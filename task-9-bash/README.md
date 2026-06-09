# Задание 10: Работа с Bash

## Цель домашнего задания

Написать bash-скрипт, который ежечасно формирует отчет о работе веб-сервера и отправляет его на заданную почту.

## Описание домашнего задания

Нужно написать скрипт для `cron`, который один раз в час анализирует логи веб-сервера и отправляет отчет на email.

Отчет должен содержать:

1. IP-адреса с наибольшим числом запросов с момента последнего запуска.
2. Запрашиваемые URL с наибольшим числом запросов с момента последнего запуска.
3. Ошибки веб-сервера или приложения с момента последнего запуска.
4. HTTP-коды ответов с указанием их количества с момента последнего запуска.
5. Временной диапазон, за который сформирован отчет.

Скрипт должен предотвращать одновременный запуск нескольких копий.

## Файлы проекта

```text
README.md
Vagrantfle -- файл для создания ВМ с Ubuntu
install.sh -- скрипт с установкой скриптов, заданий, поднятия веб-сервера
scripts/web-report.sh -- основной скрипт, описание см. ниже
config/web-report -- конфигурационный файл для скрипта с указанием почты, директорий исследуемых файлов и т.д.
cron/web-report -- файл cron-задания, которое каждый час создает отчет
nginx/web-report.conf -- конфигурация сайта для Nginx
```

### `scripts/web-report.sh`

Основной bash-скрипт.

Он выполняет следующие действия:

1. Загружает настройки из `/etc/default/web-report`.
2. Ставит блокировку через `flock`, чтобы не запустились две копии скрипта одновременно.
3. Определяет период отчета: от прошлого запуска до текущего времени.
4. Через `find` находит access log и error log Nginx.
5. Отбирает строки логов за нужный период.
6. Считает топ IP-адресов.
7. Считает топ URL.
8. Считает HTTP-коды ответов.
9. Выбирает ошибки из error log.
10. Формирует текстовый отчет.
11. Отправляет отчет на email.
12. Сохраняет время текущего запуска.

### `install.sh`

Вспомогательный установочный скрипт:

1. Устанавливает `nginx`, `mailutils`, `gawk`.
2. Создает тестовую страницу `/var/www/web-report/index.html`.
3. Копирует bash-скрипт в `/usr/local/sbin/web-report.sh`.
4. Копирует конфиг скрипта в `/etc/default/web-report`.
5. Копирует cron-файл в `/etc/cron.d/web-report`.
6. Копирует nginx-конфиг в `/etc/nginx/sites-available/web-report`.
7. Включает сайт Nginx.
8. Проверяет конфигурацию Nginx.
9. Запускает Nginx.

## Настройка веб-сервера

В задании используется Nginx.
Пример обращения к веб-серверу:

```bash
curl http://localhost:9001/
```

В этом решении используются отдельные логи:

```text
/var/log/nginx/web-report-access.log
/var/log/nginx/web-report-error.log
```

`web-report-access.log` содержит обращения к веб-серверу.

Пример строки:

```text
127.0.0.1 - - [08/Jun/2026:20:10:15 +0300] "GET /index.html HTTP/1.1" 200 615
```

Значение полей:

```text
127.0.0.1       IP-адрес клиента
GET             HTTP-метод
/index.html     запрошенный URL
200             HTTP-код ответа
615             размер ответа
```

`web-report-error.log` содержит ошибки веб-сервера.

Пример строки:

```text
2026/06/08 20:11:01 [error] 1234#1234: *5 open() "/var/www/web-report/test" failed
```

## Формирование периода отчета

Скрипт хранит время прошлого запуска в файле:

```text
/var/lib/web-report/last_run_epoch
```

При первом запуске скрипт берет период за последний час.
При следующих запусках скрипт берет период от времени прошлого запуска до текущего времени
После успешной отправки отчета скрипт записывает текущее время в state-файл.

## Защита от повторного запуска через flock

В скрипте используется `flock`.

Фрагмент:

```bash
exec 200>"$LOCK_FILE"

if ! flock -n 200; then
    echo "Script is already running"
    exit 0
fi
```

`exec 200>"$LOCK_FILE"` открывает lock-файл на файловом дескрипторе `200`.
`flock -n 200` пытается поставить блокировку.
Если одна копия скрипта уже работает, вторая копия не сможет получить блокировку и завершится.

## Парсинг логов

`sed` используется для извлечения данных из access log.

Извлечение URL:

```bash
sed -nE 's#^[^"]*"[^ ]+ ([^ ?"]+).*$#\1#p'
```

