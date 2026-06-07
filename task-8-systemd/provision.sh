#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid nginx curl

cat > /etc/default/watchlog <<'WATCHLOG_DEFAULT'
# Configuration file for watchlog service
# File and word in that file that will be monitored
WORD="ALERT"
LOG="/var/log/watchlog.log"
WATCHLOG_DEFAULT

cat > /var/log/watchlog.log <<'WATCHLOG_LOG'
System started successfully
Disk check completed
ALERT: test message for systemd timer
Service check completed
WATCHLOG_LOG

cat > /opt/watchlog.sh <<'WATCHLOG_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

WORD="${1:?WORD is required}"
LOG="${2:?LOG is required}"
DATE="$(date)"

if grep -Fq -- "$WORD" "$LOG"; then
  logger "$DATE: I found word, Master!"
fi
WATCHLOG_SCRIPT

chmod +x /opt/watchlog.sh

cat > /etc/systemd/system/watchlog.service <<'WATCHLOG_SERVICE'
[Unit]
Description=Watch log file for configured keyword

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh ${WORD} ${LOG}
WATCHLOG_SERVICE

cat > /etc/systemd/system/watchlog.timer <<'WATCHLOG_TIMER'
[Unit]
Description=Run watchlog service every 30 seconds

[Timer]
OnBootSec=30
OnUnitActiveSec=30
AccuracySec=1s
Unit=watchlog.service

[Install]
WantedBy=timers.target
WATCHLOG_TIMER

systemctl start watchlog.timer

mkdir /etc/spawn-fcgi

cat > /etc/spawn-fcgi/fcgi.conf <<'FCGI_CONF'
# Configuration file for spawn-fcgi service
SOCKET=/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s /run/php-fcgi.sock -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
FCGI_CONF

cat > /etc/systemd/system/spawn-fcgi.service <<'SPAWN_FCGI_SERVICE'
[Unit]
Description=Spawn-fcgi startup service
After=network.target

[Service]
Type=simple
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStartPre=/bin/rm -f /run/php-fcgi.sock
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
ExecStopPost=/bin/rm -f /run/php-fcgi.sock
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
SPAWN_FCGI_SERVICE

systemctl start spawn-fcgi
systemctl status spawn-fcgi

cat > /etc/systemd/system/nginx@.service <<'NGINX_TEMPLATE'
[Unit]
Description=Nginx instance %i
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%i.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%i.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%i.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%i.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%i.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
NGINX_TEMPLATE

cat > /etc/nginx/nginx-first.conf <<'NGINX_FIRST'
user www-data;
worker_processes auto;
pid /run/nginx-first.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    include /etc/nginx/mime.types;
    default_type text/plain;

    access_log /var/log/nginx/first-access.log;
    error_log /var/log/nginx/first-error.log;

    server {
        listen 9001 default_server;
        server_name _;

        location / {
            return 200 "first nginx instance\n";
        }
    }
}
NGINX_FIRST

cat > /etc/nginx/nginx-second.conf <<'NGINX_SECOND'
user www-data;
worker_processes auto;
pid /run/nginx-second.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    include /etc/nginx/mime.types;
    default_type text/plain;

    access_log /var/log/nginx/second-access.log;
    error_log /var/log/nginx/second-error.log;

    server {
        listen 9002 default_server;
        server_name _;

        location / {
            return 200 "second nginx instance\n";
        }
    }
}
NGINX_SECOND

systemctl start nginx@first
systemctl start nginx@second

echo "=== watchlog ==="
systemctl is-active watchlog.timer
systemctl list-timers watchlog.timer --no-pager
journalctl -t root -n 5 --no-pager | grep 'I found word' || true

echo "=== spawn-fcgi ==="
systemctl is-active spawn-fcgi.service
if test -S /run/php-fcgi.sock; then
  echo "/run/php-fcgi.sock exists"
fi
ps -ef | grep '[p]hp-cgi' | head -n 5

echo "=== nginx instances ==="
systemctl is-active nginx@first.service
systemctl is-active nginx@second.service
ss -tnlp | grep -E ':(9001|9002)'
curl -s http://127.0.0.1:9001/
curl -s http://127.0.0.1:9002/
