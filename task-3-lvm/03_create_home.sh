#!/usr/bin/env bash

# Удаляем временный root и переносим /home на отдельный LV с XFS.
# Запускать после перезагрузки с корневого LV размером 8 GiB.

cd /

ROOT_LV="/dev/ubuntu-vg/ubuntu-lv"
TEMP_LV="/dev/vg_root/lv_root"
VAR_LV="/dev/vg_var/lv_var"
HOME_LV="/dev/ubuntu-vg/LogVol_Home"

mount -a
test "$(readlink -f "$(findmnt -n -o SOURCE /)")" = "$(readlink -f "$ROOT_LV")"
test "$(readlink -f "$(findmnt -n -o SOURCE /var)")" = "$(readlink -f "$VAR_LV")"

findmnt /
findmnt /var
df -Th / /var
lvs -a -o lv_name,vg_name,segtype,lv_size,copy_percent,devices

lvremove -y "$TEMP_LV"
vgremove -y vg_root
pvremove -y /dev/sdb

lvcreate -n LogVol_Home -L 2G ubuntu-vg
mkfs.xfs -f "$HOME_LV"

mkdir -p /mnt/home.new
mount "$HOME_LV" /mnt/home.new
rsync -aHAX /home/ /mnt/home.new/
umount /mnt/home.new

find /home -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

HOME_UUID="$(blkid -s UUID -o value "$HOME_LV")"
sed -i -E '\|^[^#].*[[:space:]]+/home[[:space:]]+|d' /etc/fstab
printf 'UUID=%s /home xfs defaults,nodev,nosuid 0 2\n' "$HOME_UUID" >> /etc/fstab

mount /home

findmnt /
findmnt /var
findmnt /home
df -Th / /var /home
lvs -a -o lv_name,vg_name,segtype,lv_size,copy_percent,devices
grep -E '[[:space:]](/|/var|/home)[[:space:]]' /etc/fstab
