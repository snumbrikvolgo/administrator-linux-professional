# Задание 5: Работа с NFS

## Цель домашнего задания

Научиться самостоятельно разворачивать сервис NFS и подключать к нему клиентов;

## Описание домашнего задания

- запустить 2 виртуальные машины: сервер NFS и клиент NFS;
- на сервере NFS подготовить и экспортировать директорию;
- в экспортированной директории создать поддиректорию `upload` с правами на запись;
- на клиенте настроить автоматическое монтирование экспортированной директории при старте виртуальной машины;
- монтирование и работа NFS на клиенте должны использовать NFSv3.

## Используемый стенд

Хостовая система: Windows 11.

Инструменты:

- Vagrant;
- VirtualBox;
- локальный Vagrant box на базе Ubuntu 24.04 Server: `bento-ubuntu-24.04-local`;
- две VM в private network: сервер `192.168.50.10` и клиент `192.168.50.11`.

## Файлы в репозитории

Назначение файлов:

- `Vagrantfile` -- создает две VM: `nfss` и `nfsc`, назначает private IP и запускает provisioning-скрипты с настройкой сервера и клиента.
- `nfss_script.sh` -- устанавливает и настраивает NFS-сервер, создает `/srv/share/upload`, экспортирует `/srv/share` для клиента.
- `nfsc_script.sh` -- устанавливает NFS-клиент, добавляет запись в `/etc/fstab`, включает автоматическое монтирование `/mnt` через systemd automount.
- `README.md` -- описание стенда, команд запуска, проверок и ожидаемых выводов.

## Запуск стенда

В каталоге с файлами выполнить:

```bash
vagrant up
```

Подключение к серверу:

```bash
vagrant ssh nfss
```

Подключение к клиенту:

```bash
vagrant ssh nfsc
```

## Настройка NFS-сервера

Скрипт `nfss_script.sh` выполняет следующие действия:

```bash
apt-get update
apt-get install -y nfs-kernel-server
```

Порты NFS/RPC должны слушаться:

```bash
ss -tnplu | grep -E ':(111|2049)\b'
```

Вывод:

```text
udp   UNCONN 0      0             0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=2464,fd=5),("systemd",pid=1,fd=92))
udp   UNCONN 0      0                [::]:111           [::]:*    users:(("rpcbind",pid=2464,fd=7),("systemd",pid=1,fd=97))
tcp   LISTEN 0      4096          0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=2464,fd=4),("systemd",pid=1,fd=91))
tcp   LISTEN 0      64            0.0.0.0:2049       0.0.0.0:*                                                             
tcp   LISTEN 0      4096             [::]:111           [::]:*    users:(("rpcbind",pid=2464,fd=6),("systemd",pid=1,fd=96))
tcp   LISTEN 0      64               [::]:2049          [::]:*  
```

Создает экспортируемую директорию и поддиректорию для записи:

```bash
mkdir -p /srv/share/upload
chown -R nobody:nogroup /srv/share
chmod 0777 /srv/share/upload
```

Создает `/etc/exports`:

```bash
/srv/share 192.168.50.11/32(rw,sync,no_subtree_check,root_squash)
```

Применяет экспорт:

```bash
exportfs -r
exportfs -s
```

Вывод:

