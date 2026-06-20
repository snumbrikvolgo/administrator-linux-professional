# Задание 14: Docker

## Цель домашнего задания

Освоить базовые принципы работы с Docker: создание образов, запуск контейнеров, работа с Docker Compose и сохранение данных через volume.

## Описание домашнего задания

Необходимо:

- установить Docker и Docker Compose;
- создать кастомный образ `nginx` на базе `alpine`;
- изменить дефолтную страницу `nginx`;
- описать разницу между образом и контейнером;
- ответить, можно ли собрать ядро в контейнере;
- собрать образ и отправить его в Docker Hub;
- выполнить задание со звездочкой: описать `docker-compose.yml` для Redmine с опцией `build`, добавить кастомную тему и настроить volume для хранения данных.

## Запуск Docker

Чтобы запускать Docker без `sudo`, можно добавить текущего пользователя в группу `docker`, затем перелогиниться:

```bash
sudo usermod -aG docker $USER
```

## Основная часть: кастомный nginx

Для `nginx` используется файл `Dockerfile`.

Образ собирается на базе `nginx:1.27-alpine`. В образ копируется кастомная страница `nginx/index.html`, порт `80` объявляется через `EXPOSE`, а основной процесс запускается командой:

```dockerfile
CMD ["nginx", "-g", "daemon off;"]
```

Сборка образа:

```bash
docker build -t snumbrikvolgo/task-14-nginx:1.0 .
```

Вывод:

```text
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon   5.12kB
Step 1/4 : FROM nginx:1.27-alpine
 ---> 65645c7bb6a0
Step 2/4 : COPY nginx/index.html /usr/share/nginx/html/index.html
 ---> Using cache
 ---> 8bf4642979a6
Step 3/4 : EXPOSE 80
 ---> Using cache
 ---> 0f4257aa9c7d
Step 4/4 : CMD ["nginx", "-g", "daemon off;"]
 ---> Using cache
 ---> 0c272f353145
Successfully built 0c272f353145
Successfully tagged snumbrikvolgo/task-14-nginx:1.0
```

Запуск контейнера:

```bash
$ docker run -d -p 8080:80 --name task-14-nginx snumbrikvolgo/task-14-nginx:1.0
c27d5639dedd0fbe8d0f8c9cc587cdd4cbddbd40c0861c702ed9126004bdb1cb
```

Проверка запущенного контейнера:

```bash
$ docker ps

CONTAINER ID   IMAGE                               COMMAND                  CREATED          STATUS          PORTS                               NAMES
c27d5639dedd   snumbrikvolgo/task-14-nginx:1.0   "/docker-entrypoint.…"   31 seconds ago   Up 30 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   task-14-nginx
```

Проверка HTTP-ответа:

```bash
curl http://127.0.0.1:8080
```

Вывод:

```html
<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Task 14 Docker</title>
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        font-family: Arial, sans-serif;
        color: #172033;
        background: #f4f7fb;
      }

      main {
        max-width: 720px;
        padding: 40px;
        text-align: center;
      }

      h1 {
        margin: 0 0 16px;
        font-size: 40px;
      }

      p {
        margin: 0;
        font-size: 20px;
        line-height: 1.5;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Docker homework</h1>
      <p>Custom nginx image based on Alpine is running successfully.</p>
    </main>
  </body>
</html>
```

Просмотр логов:

```bash
docker logs task-14-nginx
```

Вывод:

```text
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/06/19 19:57:11 [notice] 1#1: using the "epoll" event method
2026/06/19 19:57:11 [notice] 1#1: nginx/1.27.5
2026/06/19 19:57:11 [notice] 1#1: built by gcc 14.2.0 (Alpine 14.2.0) 
2026/06/19 19:57:11 [notice] 1#1: OS: Linux 6.6.87.2-microsoft-standard-WSL2
2026/06/19 19:57:11 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1024:1048576
2026/06/19 19:57:11 [notice] 1#1: start worker processes
2026/06/19 19:57:11 [notice] 1#1: start worker process 30
2026/06/19 19:57:11 [notice] 1#1: start worker process 31
2026/06/19 19:57:11 [notice] 1#1: start worker process 32
2026/06/19 19:57:11 [notice] 1#1: start worker process 33
2026/06/19 19:57:11 [notice] 1#1: start worker process 34
2026/06/19 19:57:11 [notice] 1#1: start worker process 35
2026/06/19 19:57:11 [notice] 1#1: start worker process 36
2026/06/19 19:57:11 [notice] 1#1: start worker process 37
172.17.0.1 - - [19/Jun/2026:19:57:55 +0000] "GET / HTTP/1.1" 200 836 "-" "curl/7.81.0" "-"
```

Остановка контейнера:

```bash
docker stop task-14-nginx
```

Публикация образа в Docker Hub:

```bash
docker login
docker push snumbrikvolgo/task-14-nginx:1.0
```

Ссылка на репозиторий Docker Hub:

```text
https://hub.docker.com/r/snumbrikvolgo/task-14-nginx
```

## Разница между образом и контейнером

