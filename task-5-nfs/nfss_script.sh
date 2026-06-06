#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y nfs-kernel-server
ss -tnplu | grep -E ':(111|2049)\b' || true

mkdir -p /srv/share/upload
chown -R nobody:nogroup /srv/share
chmod 0777 /srv/share/upload

cat > /etc/exports <<'EXPORTS'
/srv/share 192.168.50.11/32(rw,sync,no_subtree_check,root_squash)
EXPORTS

exportfs -r
exportfs -s
