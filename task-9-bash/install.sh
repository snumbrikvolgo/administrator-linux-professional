#!/usr/bin/env bash

set -euo pipefail

apt update
apt install -y nginx mailutils gawk

mkdir -p /var/www/web-report
cat > /var/www/web-report/index.html <<'HTML'
<!doctype html>
<html>
<head><title>web-report</title></head>
<body>web-report test page</body>
</html>
HTML

cp scripts/web-report.sh /usr/local/sbin/web-report.sh
chmod +x /usr/local/sbin/web-report.sh

cp config/web-report /etc/default/web-report

cp cron/web-report /etc/cron.d/web-report
chmod 0644 /etc/cron.d/web-report

cp nginx/web-report.conf /etc/nginx/sites-available/web-report
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/web-report /etc/nginx/sites-enabled/web-report

mkdir -p /var/lib/web-report

touch /var/log/nginx/web-report-access.log /var/log/nginx/web-report-error.log

nginx -t
systemctl enable --now nginx
systemctl reload nginx