```text
/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

## Настройка NFS-клиента

Скрипт `nfsc_script.sh` выполняет следующие действия:

```bash
apt-get update
apt-get install -y nfs-common
```

Создает точку монтирования:

```bash
mkdir -p /mnt
```

Добавляет в `/etc/fstab` строку:

```text
192.168.50.10:/srv/share /mnt nfs vers=3,noauto,x-systemd.automount,_netdev 0 0
```

После изменения `/etc/fstab` выполняется:

```bash
systemctl daemon-reload
systemctl restart remote-fs.target
```

## Проверка работоспособности по методичке

Этот раздел повторяет проверки из методички в той же логике: сначала проверяется запись с сервера и клиента, затем поведение после перезагрузки клиента, затем поведение после перезагрузки сервера и повторная проверка клиента.

### 1. Проверка записи с сервера на клиент

Зайти на сервер:

```bash
vagrant ssh nfss
```

Создать тестовый файл в экспортированной директории:

```bash
sudo touch /srv/share/upload/check_file
ls -l /srv/share/upload
```

Ожидаемый вывод должен содержать файл `check_file`:

```text
-rw-r--r-- 1 root root 0 Jun  6 20:14 check_file```

Зайти на клиент:

```bash
vagrant ssh nfsc
```

Перейти в смонтированную директорию и проверить наличие файла, созданного на сервере:

```bash
cd /mnt/upload
ls -l
```

Вывод:

```text
-rw-r--r-- 1 root root 0 Jun  6 20:14 check_file
```

### 2. Проверка записи с клиента на сервер

На клиенте создать файл:

```bash
sudo touch /mnt/upload/client_file
ls -l /mnt/upload
```

Вывод:

```text
-rw-r--r-- 1 root   root    0 Jun  6 20:14 check_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:14 client_file
```

На сервере проверить, что файл клиента появился в реальной директории `/srv/share/upload`:

```bash
ls -l /srv/share/upload
```

Ожидаемый вывод должен содержать:

```text
-rw-r--r-- 1 root   root    0 Jun  6 20:14 check_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:14 client_file
```

### 3. Предварительная проверка клиента после перезагрузки

Перезагрузить клиента:

```bash
vagrant reload nfsc
```

Зайти на клиента:

```bash
vagrant ssh nfsc
```

Проверить, что automount снова сработал при обращении к `/mnt/upload`:

```bash
cd /mnt/upload
ls -l
```

Вывод:

```text
-rw-r--r-- 1 root   root    0 Jun  6 20:14 check_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:14 client_file
```

### 4. Проверка сервера после перезагрузки

Перезагрузить сервер:

```bash
vagrant reload nfss
```

Зайти на сервер:

```bash
vagrant ssh nfss
```

Проверить, что файлы остались на сервере:

```bash
ls -l /srv/share/upload
```

Вывод:

```text
-rw-r--r-- 1 root   root    0 Jun  6 20:14 check_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:14 client_file
```

Проверить экспорты:

```bash
sudo exportfs -s
```

Вывод:

```text
/srv/share  192.168.50.11/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

Проверить работу RPC:

```bash
showmount -a 192.168.50.10
```

Вывод:

```text
All mount points on 192.168.50.10:
192.168.50.11:/srv/share
```

### 5. Финальная проверка клиента после перезагрузки сервера

Перезагрузить клиента:

```bash
vagrant reload nfsc
```

Зайти на клиента:

```bash
vagrant ssh nfsc
```

Проверить RPC:

```bash
showmount -a 192.168.50.10
```

Вывод:

```text
Export list for 192.168.50.10:
/srv/share 192.168.50.11/32
```

Зайти в каталог `/mnt/upload`:

```bash
cd /mnt/upload
```

Проверить статус монтирования:

```bash
mount | grep mnt
```

Вывод:

```text
systemd-1 on /mnt type autofs (rw,relatime,fd=52,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=4273)
192.168.50.10:/srv/share on /mnt type nfs (rw,relatime,vers=3,rsize=262144,wsize=262144,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.50.10,mountvers=3,mountport=58201,mountproto=udp,local_lock=none,addr=192.168.50.10,_netdev)
```

Проверить наличие ранее созданных файлов:

```bash
ls -l /mnt/upload
```

Вывод:

```text
-rw-r--r-- 1 root   root    0 Jun  6 20:14 check_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:14 client_file
```

Создать финальный файл:

```bash
sudo touch /mnt/upload/final_check
ls -l /mnt/upload
```

Вывод:

```text
-rw-r--r-- 1 root   root    0 Jun  6 20:14 check_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:14 client_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6  2026 final_check
```

Проверить на сервере:

```bash
vagrant ssh nfss
ls -l /srv/share/upload
```

Вывод:

```text
-rw-r--r-- 1 root   root    0 Jun  6 20:14 check_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:14 client_file
-rw-r--r-- 1 nobody nogroup 0 Jun  6 20:26 final_check
```

Если все проверки прошли успешно, демонстрационный стенд работоспособен: NFS-сервер экспортирует директорию, клиент автоматически монтирует ее через systemd automount, запись в `upload` работает, после перезагрузки клиента и сервера доступ сохраняется, а в параметрах монтирования присутствует `vers=3`.