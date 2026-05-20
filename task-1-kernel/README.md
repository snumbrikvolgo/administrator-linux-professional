# Задание 1. Обновление ядра системы

## Цель домашнего задания

Научиться обновлять ядро в ОС Linux.

## Описание домашнего задания

1) Запустить ВМ c Ubuntu.
2) Обновить ядро ОС на новейшую стабильную версию из mainline-репозитория.
3) Оформить отчет в README-файле в GitHub-репозитории.

Дополнительное задание:
Собрать ядро самостоятельно из исходных кодов.

## Ход выполнения домашнего задания

### Основное задание

Все дальнейшие действия были проверены при использовании proxmox qemu, хостовая ОС: Ubuntu 24.04 Server, гостевая система -- Ubuntu 24.04.3 Desktop. Управление осуществлялось по ssh.

Проверка исходного состояния системы:
```sh
$ uname -r
$ dpkg --print-architecture
6.14.0-29-generic
amd64
```

Ищем в https://kernel.ubuntu.com/mainline/ актуальную версию -- [`v7.0.1`](https://kernel.ubuntu.com/mainline/v7.0.1) -- есть версия готовых пакетов для amd64:

```text
amd64/linux-headers-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb
amd64/linux-headers-7.0.1-070001_7.0.1-070001.202604221347_all.deb
amd64/linux-image-unsigned-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb
amd64/linux-modules-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb
```

Качаем пакеты:
```
mkdir kernel && cd kernel
wget https://kernel.ubuntu.com/mainline/v7.0.1/amd64/linux-headers-7.0.1-070001_7.0.1-070001.202604221347_all.deb

wget https://kernel.ubuntu.com/mainline/v7.0.1/amd64/linux-headers-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb

wget https://kernel.ubuntu.com/mainline/v7.0.1/amd64/linux-image-unsigned-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb

wget https://kernel.ubuntu.com/mainline/v7.0.1/amd64/linux-modules-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb
ls -lh
```

```text
total 196M
-rw-rw-r-- 1 user0 user0  15M Apr 22 22:02 linux-headers-7.0.1-070001_7.0.1-070001.202604221347_all.deb
-rw-rw-r-- 1 user0 user0 3.9M Apr 22 22:01 linux-headers-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb
-rw-rw-r-- 1 user0 user0  17M Apr 22 22:00 linux-image-unsigned-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb
-rw-rw-r-- 1 user0 user0 162M Apr 22 22:01 linux-modules-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb
```

Устанавливаем пакеты и встречаем ошибку:
```sh
$ sudo dpkg -i *.deb
dpkg: error processing archive linux-image-unsigned-7.0.1-070001-generic_7.0.1-070001.202604221347_amd64.deb (--install):
 new linux-image-unsigned-7.0.1-070001-generic package pre-installation script subprocess returned error exit status 1
run-parts: missing operand
Try `run-parts --help' for more information.
```
Исправляем базу `dpkg`:
```
pkg="linux-image-unsigned-7.0.1-070001-generic"

sudo mkdir -p /root/dpkg-info-backup-7.0.1

for script in preinst postinst prerm postrm; do
  file="/var/lib/dpkg/info/${pkg}.${script}"
  if [ -f "$file" ]; then
    sudo cp -a "$file" "/root/dpkg-info-backup-7.0.1/"
    printf '#!/bin/sh\nexit 0\n' | sudo tee "$file" >/dev/null
    sudo chmod 755 "$file"
  fi
done

sudo dpkg --purge --force-remove-reinstreq "$pkg"
```

Правим скрипты и пересобираем (см. https://www.mail-archive.com/ubuntu-bugs%40lists.ubuntu.com/msg6269102.html):
```sh
cd ~/kernel

