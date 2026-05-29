#!/usr/bin/env bash

# Выполняется после перезагрузки на временный root /dev/vg_root/lv_root.

ROOT_LV="/dev/ubuntu-vg/ubuntu-lv"
TEMP_LV="/dev/vg_root/lv_root"
VAR_LV="/dev/vg_var/lv_var"
TARGET="/mnt/root.new"

# Пересоздаем постоянный root размером 8 GiB.
lvremove -y "$ROOT_LV"
lvcreate -n ubuntu-lv -L 8G ubuntu-vg
mkfs.ext4 -F "$ROOT_LV"

mkdir -p "$TARGET"
mount "$ROOT_LV" "$TARGET"

# Создаем отдельный mirrored LV для /var.
pvcreate /dev/sdc /dev/sdd
vgcreate vg_var /dev/sdc /dev/sdd
lvcreate --type raid1 -m1 -L 950M -n lv_var vg_var /dev/sdc /dev/sdd
mkfs.ext4 -F "$VAR_LV"

# Сразу подключаем будущий /var внутрь будущего root.
mkdir -p "$TARGET/var"
mount "$VAR_LV" "$TARGET/var"

# Один раз копируем систему:
# обычные каталоги попадут на ROOT_LV,
# а содержимое /var сразу попадет на VAR_LV.
rsync -avxHAX --progress / "$TARGET/"

# Файл fstab уже скопирован командой rsync. # Строки / и /boot сохраняются без изменений.
# Добавляем только новую файловую систему /var.
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_LV")"
VAR_UUID="$(blkid -s UUID -o value "$VAR_LV")"

sed -i -E \
 -e '\|^[[:space:]]*[^#].*[[:space:]]+/[[:space:]]+|d' \
  -e '\|^[[:space:]]*[^#].*[[:space:]]+/var[[:space:]]+|d' \
 "$TARGET/etc/fstab"

printf 'UUID=%s / ext4 defaults 0 1\n' "$ROOT_UUID" \ >> "$TARGET/etc/fstab"
printf 'UUID=%s /var ext4 defaults,nodev,nosuid 0 2\n' "$VAR_UUID" >> "$TARGET/etc/fstab"
# Подключаем служебные файловые системы для chroot.
for i in /proc /sys /dev /run /boot; do
  mount --bind "$i" "/mnt/root.new$i"
done

# Обновляем загрузочную конфигурацию уже для окончательной схемы:
chroot "$TARGET" grub-mkconfig -o /boot/grub/grub.cfg

mkdir -p "$TARGET/tmp"
chmod 1777 "$TARGET/tmp"
chroot "$TARGET" env TMPDIR=/tmp update-initramfs -u