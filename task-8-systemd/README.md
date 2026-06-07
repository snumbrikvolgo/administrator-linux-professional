# Задание 8: Работа с systemd

## Цель домашнего задания

Научиться редактировать существующие unit-файлы и создавать новые unit-файлы для systemd.

## Описание домашнего задания

1. Написать service, который раз в 30 секунд мониторит лог на наличие ключевого слова. Файл лога и ключевое слово должны задаваться в `/etc/default`.
2. Установить `spawn-fcgi` и создать unit-файл `spawn-fcgi.service` на основе логики init-скрипта.
3. Доработать unit-файл Nginx для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.

## Используемое окружение

Решение реализовано через Vagrant и shell provisioner.

Используемая виртуальная машина:

- ОС: Ubuntu 22.04;
- hostname: `systemd`;
- провайдер: VirtualBox;
- CPU: 2;
- RAM: 2048 МБ;
- проброс порта первого инстанса Nginx: `127.0.0.1:9001 -> 9001`;
- проброс порта второго инстанса Nginx: `127.0.0.1:9002 -> 9002`.

## Запуск стенда

Запуск виртуальной машины и автоматической настройки:

```bash
vagrant up
```

Повторный запуск provision без пересоздания виртуальной машины:

```bash
vagrant provision
```

Подключение к виртуальной машине:

```bash
vagrant ssh
```

Остановка стенда:

```bash
vagrant halt
```

Удаление стенда:

```bash
vagrant destroy -f
```

## Ход выполнения provision.sh

### 1. Установка пакетов

В начале скрипта обновляется индекс пакетов и устанавливаются необходимые программы:

```bash
apt-get update
apt-get install -y spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid nginx curl
```

Пакеты нужны для выполнения всех частей задания:

- `spawn-fcgi` -- для запуска FastCGI-процесса;
- `php-cgi` -- CGI-приложение, которое будет запускаться через `spawn-fcgi`;
- `nginx` -- веб-сервер для запуска нескольких инстансов;
- `curl` -- для проверки HTTP-ответов от двух инстансов Nginx.

### 2. Создание watchlog service и таймера

Создается файл `/etc/default/watchlog`:

```bash
WORD="ALERT"
LOG="/var/log/watchlog.log"
```

В этом файле задаются две переменные:

- `WORD` -- ключевое слово для поиска;
- `LOG` -- путь к лог-файлу, который нужно проверять.

Создается тестовый лог `/var/log/watchlog.log`, в котором есть строка с ключевым словом `ALERT`.

Затем создается скрипт `/opt/watchlog.sh`:

```bash
if grep -Fq -- "$WORD" "$LOG"; then
  logger "$DATE: I found word, Master!"
fi
```

Команда `grep -Fq` ищет ключевое слово в лог-файле как обычный текст. Если слово найдено, команда `logger` пишет сообщение в системный журнал.

Создается unit-файл `/etc/systemd/system/watchlog.service`:

```ini
[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh ${WORD} ${LOG}
```

Параметр `Type=oneshot` означает, что сервис запускает одну короткую задачу и завершается. `EnvironmentFile` подключает переменные из `/etc/default/watchlog`. Через `ExecStart` systemd запускает скрипт и передает ему ключевое слово и путь к логу.

Создается таймер `/etc/systemd/system/watchlog.timer`:

```ini
[Timer]
OnBootSec=30
OnUnitActiveSec=30
AccuracySec=1s
Unit=watchlog.service
```

Таймер запускает `watchlog.service` через 30 секунд после загрузки, затем повторяет запуск каждые 30 секунд после предыдущего запуска сервиса.


```bash
systemctl start watchlog.timer
```

Проверяем:

```sh
$ tail -n 1000 /var/log/syslog  | grep word
2026-06-07T18:52:25.212366+00:00 vagrant root: Sun Jun  7 06:52:25 PM UTC 2026: I found word, Master!
```

### 3. Создание spawn-fcgi.service

Создается каталог `/etc/spawn-fcgi` и файл настроек `/etc/spawn-fcgi/fcgi.conf`:

```bash
SOCKET=/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s /run/php-fcgi.sock -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

Здесь задается Unix socket `/run/php-fcgi.sock` и параметры запуска `php-cgi`.

В unit-файле `/etc/systemd/system/spawn-fcgi.service` используется этот конфигурационный файл:

```ini
[Service]
Type=simple
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStartPre=/bin/rm -f /run/php-fcgi.sock
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
ExecStopPost=/bin/rm -f /run/php-fcgi.sock
KillMode=process
Restart=on-failure
```

Пояснение:

- `Type=simple` -- systemd считает сервис запущенным сразу после старта процесса `spawn-fcgi`;
- `EnvironmentFile` -- подключает параметры из `/etc/spawn-fcgi/fcgi.conf`;
- `ExecStartPre` -- удаляет старый socket перед запуском;
- `ExecStart` -- запускает `spawn-fcgi` в foreground-режиме через параметр `-n`;
- `ExecStopPost` -- удаляет socket после остановки сервиса;
- `Restart=on-failure` -- перезапускает сервис при аварийном завершении.

После создания unit-файла сервис включается и запускается:

```bash
systemctl start spawn-fcgi
systemctl status spawn-fcgi
```

### 4. Создание нескольких инстансов Nginx

Создается шаблонный unit-файл `/etc/systemd/system/nginx@.service`.

Главная идея шаблонного unit-файла -- использовать имя инстанса в путях к конфигурации и PID-файлу:

```ini
PIDFile=/run/nginx-%i.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%i.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%i.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%i.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%i.pid
```

`%i` -- это имя инстанса. Например, при запуске `nginx@first.service` systemd подставляет `first`, а при запуске `nginx@second.service` -- `second`.

Поэтому:

- `nginx@first.service` использует `/etc/nginx/nginx-first.conf` и `/run/nginx-first.pid`;
- `nginx@second.service` использует `/etc/nginx/nginx-second.conf` и `/run/nginx-second.pid`.

Создаются два отдельных конфигурационных файла Nginx:

```text
/etc/nginx/nginx-first.conf
/etc/nginx/nginx-second.conf
```

Первый инстанс слушает порт `9001` и возвращает ответ:

```text
first nginx instance
```

Второй инстанс слушает порт `9002` и возвращает ответ:

```text
second nginx instance
```

Запуск инстансов выполняется командами:

```bash
systemctl start nginx@first
systemctl start nginx@second
```

## Вывод из provision.sh

В конце `provision.sh` выполняет проверки и выводит результат по каждому пункту задания.

```text
    default: === watchlog ===
    default: active
    default: NEXT                        LEFT LAST                        PASSED UNIT           ACTIVATES
    default: Sun 2026-06-07 19:10:21 UTC  24s Sun 2026-06-07 19:09:51 UTC 5s ago watchlog.timer watchlog.service
    default: 
    default: 1 timers listed.
    default: Pass --all to see loaded but inactive timers, too.
    default: Jun 07 19:09:51 systemd root[11112]: Sun Jun  7 07:09:51 PM UTC 2026: I found word, Master!
    default: === spawn-fcgi ===
    default: active
    default: /run/php-fcgi.sock exists
    default: www-data   11116       1  3 19:09 ?        00:00:00 /usr/bin/php-cgi
    default: www-data   11122   11116  0 19:09 ?        00:00:00 /usr/bin/php-cgi
    default: www-data   11123   11116  0 19:09 ?        00:00:00 /usr/bin/php-cgi
    default: www-data   11124   11116  0 19:09 ?        00:00:00 /usr/bin/php-cgi
    default: www-data   11125   11116  0 19:09 ?        00:00:00 /usr/bin/php-cgi
    default: === nginx instances ===
    default: active
    default: active
    default: LISTEN 0      511          0.0.0.0:9002      0.0.0.0:*    users:(("nginx",pid=11291,fd=5),("nginx",pid=11290,fd=5),("nginx",pid=11289,fd=5))
    default: LISTEN 0      511          0.0.0.0:9001      0.0.0.0:*    users:(("nginx",pid=11242,fd=5),("nginx",pid=11241,fd=5),("nginx",pid=11240,fd=5))
    default: first nginx instance
    default: second nginx instance
```

## Проверка после запуска стенда

### Проверка watchlog

```bash
systemctl status watchlog.timer
systemctl list-timers watchlog.timer
journalctl -u watchlog.service --no-pager
journalctl -t root --no-pager | grep 'I found word'
```

Ожидаемый результат: таймер активен, а в журнале есть сообщение `I found word, Master!`.

### Проверка spawn-fcgi

```bash
systemctl status spawn-fcgi.service
ss -xl | grep php-fcgi
ps -ef | grep '[p]hp-cgi'
```

Ожидаемый результат: сервис `spawn-fcgi.service` активен, существует socket `/run/php-fcgi.sock`, запущен процесс `php-cgi`.

### Проверка нескольких инстансов Nginx

```bash
systemctl status nginx@first.service
systemctl status nginx@second.service
ss -tnlp | grep nginx
curl http://127.0.0.1:9001/
curl http://127.0.0.1:9002/
```

Ожидаемый результат: оба сервиса активны, Nginx слушает порты `9001` и `9002`, каждый порт возвращает ответ своего инстанса.