#!/usr/bin/env bash

# Дополнительное задание: перенос /opt на Btrfs, сжатие и snapshot.

cd /

apt install -y btrfs-progs

test -b /dev/sde
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/sde

wipefs -a /dev/sde
mkfs.btrfs -f -L opt_btrfs /dev/sde

mkdir -p /mnt/btrfs_opt /opt
mount /dev/sde /mnt/btrfs_opt
btrfs subvolume create /mnt/btrfs_opt/opt
rsync -aHAX  /opt/ /mnt/btrfs_opt/opt/
mkdir -p /mnt/btrfs_opt/snapshots

OPT_UUID="$(blkid -s UUID -o value /dev/sde)"
sed -i -E '\|^[^#].*[[:space:]]+/opt[[:space:]]+|d' /etc/fstab
printf 'UUID=%s /opt btrfs defaults,compress=zstd:1,noatime,subvol=opt 0 0\n' "$OPT_UUID" >> /etc/fstab

umount /mnt/btrfs_opt
mount /opt

touch /opt/file{1..5}
ls -la /opt/file*

mount -o subvolid=5 /dev/sde /mnt/btrfs_opt
btrfs subvolume snapshot -r /mnt/btrfs_opt/opt /mnt/btrfs_opt/snapshots/opt_before_remove

rm -f /opt/file{3..5}
umount /opt
btrfs subvolume delete /mnt/btrfs_opt/opt
btrfs subvolume snapshot /mnt/btrfs_opt/snapshots/opt_before_remove /mnt/btrfs_opt/opt
umount /mnt/btrfs_opt
mount /opt

ls -la /opt/file*
findmnt /opt
mount -o subvolid=5 /dev/sde /mnt/btrfs_opt
btrfs subvolume list /mnt/btrfs_opt
umount /mnt/btrfs_opt
grep -E '[[:space:]]/opt[[:space:]]' /etc/fstab
