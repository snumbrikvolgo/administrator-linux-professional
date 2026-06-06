#!/usr/bin/env bash
set -euo pipefail

apt-get update
apt-get install -y nfs-common

mkdir -p /mnt

cat >> /etc/fstab <<'FSTAB'
192.168.50.10:/srv/share /mnt nfs vers=3,noauto,x-systemd.automount,_netdev 0 0
FSTAB

systemctl daemon-reload
systemctl restart remote-fs.target

ls /mnt
mount | grep ' /mnt '