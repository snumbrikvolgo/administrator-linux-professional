#!/usr/bin/env bash

# Создаем snapshot /home, удаляем часть файлов и выполняем восстановление.

cd /

HOME_LV="/dev/ubuntu-vg/LogVol_Home"
SNAP_LV="/dev/ubuntu-vg/home_snap"

touch /home/file{1..20}
ls -la /home/file*

lvcreate -L 100M -s -n home_snap "$HOME_LV"
lvs -a -o +devices

rm -f /home/file{11..20}
ls -la /home/file*

fuser -vm /home || true
umount /home
lvconvert --merge "$SNAP_LV"
mount /home

ls -la /home/file*
lvs -a -o +devices
