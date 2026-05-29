# Задание 3. Работа с LVM

## Цель домашнего задания

Cоздавать и управлять логическими томами в LVM;

## Описание домашнего задания

На виртуальной машине с Ubuntu 24.04 и LVM.

1. Уменьшить том под `/` до 8G.
2. Выделить том под `/home`.
3. Выделить том под `/var` - сделать в mirror.
4. `/home` - сделать том для снапшотов.
5. Прописать монтирование в fstab. Попробовать с разными опциями и разными файловыми системами (на выбор).
6. Работа со снапшотами:
- сгенерить файлы в `/home`;
- снять снапшот;
- удалить часть файлов;
- восстановиться со снапшота.

## Ход выполнения домашнего задания

### Основное задание

#### Подготовка системы

В предыдущей работе использовалась виртуальная машина с обычной файловой системой на `/dev/sda2` и программным RAID. Для задания по LVM эта машина не переиспользовалась. Была создана новая чистая виртуальная машина, поскольку корневая файловая система должна изначально находиться на логическом томе LVM.

По условию задания требуется Ubuntu 24.04. Имеющийся образ `ubuntu-22.04.5-live-server-amd64.iso` пригоден для тренировки тех же действий.

```sh
sudo apt install -y lvm2 rsync xfsprogs
sudo -i
ROOT_LV="/dev/ubuntu-vg/ubuntu-lv"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
findmnt /
df -Th /
pvs
vgs
lvs -a -o +devices

test -b "$ROOT_LV"
test -b /dev/sdb
test -b /dev/sdc
test -b /dev/sdd
test "$(readlink -f "$(findmnt -n -o SOURCE /)")" = "$(readlink -f "$ROOT_LV")"
```

Скрипт устанавливает необходимые утилиты и проверяет, что `/` находится на LVM, а дополнительные диски доступны.

```txt
NAME                       SIZE TYPE FSTYPE      MOUNTPOINTS
loop0                     63.8M loop squashfs    /snap/core20/2866
loop1                     63.9M loop squashfs    /snap/core20/2318
loop2                       87M loop squashfs    /snap/lxd/29351
loop3                     38.8M loop squashfs    /snap/snapd/21759
sda                         64G disk
├─sda1                       1M part
├─sda2                       2G part ext4        /boot
└─sda3                      62G part LVM2_member
  └─ubuntu--vg-ubuntu--lv   31G lvm  ext4        /
sdb                         10G disk
sdc                          1G disk
sdd                          1G disk
sde                          1G disk
```

#### Перенос `/` на временный логический том

[Первый отдельный скрипт](./01_move_root_to_temp.sh) создает временный root на `/dev/sdb`, копирует туда систему и обновляет загрузочную конфигурацию.

```sh
script -a install_lvm.log
sudo ./01_move_root_to_temp.sh
exit
reboot
```

Фрагмент журнала:

```txt
Physical volume "/dev/sdb" successfully created.
Volume group "vg_root" successfully created
Logical volume "lv_root" created.
...
Generating grub configuration file ...
update-initramfs: Generating /boot/initrd.img-5.15.0-179-generic
```

После перезагрузки проверяется, что система загрузилась с временного root:

```sh
findmnt /
```

```txt
TARGET SOURCE                      FSTYPE OPTIONS
/      /dev/mapper/vg_root-lv_root ext4   rw,relatime
```

#### Создание нового `/` размером 8 GiB и зеркального `/var`

После загрузки с временного root исходный `ubuntu-lv` больше не используется как `/`. [Второй отдельный скрипт](./02_create_root_8g_and_var.sh) пересоздает его размером 8 GiB, создает mirrored LV под `/var`, копирует систему обратно.

```sh
script -a install_lvm.log
sudo ./02_create_root_8g_and_var.sh
exit
reboot
```

Основные выполняемые команды:

```sh
lvremove -y /dev/ubuntu-vg/ubuntu-lv
lvcreate -n ubuntu-lv -L 8G ubuntu-vg
mkfs.ext4 -F /dev/ubuntu-vg/ubuntu-lv
mount /dev/ubuntu-vg/ubuntu-lv /mnt/root.new
rsync -avxHAX --numeric-ids --progress / /mnt/root.new/

pvcreate /dev/sdc /dev/sdd
vgcreate vg_var /dev/sdc /dev/sdd
lvcreate -L 950M -m1 -n lv_var vg_var
mkfs.ext4 -F /dev/vg_var/lv_var
```

Для `/var` и `/` записывается автоматическое монтирование с опциями `nodev` и `nosuid`:

```txt
UUID=<UUID-var> /var ext4 defaults,nodev,nosuid 0 2
```

Фрагмент журнала:

```txt
Logical volume "ubuntu-lv" successfully removed.
Logical volume "ubuntu-lv" created.
Physical volume "/dev/sdc" successfully created.
Physical volume "/dev/sdd" successfully created.
Volume group "vg_var" successfully created
Logical volume "lv_var" created.

LV     VG     Type  LSize   Cpy%Sync
lv_var vg_var raid1 952.00m 100.00
```