Образ Docker -- это неизменяемый шаблон, из которого создаются контейнеры.
В образ входят файловая система, зависимости, конфигурация и команда запуска приложения.

Контейнер -- это запущенный экземпляр образа.
У контейнера есть собственный стейт: процессы, сеть, временные изменения файловой системы и привязанные volume.
Один и тот же образ можно использовать для запуска нескольких независимых контейнеров.

Вывод: образ отвечает на вопрос "что запускать", а контейнер -- "какой конкретный экземпляр сейчас запущен".

## Можно ли в контейнере собрать ядро

Да, в контейнере можно собрать ядро Linux как набор файлов: установить компилятор, исходники, зависимости и выполнить `make`. Окружение сборки получается воспроизводимым.

Но контейнер не загружает собранное ядро сам по себе и обычно использует ядро хостовой системы.
Для установки и загрузки нового ядра нужны операции уже на хосте или в виртуальной машине.

## Задание со звездочкой: Redmine с темой Bleuclair

Для Redmine подготовлен `docker-compose.yml` с двумя сервисами:

- `redmine` -- приложение Redmine, собирается через `build` из `redmine/Dockerfile`;
- `db` -- PostgreSQL 16 для хранения данных Redmine.

В `redmine/Dockerfile` используется образ `redmine:6.0`. В него устанавливается тема Farend Bleuclair из репозитория `farend/redmine_theme_farend_bleuclair`, ветка `redmine6.0`. Для Redmine 6 темы должны находиться в каталоге `/themes/<theme_name>/stylesheets/application.css`, поэтому тема кладется в `/usr/src/redmine/themes/bleuclair`.

База данных нужна, потому что Redmine хранит в ней пользователей, проекты, задачи, настройки и выбранную тему оформления. Без отдельной БД данные приложения будут легко теряться при пересоздании контейнера.

Для сохранения данных настроены volume:

- `postgres_data` -- база данных PostgreSQL;
- `redmine_files` -- загруженные файлы Redmine.

Запуск Redmine:

```bash
$ docker compose up -d --build
[+] Building 43860.6s (10/10) FINISHED [+] Running 4/4
[+] Running 6/6
 ✔ redmine                              Built                                                                      0.0s 
 ✔ Network task-14-docker_default       Created                                                                    0.1s 
 ✔ Volume task-14-docker_postgres_data  Created                                                                    0.0s 
 ✔ Volume task-14-docker_redmine_files  Created                                                                    0.0s 
 ✔ Container task-14-docker-db-1        Started                                                                    1.8s 
 ✔ Container task-14-docker-redmine-1   Started                                                                    2.5s 
```

Проверка контейнеров:

```bash
$ docker compose ps
NAME                       IMAGE                           COMMAND                  SERVICE   CREATED              STATUS              PORTS
task-14-docker-db-1        postgres:16-alpine              "docker-entrypoint.s…"   db        About a minute ago   Up About a minute   5432/tcp
task-14-docker-redmine-1   task-14-redmine-bleuclair:6.0   "/docker-entrypoint.…"   redmine   About a minute ago   Up About a minute   0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp
```

Проверка доступности Redmine:

```bash
curl -I http://127.0.0.1:3000
```

Вывод:

```text
HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 1; mode=block
x-content-type-options: nosniff
x-download-options: noopen
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
content-type: text/html; charset=utf-8
vary: Accept
etag: W/"a76deb530fa85b00a93d5c7a477a9b47"
cache-control: max-age=0, private, must-revalidate
set-cookie: _redmine_session=VHVqOHN3TlVIQ1VrNlhkMnhSRXBiNDlhTFN6Vi9MaXdxYUdJRk9uLytPNTVQdm00Ym0yeExVaTZyakpTN3krcmNCK05sSFlBK2E2amhaSlloV1kzL3lDOHhJY2RQVVZYOTZYeEFldnROdXc0MS9nTE5peks3Y0NDUVVhaHhFSkc1V1M0TzV3Rm94NjdwT1dwR0w3eXpQbzYybWVWOWwydmhqQ1RHVzZ5M2tJZVJJV3YrNXhvd2Q2MVkyVTAwTzNrLS1EUlpyYUR5MjFOQjZjeGRyLzJlNENBPT0%3D--07588080df64e5c512e913caf080c7b3d6aeb0cc; path=/; httponly; samesite=lax
x-request-id: 8d9ceeee-1dd3-4c56-938c-8d46391a8ad9
x-runtime: 0.022554
content-length: 0
```

Проверка, что тема попала в образ:

```bash
$ docker compose exec redmine ls -la /usr/src/redmine/themes/bleuclair/stylesheets/application.css
-rw-r--r-- 1 root root 77 Jun 20 08:39 /usr/src/redmine/themes/bleuclair/stylesheets/application.css
```

После первого запуска Redmine открывается по адресу:

```text
http://127.0.0.1:3000
```

В веб-интерфейсе нужно войти под стандартной учетной записью `admin/admin`, затем открыть `Administration -> Settings -> Display` и выбрать тему `Bleuclair` в поле `Theme`.

Остановка стенда:

```bash
docker compose down
```

Остановка с удалением volume:

```bash
docker compose down -v
```