mkdir -p fixed patched
rm -rf fixed/* patched/*

for deb in *7.0.1-070001*.deb; do
  dir="fixed/${deb%.deb}"
  dpkg-deb -R "$deb" "$dir"
done

find fixed -path '*/DEBIAN/*' -type f -exec sed -i \
  -e 's#/etc/kernel/preinst\.d /usr/share/kernel/preinst\.d#/etc/kernel/preinst.d#g' \
  -e 's#/etc/kernel/postinst\.d /usr/share/kernel/postinst\.d#/etc/kernel/postinst.d#g' \
  -e 's#/etc/kernel/postrm\.d /usr/share/kernel/postrm\.d#/etc/kernel/postrm.d#g' \
  -e 's#/etc/kernel/prerm\.d /usr/share/kernel/prerm\.d#/etc/kernel/prerm.d#g' \
  -e 's#/etc/kernel/header_postinst\.d /usr/share/kernel/header_postinst\.d#/etc/kernel/header_postinst.d#g' \
  {} +

sudo mkdir -p \
  /etc/kernel/preinst.d \
  /etc/kernel/postinst.d \
  /etc/kernel/postrm.d \
  /etc/kernel/prerm.d \
  /etc/kernel/header_postinst.d

for dir in fixed/*; do
  dpkg-deb --root-owner-group -b "$dir" "patched/$(basename "$dir").deb"
done
```
Переустанавливаем исправленные пакеты:
```sh
$ sudo dpkg -i patched/*.deb
... Вывод сокращен ...
Adding boot menu entry for UEFI Firmware Settings ...
done
```

Проверяем, что ядро появилось в `/boot`:
```sh
sudo dpkg --configure -a
sudo apt -f install -y
sudo update-grub
ls -lh /boot | grep '7.0.1'
```
```text
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
0 upgraded, 0 newly installed, 0 to remove and 40 not upgraded.
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-7.0.1-070001-generic
Found initrd image: /boot/initrd.img-7.0.1-070001-generic
Found linux image: /boot/vmlinuz-6.14.0-29-generic
Found initrd image: /boot/initrd.img-6.14.0-29-generic
Found memtest86+x64 image: /boot/memtest86+x64.bin
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
-rw-r--r-- 1 root root 301K Apr 22 16:47 config-7.0.1-070001-generic
lrwxrwxrwx 1 root root   31 May 19 21:11 initrd.img -> initrd.img-7.0.1-070001-generic
-rw-r--r-- 1 root root  72M May 19 21:11 initrd.img-7.0.1-070001-generic
-rw------- 1 root root  11M Apr 22 16:47 System.map-7.0.1-070001-generic
lrwxrwxrwx 1 root root   28 May 19 21:11 vmlinuz -> vmlinuz-7.0.1-070001-generic
-rw------- 1 root root  17M Apr 22 16:47 vmlinuz-7.0.1-070001-generic
```
Выполняем перезагрузку:
```sh
sudo reboot
```

Проверка нового ядра:
```sh
$ uname -r
7.0.1-070001-generic
```

Итог: ядро обновлено с `6.14.0-29-generic` до `7.0.1-070001-generic`.

### Дополнительное задание

Соберем ванильное ядро [7.0.9](https://kernel.org/). Устанавливаем необходимые пакеты:
```sh
$ sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
$ sudo sed -i -E 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
$ sudo apt update
...
401 packages can be upgraded. Run 'apt list --upgradable' to see them.
$ sudo apt build-dep -y linux
$ sudo apt install libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf llvm
```

Скачиваем исходный код ядра:
```sh
$ mkdir -p ~/kernel-build
$ cd ~/kernel-build

$ wget -c https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.0.9.tar.xz
$ wget -c https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.0.9.tar.sign

$ ls -lh
total 150M
-rw-rw-r-- 1 user0 user0  987 May 17 18:33 linux-7.0.9.tar.sign
-rw-rw-r-- 1 user0 user0 150M May 17 18:33 linux-7.0.9.tar.xz
```

Распаковываем исходники:
```sh
tar -xf linux-7.0.9.tar.xz
cd linux-7.0.9
```

В качестве базовой конфигурации использована конфигурация текущего установленного ядра:
```bash
cp -v /boot/config-$(uname -r) .config
scripts/config --set-str LOCALVERSION "-otus"
# для избежания ошибок от ubuntu-специфичных сертификатов
scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
scripts/config --set-str SYSTEM_REVOCATION_KEYS ""
scripts/config --set-str SYSTEM_BLACKLIST_HASH_LIST ""
yes "" | make olddefconfig

make -j"$(nproc)" bindeb-pkg LOCALVERSION=-otus
```

Вывод:

```text
'/boot/config-7.0.6-070006-generic' -> '.config'
#
# configuration written to .config
```

Проверяем .deb пакеты:
```sh
$ cd ..
$ ls -lh *.deb
-rw-r--r-- 1 user0 user0  11M May 19 23:50 linux-headers-7.0.9-otus_7.0.9-2_amd64.deb
-rw-r--r-- 1 user0 user0 122M May 19 23:50 linux-image-7.0.9-otus_7.0.9-2_amd64.deb
-rw-r--r-- 1 user0 user0 1.5G May 20 00:08 linux-image-7.0.9-otus-dbg_7.0.9-2_amd64.deb
-rw-r--r-- 1 user0 user0 1.5M May 19 23:50 linux-libc-dev_7.0.9-2_amd64.deb
```

Установка ядра:
```sh
sudo dpkg -i linux-image-*.deb linux-headers-*.deb linux-libc-dev_*.deb
sudo update-grub
```

Перезагрузка и проверка:
```sh
$ sudo reboot
$ uname -r
$ ls -al /boot | grep '7.0.9-otus'
7.0.9-otus
-rw-r--r--  1 root root   306491 May 19 22:16 config-7.0.9-otus
-rw-r--r--  1 root root 84674580 May 20 12:55 initrd.img-7.0.9-otus
-rw-r--r--  1 root root  9881064 May 19 22:16 System.map-7.0.9-otus
-rw-r--r--  1 root root 16552448 May 19 22:16 vmlinuz-7.0.9-otus
```

Итог: ядро пересобрано, и теперь она сменилось с `7.0.1-070001-generic` на `7.0.9-otus`.