После перезагрузки:

```sh
findmnt /
findmnt /var
df -Th / /var
```

#### Создание отдельного тома `/home`

[Третий отдельный скрипт](./03_create_home.sh) удаляет больше не нужный временный root и создает отдельный том `/home` размером 2 GiB. Для `/home` используется XFS, чтобы продемонстрировать файловую систему, отличную от `ext4`.

```sh
script -a install_lvm.log
sudo ./03_create_home.sh
exit
reboot
```

Основные выполняемые команды:

```sh
lvremove -y /dev/vg_root/lv_root
vgremove -y vg_root
pvremove -y /dev/sdb

lvcreate -n LogVol_Home -L 2G ubuntu-vg
mkfs.xfs -f /dev/ubuntu-vg/LogVol_Home
mount /dev/ubuntu-vg/LogVol_Home /mnt/home.new
rsync -aHAX --numeric-ids /home/ /mnt/home.new/
mount /dev/ubuntu-vg/LogVol_Home /home
```

В `/etc/fstab` добавляется строка:

```txt
UUID=<UUID-home> /home xfs defaults,nodev,nosuid 0 2
```

Фрагмент журнала:

```txt
Logical volume "lv_root" successfully removed.
Volume group "vg_root" successfully removed
Logical volume "LogVol_Home" created.

TARGET SOURCE                                  FSTYPE OPTIONS
/      /dev/mapper/ubuntu--vg-ubuntu--lv ext4   rw,relatime
/var   /dev/mapper/vg_var-lv_var ext4   rw,nosuid,nodev,relatime
/home  /dev/mapper/ubuntu--vg-LogVol_Home xfs    rw,nosuid,nodev,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota
```

#### Создание и восстановление snapshot `/home`

[Четвертый скрипт](./04_home_snapshot_restore.sh) создает тестовые файлы, снимает snapshot, удаляет часть файлов и выполняет восстановление.

Скрипт выполняется из root-shell или локальной консоли. При восстановлении `/home` должен отмонтироваться, поэтому активные пользовательские процессы не должны удерживать этот каталог.

```sh
script -a install_lvm.log
sudo ./04_home_snapshot_restore.sh
exit
```

Список команд создания и восстановления snapshot:

```sh
touch /home/file{1..20}
lvcreate -L 100M -s -n home_snap /dev/ubuntu-vg/LogVol_Home
rm -f /home/file{11..20}
umount /home
lvconvert --merge /dev/ubuntu-vg/home_snap
mount /home
ls -la /home/file*
```

Фрагмент журнала:

```txt
Logical volume "home_snap" created.
Merging of volume ubuntu-vg/home_snap started.
ubuntu-vg/LogVol_Home: Merged: 100.00%

-rw-r--r-- 1 root root 0 ... /home/file1
-rw-r--r-- 1 root root 0 ... /home/file10
-rw-r--r-- 1 root root 0 ... /home/file11
-rw-r--r-- 1 root root 0 ... /home/file20
```

Повторное появление файлов `/home/file11`–`/home/file20` подтверждает восстановление из snapshot.

### Дополнительное задание

[Для дополнительного задания](./optional_btrfs_opt.sh) используется отдельный диск `/dev/sde` размером 2 GiB. На нем создается файловая система Btrfs, а `/opt` размещается в отдельном subvolume. Демонстрируются сжатие и восстановление snapshot.

```sh
script -a optional_btrfs_opt.log
sudo ./optional_btrfs_opt.sh
exit
```

Основные команды:

```sh
mkfs.btrfs -f -L opt_btrfs /dev/sde
mount /dev/sde /mnt/btrfs_opt
btrfs subvolume create /mnt/btrfs_opt/opt
mount /opt
btrfs subvolume snapshot -r /mnt/btrfs_opt/opt /mnt/btrfs_opt/snapshots/opt_before_remove
btrfs subvolume snapshot /mnt/btrfs_opt/snapshots/opt_before_remove /mnt/btrfs_opt/opt
```

В `/etc/fstab` добавляется строка:

```txt
UUID=<UUID-btrfs> /opt btrfs defaults,compress=zstd:1,noatime,subvol=opt 0 0
```

Фрагмент журнала:

```txt
Create subvolume '/mnt/btrfs_opt/opt'
Create a readonly snapshot of '/mnt/btrfs_opt/opt' in '/mnt/btrfs_opt/snapshots/opt_before_remove'
Create a snapshot of '/mnt/btrfs_opt/snapshots/opt_before_remove' in '/mnt/btrfs_opt/opt'

TARGET SOURCE   FSTYPE OPTIONS
/opt   /dev/sde btrfs  rw,noatime,compress=zstd:1,subvol=/opt
```