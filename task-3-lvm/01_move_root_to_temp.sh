#!/usr/bin/env bash

# Создаем временный root на /dev/sdb и готовим загрузку с него.

ROOT_LV="/dev/ubuntu-vg/ubuntu-lv"
TEMP_LV="/dev/vg_root/lv_root"

test "$(readlink -f "$(findmnt -n -o SOURCE /)")" = "$(readlink -f "$ROOT_LV")"
test ! -e "$TEMP_LV"

pvcreate /dev/sdb
vgcreate vg_root /dev/sdb
lvcreate -n lv_root -l +100%FREE /dev/vg_root

mkfs.ext4 -F "$TEMP_LV"
mkdir -p /mnt/root.new
mount "$TEMP_LV" /mnt/root.new
rsync -avxHAX --progress / /mnt/root.new/

for i in /proc /sys /dev /run /boot; do
  mount --bind "$i" "/mnt/root.new$i"
done

chroot /mnt/root.new grub-mkconfig -o /boot/grub/grub.cfg
chroot /mnt/root.new update-initramfs -u

lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
lvs -a -o +devices