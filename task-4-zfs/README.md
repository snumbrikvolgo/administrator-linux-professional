# Задание 4. Стенд ZFS

## Цель домашнего задания

Научится самостоятельно устанавливать ZFS, настраивать пулы, изучить основные возможности ZFS.

## Описание домашнего задания

Выполнить настройку ZFS и изучить базовые возможности файловой системы:

1. Определить алгоритм с наилучшим сжатием:
   - определить, какие алгоритмы сжатия поддерживает ZFS;
   - создать 4 файловые системы;
   - на каждой применить свой алгоритм сжатия: `gzip`, `zle`, `lzjb`, `lz4`;
   - для сжатия использовать текстовый файл или группу файлов;
   - сравнить результат.

2. Определить настройки пула:
   - с помощью команды `zpool import` собрать ZFS pool;
   - командами ZFS определить:
     - размер хранилища;
     - тип pool;
     - значение `recordsize`;
     - используемое сжатие;
     - используемую контрольную сумму.

3. Выполнить работу со снапшотами:
   - скачать файл со снапшотом;
   - восстановить файловую систему локально через `zfs receive`;
   - найти зашифрованное сообщение в файле `secret_message`.

## Используемый стенд

Задание выполняется на виртуальной машине Ubuntu 24.04 LTS, развернутой через Vagrant и VirtualBox. Предварительно был скачан файл с диском Vagrant box по ссылке https://vagrantcloud.com/bento/boxes/ubuntu-24.04/versions/202510.26.0/providers/virtualbox/amd64/vagrant.box. Скрипт [zfs_setup.sh](./zfs_setup.sh) выполнялся после поднятия машины автоматически благодаря установленному provision.

Ресурсы VM:

```text
CPU: 2
RAM: 8192 MB
System disk: диск Vagrant box
Additional disks: 8 дисков по 512 MB
Provider: VirtualBox
```

## Запуск на Windows 11

Требуется:

- Oracle VirtualBox;
- Vagrant for Windows;
- sh или Windows Terminal.

Запуск:

```sh
vagrant up --provider=virtualbox
```

Вход в VM:

```sh
vagrant ssh
```

Повторный запуск скрипта provision

```sh
vagrant provision
```

Остановка VM:

```sh
vagrant halt
```

Полное удаление VM:

```sh
vagrant destroy -f
```

## Задание 1. Определение алгоритма с наилучшим сжатием

### 1.1. Проверка дисков

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

```text
NAME                       SIZE TYPE FSTYPE      MOUNTPOINTS
                                                       MODEL
sda                         64G disk                   VBOX HARDDISK
├─sda1                       1M part
├─sda2                       2G part ext4        /boot
└─sda3                      62G part LVM2_member
  └─ubuntu--vg-ubuntu--lv   31G lvm  ext4        /
sdb                        512M disk                   VBOX HARDDISK
sdc                        512M disk                   VBOX HARDDISK
sdd                        512M disk                   VBOX HARDDISK
sde                        512M disk                   VBOX HARDDISK
sdf                        512M disk                   VBOX HARDDISK
sdg                        512M disk                   VBOX HARDDISK
sdh                        512M disk                   VBOX HARDDISK
sdi                        512M disk                   VBOX HARDDISK
```

Система завелась корректно.

### 1.2. Установка ZFS

Команды:

```bash
sudo apt-get update
sudo apt-get install -y zfsutils-linux wget ca-certificates
zfs version
```

```text
zfs-2.2.2-0ubuntu9.4
zfs-kmod-2.2.2-0ubuntu9.4
```

### 1.3. Создание четырех mirror-пулов

Команды:

```bash
sudo zpool create otus1 mirror /dev/sdb /dev/sdc
sudo zpool create otus2 mirror /dev/sdd /dev/sde
sudo zpool create otus3 mirror /dev/sdf /dev/sdg
sudo zpool create otus4 mirror /dev/sdh /dev/sdi

zpool list
```

```text
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   480M   114K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus2   480M   142K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus3   480M   140K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus4   480M   140K   480M        -         -     0%     0%  1.00x    ONLINE  -
```

### 1.4. Определение поддерживаемых алгоритмов сжатия

