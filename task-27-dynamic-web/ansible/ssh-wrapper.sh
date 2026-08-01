#!/usr/bin/env bash
set -euo pipefail

args=()
skip_next=0

for arg in "$@"; do
  if [[ "$skip_next" -eq 1 ]]; then
    case "$arg" in
      ControlPath=*|ControlMaster=auto|ControlPersist=60s)
        ;;
      *)
        args+=("-o" "$arg")
        ;;
    esac
    skip_next=0
    continue
  fi

  if [[ "$arg" == "-o" ]]; then
    skip_next=1
    continue
  fi

  case "$arg" in
    -oControlPath=*|-oControlMaster=auto|-oControlPersist=60s)
      ;;
    *)
      args+=("$arg")
      ;;
  esac
done

exec /mnt/c/Windows/System32/OpenSSH/ssh.exe "${args[@]}"
