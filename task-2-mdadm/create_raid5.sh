#!/usr/bin/env bash

# Проверяем подключенные диски
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS

# Удаляем старые метаданные RAID с трех дисков массива (+ ошибка Unrecognised md component device, т.к. устройство новое)
sudo mdadm --zero-superblock --force /dev/sdb /dev/sdc /dev/sdd

# Создаем RAID-5 из трех дисков
sudo mdadm --create --verbose /dev/md0 --level=5 --raid-devices=3 /dev/sdb /dev/sdc /dev/sdd

# Проверяем состояние собранного RAID
cat /proc/mdstat
sudo mdadm -D /dev/md0