Вбиваем

```bash
zfs set compression --help
```
И видим
```text
        compression     YES      YES   on | off | lzjb | gzip | gzip-[1-9] | zle | lz4 | zstd | zstd-[1-19] | zstd-fast | zstd-fast-[1-10,20,30,40,50,60,70,80,90,100,500,1000]
```

Для выполнения задания используются алгоритмы из методички:

```text
lzjb
lz4
gzip-9
zle
```

### 1.5. Настройка алгоритмов сжатия

Команды:

```bash
sudo zfs set compression=lzjb otus1
sudo zfs set compression=lz4 otus2
sudo zfs set compression=gzip-9 otus3
sudo zfs set compression=zle otus4

zfs get compression otus1 otus2 otus3 otus4
```
```text
NAME   PROPERTY     VALUE     SOURCE
otus1  compression  lzjb      local
otus2  compression  lz4       local
otus3  compression  gzip-9    local
otus4  compression  zle       local
```

### 1.6. Загрузка одинакового файла и сравнение сжатия

Команды:

```bash
sudo wget -O /otus1/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'
sudo wget -O /otus2/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'
sudo wget -O /otus3/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'
sudo wget -O /otus4/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'

zfs list
zfs get all | grep compressratio | grep -v ref
```

```text
NAME    USED  AVAIL  REFER  MOUNTPOINT
otus1  21.8M   330M  21.6M  /otus1
otus2  17.7M   334M  17.6M  /otus2
otus3  10.9M   341M  10.7M  /otus3
otus4  39.5M   312M  39.4M  /otus4
otus1  compressratio         1.82x                  -
otus2  compressratio         2.23x                  -
otus3  compressratio         3.66x                  -
otus4  compressratio         1.00x                  -
```

Вывод: в контрольном примере лучший результат показал `gzip-9`, потому что у него максимальный `compressratio` и минимальный объем занятых данных.

## Задание 2. Определение настроек импортированного пула

### 2.1. Скачивание и распаковка архива

```bash
sudo wget -O /root/archive.tar.gz --no-check-certificate \
  'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'

sudo tar -xzf /root/archive.tar.gz -C /root
sudo ls /root
```

```text
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
```

### 2.2. Проверка возможности импорта

```bash
sudo zpool import -d /root/zpoolexport
```

```text
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
        (Note that they may be intentionally disabled if the
        'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE
```

### 2.3. Импорт пула

```bash
zpool import -d /root/zpoolexport otus
zpool status otus
```

```text
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors
```

### 2.4. Определение настроек пула

```bash
zpool get size,allocated,free,health otus
zfs get available,recordsize,compression,checksum otus
```

```text
NAME  PROPERTY   VALUE  SOURCE
otus  size       480M   -
otus  allocated  2.09M  -
otus  free       478M   -
otus  health     ONLINE -
```

```text
NAME  PROPERTY     VALUE   SOURCE
otus  available    350M    -
otus  recordsize   128K    local
otus  compression  zle     local
otus  checksum     sha256  local
```

Итоговая таблица:

| Параметр | Команда | Контрольное значение |
|---|---|---|
| Размер пула | `zpool get size otus` | `480M` |
| Тип пула | `zpool status otus` | `mirror` |
| Доступное место dataset | `zfs get available otus` | около `350M` |
| Recordsize | `zfs get recordsize otus` | `128K` |
| Сжатие | `zfs get compression otus` | `zle` |
| Контрольная сумма | `zfs get checksum otus` | `sha256` |

## Задание 3. Работа со снапшотами

### 3.1. Скачивание файла со снапшотом

Команда:

```bash
sudo wget -O /root/otus_task2.file --no-check-certificate \
  'https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download'
```

### 3.2. Восстановление snapshot через zfs receive

Команда:

```bash
sudo zfs receive otus/test@today < /root/otus_task2.file
```

### 3.3. Поиск secret_message

```bash
find /otus/test -type f -name secret_message -print
cat "$(find /otus/test -type f -name secret_message -print -quit)"
```

```text
/otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/
```

Вывод: файл `secret_message` найден, сообщение прочитано.