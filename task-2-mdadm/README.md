# Задание 2. Работа с mdadm

## Цель домашнего задания

Научиться работать с программным RAID в ОС Linux: создать RAID-массив, смоделировать отказ одного из дисков, восстановить массив, создать GPT-таблицу разделов и смонтировать файловые системы.

## Описание домашнего задания

1) Добавить в виртуальную машину несколько дисков.
2) Собрать RAID-0/1/5/10 на выбор.
3) Сломать и починить RAID.
4) Создать GPT-таблицу, пять разделов и смонтировать их в системе.

## Ход выполнения домашнего задания

### Основное задание

Все дальнейшие действия выполнялись при использовании Proxmox QEMU. В виртуальную машину были добавлены четыре дополнительных виртуальных диска размером по 1 GiB каждый.

Для выполнения задания выбран RAID-5. Три диска используются в составе массива, четвертый диск используется для замены диска после имитации его отказа:

```text
/dev/sdb  1 GiB  первый диск RAID-5
/dev/sdc  1 GiB  второй диск RAID-5, который будет выведен из строя
/dev/sdd  1 GiB  третий диск RAID-5
/dev/sde  1 GiB  новый диск для восстановления массива
```

Проверяем наличие добавленных дисков:

```sh
$ lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

```text
NAME    SIZE TYPE FSTYPE MOUNTPOINTS
sda      100G disk
├─sda1     1M part
└─sda2   100G part ext4     /
sdb       1G disk
sdc       1G disk
sdd       1G disk
sde       1G disk
```

Диск `/dev/sda` в RAID-массив не включается.

Устанавливаем необходимые пакеты:

```sh
$ sudo apt update
$ sudo apt install -y mdadm parted
```

### Создание RAID-5

Создание RAID вынесено в скрипт `create_raid5.sh`. Скрипт удаляет старые метаданные RAID с дисков `/dev/sdb`, `/dev/sdc`, `/dev/sdd`, создает массив `/dev/md0` уровня RAID-5 и выводит его состояние.

Запускаем скрипт:

```sh
$ ./create_raid5.sh
```

Ожидаемое состояние исправного массива:

```text
Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 sdd[3] sdc[1] sdb[0]
      2093056 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/3] [UUU]

/dev/md0:
    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       1       8       32        1      active sync   /dev/sdc
       3       8       48        2      active sync   /dev/sdd
```

Обозначение `[UUU]` показывает, что все три диска RAID-5 находятся в рабочем состоянии.

### Имитация отказа RAID

Для проверки отказоустойчивости искусственно помечаем диск `/dev/sdc` как неисправный:

```sh
$ sudo mdadm /dev/md0 --fail /dev/sdc
mdadm: set /dev/sdc faulty in /dev/md0
```

Проверяем состояние массива:

```sh
$ cat /proc/mdstat
```

Ожидаемое состояние массива после отказа одного диска:

```text
Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 sdd[3] sdc[1](F) sdb[0]
      2093056 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/2] [U_U]
```

Обозначение `(F)` показывает неисправный диск, а `[U_U]` -- что один из трех компонентов массива недоступен. RAID-5 продолжает работать, но больше не имеет защиты от отказа еще одного диска.

Удаляем неисправный диск из массива:

```sh
$ sudo mdadm /dev/md0 --remove /dev/sdc
mdadm: hot removed /dev/sdc from /dev/md0
```

Проверяем результат:

```sh
$ cat /proc/mdstat
```

```text
Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 sdd[3] sdb[0]
      2093056 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/2] [U_U]
```

### Восстановление RAID

Вместо удаленного диска `/dev/sdc` добавляем новый диск `/dev/sde`, который ранее не входил в массив:

```sh
$ sudo mdadm --zero-superblock --force /dev/sde
$ sudo mdadm /dev/md0 --add /dev/sde
mdadm: added /dev/sde
```

Во время восстановления состояние массива можно проверить командой:

```sh
$ cat /proc/mdstat
```

```text
Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 sde[4] sdd[3] sdb[0]
      2093056 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/2] [U_U]
      [===================>.]  recovery = 95.8% (1003904/1046528) finish=0.0min speed=200780K/sec

unused devices: <none>
```

Дожидаемся окончания восстановления и снова проверяем массив:

```sh
$ sudo mdadm --wait /dev/md0
$ cat /proc/mdstat
$ sudo mdadm -D /dev/md0
```

Ожидаемое состояние массива после восстановления:

```text
Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 sde[4] sdd[3] sdb[0]
      2093056 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/3] [UUU]

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync   /dev/sdb
       4       8       64        1      active sync   /dev/sde
       3       8       48        2      active sync   /dev/sdd
```

Массив восстановлен: вместо удаленного `/dev/sdc` активным компонентом стал `/dev/sde`, а состояние `[UUU]` подтверждает работоспособность всех трех компонентов RAID-5.

### Создание GPT-таблицы и пяти разделов

После проверки восстановления RAID создаем GPT-таблицу разделов на устройстве массива `/dev/md0`.

Создаем GPT-таблицу:

```sh
$ sudo parted -s /dev/md0 mklabel gpt
```

Создаем пять разделов:

```sh
$ sudo parted -s -a optimal /dev/md0 mkpart part1 ext4 1MiB 20%
$ sudo parted -s -a optimal /dev/md0 mkpart part2 ext4 20% 40%
$ sudo parted -s -a optimal /dev/md0 mkpart part3 ext4 40% 60%
$ sudo parted -s -a optimal /dev/md0 mkpart part4 ext4 60% 80%
$ sudo parted -s -a optimal /dev/md0 mkpart part5 ext4 80% 100%
$ sudo partprobe /dev/md0
```

Создаем файловые системы `ext4` на разделах:

```sh
$ for i in {1..5}; do sudo mkfs.ext4 -F /dev/md0p$i; done
```

Создаем каталоги для монтирования и монтируем разделы:

```sh
$ sudo mkdir -p /raid/part{1..5}
$ for i in {1..5}; do sudo mount /dev/md0p$i /raid/part$i; done
```

Проверяем монтирование:

```sh
$ lsblk -f /dev/md0
```

Ожидаемый результат:

```text
NAME FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
md0
├─md0p1
│    ext4   1.0         6ad7b100-83b2-4ec2-9c88-69899d1a9411  337.3M     0% /raid/part1
├─md0p2
│    ext4   1.0         9ec8301f-f308-407c-9a00-ba2f5295e301  338.1M     0% /raid/part2
├─md0p3
│    ext4   1.0         6e07ae79-7265-44fc-8e8c-245af3414ceb  337.3M     0% /raid/part3
├─md0p4
│    ext4   1.0         1e38180a-f6ef-44be-b34f-405e19854883  338.1M     0% /raid/part4
└─md0p5
     ext4   1.0         e369987f-5469-449a-b317-68327a6135ba  337.3M     0% /raid/part5
```

## Итог

В виртуальную машину были добавлены четыре дополнительных диска размером по 1 GiB. Из трех дисков был собран массив RAID-5 `/dev/md0`. Затем был смоделирован отказ диска `/dev/sdc`, неисправный диск удален из массива, а вместо него добавлен новый диск `/dev/sde`. После завершения восстановления состояние массива вернулось к `[UUU]`.

После поломки и починки RAID на восстановленном устройстве `/dev/md0` была создана GPT-таблица, пять разделов с файловой системой `ext4`, которые были смонтированы в каталоги `/raid/part1`-...-`/raid/part5`.
