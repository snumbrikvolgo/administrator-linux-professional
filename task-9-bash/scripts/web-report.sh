#!/usr/bin/env bash

set -euo pipefail

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

CONFIG_FILE="${CONFIG_FILE:-/etc/default/web-report}"

REPORT_FILE=""
ACCESS_TMP=""
ERROR_TMP=""
ACCESS_LOG=""
ERROR_LOG=""
NOW_EPOCH=""
LAST_EPOCH=""
START_TIME=""
END_TIME=""

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Config file not found: $CONFIG_FILE" >&2
        exit 1
    fi

    source "$CONFIG_FILE"
}

validate_config() {
    : "${MAIL_TO:?MAIL_TO is not set}"
    : "${LOG_DIR:?LOG_DIR is not set}"
    : "${ACCESS_LOG_NAME:?ACCESS_LOG_NAME is not set}"
    : "${ERROR_LOG_NAME:?ERROR_LOG_NAME is not set}"
    : "${STATE_FILE:?STATE_FILE is not set}"
    : "${LOCK_FILE:?LOCK_FILE is not set}"
    : "${TOP_N:?TOP_N is not set}"
    : "${MAIL_SUBJECT:?MAIL_SUBJECT is not set}"
}

cleanup() {
    for file in "$REPORT_FILE" "$ACCESS_TMP" "$ERROR_TMP"; do
        if [[ -n "$file" && -f "$file" ]]; then
            rm -f "$file"
        fi
    done
}

lock_script() {
    mkdir -p "$(dirname "$LOCK_FILE")"

    exec 200>"$LOCK_FILE"

    if ! flock -n 200; then
        echo "Script is already running"
        exit 0
    fi
}

init_runtime() {
    NOW_EPOCH="$(date +%s)"
    REPORT_FILE="$(mktemp)"
    ACCESS_TMP="$(mktemp)"
    ERROR_TMP="$(mktemp)"

    trap cleanup EXIT INT TERM
}

get_period() {
    mkdir -p "$(dirname "$STATE_FILE")"

    if [[ -s "$STATE_FILE" ]]; then
        LAST_EPOCH="$(cat "$STATE_FILE")"
    else
        LAST_EPOCH="$((NOW_EPOCH - 3600))"
    fi

    if ! [[ "$LAST_EPOCH" =~ ^[0-9]+$ ]]; then
        LAST_EPOCH="$((NOW_EPOCH - 3600))"
    fi

    START_TIME="$(date -d "@$LAST_EPOCH" '+%Y-%m-%d %H:%M:%S %z')"
    END_TIME="$(date -d "@$NOW_EPOCH" '+%Y-%m-%d %H:%M:%S %z')"
}

find_logs() {
    ACCESS_LOG="$(find "$LOG_DIR" -maxdepth 1 -type f -name "$ACCESS_LOG_NAME" | head -n 1 || true)"
    ERROR_LOG="$(find "$LOG_DIR" -maxdepth 1 -type f -name "$ERROR_LOG_NAME" | head -n 1 || true)"
}

filter_access_log() {
    : > "$ACCESS_TMP"

    if [[ -z "$ACCESS_LOG" ]]; then
        return
    fi

    awk -v start="$LAST_EPOCH" -v end="$NOW_EPOCH" '
        BEGIN {
            mon["Jan"]="01"; mon["Feb"]="02"; mon["Mar"]="03"; mon["Apr"]="04";
            mon["May"]="05"; mon["Jun"]="06"; mon["Jul"]="07"; mon["Aug"]="08";
            mon["Sep"]="09"; mon["Oct"]="10"; mon["Nov"]="11"; mon["Dec"]="12";
        }

        {
            left = index($0, "[");
            if (left == 0) {
                next;
            }

            raw = substr($0, left + 1, 20);
            split(raw, t, /[\/:]/);

            if (!(t[2] in mon)) {
                next;
            }

            log_time = mktime(t[3] " " mon[t[2]] " " t[1] " " t[4] " " t[5] " " t[6]);

            if (log_time >= start && log_time < end) {
                print $0;
            }
        }
    ' "$ACCESS_LOG" > "$ACCESS_TMP"
}

filter_error_log() {
    : > "$ERROR_TMP"

    if [[ -z "$ERROR_LOG" ]]; then
        return
    fi

    awk -v start="$LAST_EPOCH" -v end="$NOW_EPOCH" '
        {
            raw = substr($0, 1, 19);

            if (raw !~ /^[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/) {
                next;
            }

            gsub(/\//, " ", raw);
            gsub(/:/, " ", raw);
            split(raw, t, " ");

            log_time = mktime(t[1] " " t[2] " " t[3] " " t[4] " " t[5] " " t[6]);

            if (log_time >= start && log_time < end) {
                print $0;
            }
        }
    ' "$ERROR_LOG" \
        | sed -nE '/error|crit|alert|emerg|failed|denied|fatal|exception/Ip' \
        > "$ERROR_TMP"
}

make_report() {
    {
        echo "Web server hourly report"
        echo "Period: $START_TIME — $END_TIME"
        echo "Access log: ${ACCESS_LOG:-not found}"
        echo "Error log: ${ERROR_LOG:-not found}"
        echo

        echo "Top IP addresses:"
        if [[ -s "$ACCESS_TMP" ]]; then
            awk '{ print $1 }' "$ACCESS_TMP" \
                | sort \
                | uniq -c \
                | sort -rn \
                | head -n "$TOP_N"
        else
            echo "No requests"
        fi

        echo
        echo "Top requested URLs:"
        if [[ -s "$ACCESS_TMP" ]]; then
            sed -nE 's#^[^"]*"[^ ]+ ([^ ?"]+).*$#\1#p' "$ACCESS_TMP" \
                | sort \
                | uniq -c \
                | sort -rn \
                | head -n "$TOP_N"
        else
            echo "No URLs"
        fi

        echo
        echo "HTTP response codes:"
        if [[ -s "$ACCESS_TMP" ]]; then
            sed -nE 's#^.*" ([0-9]{3}) [0-9-]+.*$#\1#p' "$ACCESS_TMP" \
                | sort \
                | uniq -c \
                | sort -rn
        else
            echo "No HTTP codes"
        fi

        echo
        echo "Web server / application errors:"
        if [[ -s "$ERROR_TMP" ]]; then
            cat "$ERROR_TMP"
        else
            echo "No errors"
        fi
    } > "$REPORT_FILE"
}

send_report() {
    if command -v mail >/dev/null 2>&1; then
        mail -s "$MAIL_SUBJECT" "$MAIL_TO" < "$REPORT_FILE"
    else
        cat "$REPORT_FILE"
        echo "mail command not found. Install mailutils or mailx." >&2
        exit 1
    fi
}

save_state() {
    echo "$NOW_EPOCH" > "$STATE_FILE"
}

main() {
    load_config
    validate_config
    lock_script
    init_runtime
    get_period
    find_logs
    filter_access_log
    filter_error_log
    make_report
    send_report
    save_state
}

main "$@"