Извлечение HTTP-кодов:

```bash
sed -nE 's#^.*" ([0-9]{3}) [0-9-]+.*$#\1#p'
```

Отбор ошибок:

```bash
sed -nE '/error|crit|alert|emerg|failed|denied|fatal|exception/Ip'
```

## Установка

Запустить установку:

```bash
sudo ./install.sh
```
или сделать все вручную по инструкции ниже.

Установить пакеты:

```bash
sudo apt update
sudo apt install -y nginx mailutils gawk
```

Скопировать bash-скрипт:

```bash
sudo cp scripts/web-report.sh /usr/local/sbin/web-report.sh
sudo chmod +x /usr/local/sbin/web-report.sh
```

Скопировать конфиг скрипта:

```bash
sudo cp config/web-report /etc/default/web-report
```

Скопировать cron-файл:

```bash
sudo cp cron/web-report /etc/cron.d/web-report
sudo chmod 0644 /etc/cron.d/web-report
```

Скопировать nginx-конфиг:

```bash
sudo cp nginx/web-report.conf /etc/nginx/sites-available/web-report
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/web-report /etc/nginx/sites-enabled/web-report
```

Создать каталог сайта:

```bash
sudo mkdir -p /var/www/web-report
```

Создать тестовую страницу:

```bash
cat <<'HTML' | sudo tee /var/www/web-report/index.html
<!doctype html>
<html>
<head><title>web-report</title></head>
<body>web-report test page</body>
</html>
HTML
```

Проверить Nginx:

```bash
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
```

## Создание обращений к серверу

Выполнить несколько запросов:

```bash
curl http://localhost:9001/
curl http://localhost:9001/
curl http://localhost:9001/not-found
curl http://localhost:9001/not-found
curl http://localhost:9001/app-error
curl http://localhost:9001/
curl http://localhost:9001/
curl http://localhost:9001/not-found
curl http://localhost:9001/not-found
curl http://localhost:9001/app-error
```

Проверить access log:

```bash
sudo tail /var/log/nginx/web-report-access.log
```

Пример:

```text
127.0.0.1 - - [09/Jun/2026:15:55:22 +0000] "GET / HTTP/1.1" 200 104 "-" "curl/8.5.0"
127.0.0.1 - - [09/Jun/2026:15:55:22 +0000] "GET / HTTP/1.1" 200 104 "-" "curl/8.5.0"
127.0.0.1 - - [09/Jun/2026:15:55:23 +0000] "GET /not-found HTTP/1.1" 404 162 "-" "curl/8.5.0"
127.0.0.1 - - [09/Jun/2026:15:55:23 +0000] "GET /not-found HTTP/1.1" 404 162 "-" "curl/8.5.0"
127.0.0.1 - - [09/Jun/2026:15:55:23 +0000] "GET /app-error HTTP/1.1" 500 186 "-" "curl/8.5.0"
```

## Ручная проверка скрипта

Запустить скрипт вручную:

```bash
sudo /usr/local/sbin/web-report.sh
```

Проверить state-файл:

```bash
sudo cat /var/lib/web-report/last_run_epoch
```

Если `mailutils` настроен, отчет будет отправлен на адрес из `/etc/default/web-report`.

## Проверка cron

Проверить cron-файл:

```bash
cat /etc/cron.d/web-report
```

Проверить логи cron:

```bash
sudo journalctl -u cron
```

## Пример отчета

```text
Return-Path: <root@vagrant>
X-Original-To: vagrant
Delivered-To: vagrant@systemd.local
Received: by vagrant.aktiv.guardant.ru (Postfix, from userid 0)
        id A7D8C1C0D2D; Tue,  9 Jun 2026 15:55:48 +0000 (UTC)
Subject: Web server hourly report
To: vagrant@systemd.local
User-Agent: mail (GNU Mailutils 3.17)
Date: Tue,  9 Jun 2026 15:55:48 +0000
Message-Id: <20260609155548.A7D8C1C0D2D@vagrant.aktiv.guardant.ru>
From: root <root@vagrant>

Web server hourly report
Period: 2026-06-09 14:55:48 +0000 — 2026-06-09 15:55:48 +0000
Access log: /var/log/nginx/web-report-access.log
Error log: /var/log/nginx/web-report-error.log

Top IP addresses:
     10 127.0.0.1

Top requested URLs:
      4 /not-found
      4 /
      2 /app-error

HTTP response codes:
      4 404
      4 200
      2 500

Web server / application errors:
No errors
```