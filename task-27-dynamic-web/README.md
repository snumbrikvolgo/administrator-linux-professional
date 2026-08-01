# Задание 27: Динамический веб. Развертывание веб-приложения

## Цель домашнего задания

Получить практические навыки в описании инфраструктуры как кода и развернуть несколько веб-приложений.

### Схема стенда

Порты приложений проброшены на localhost хостовой системы:

| Порт | Приложение |
| --- | --- |
| `8081` | Django через nginx |
| `8082` | Node.js через nginx |
| `8083` | WordPress/php-fpm через nginx |

## Что настраивает Ansible

Ansible устанавливает `docker.io`, compose-плагин и Python-библиотеку для Docker, копирует проект в `/opt/dynamic-web` и запускает compose-стек.

В compose-проект входят:

- `database` на образе `mysql:8.0`;
- `wordpress` на образе `wordpress:6.5-fpm-alpine`;
- `app`, который собирает минимальное Django-приложение с `gunicorn`;
- `node`, который запускает HTTP-сервер из `test.js`;
- `nginx`, который маршрутизирует три внешних порта к нужным контейнерам.

## Запуск

Из Windows PowerShell:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-27-dynamic-web
vagrant up
```

Из WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-27-dynamic-web
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

После выполнения playbook сайты доступны с Windows:

```powershell
curl http://127.0.0.1:8081/
curl http://127.0.0.1:8082/
curl http://127.0.0.1:8083/
```

## Проверка

Автоматическая проверка:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-27-dynamic-web
ansible-playbook -i ansible/inventory.ini ansible/test.yml
```

`test.yml` проверяет:

- доступность Django на `8081`;
- доступность Node.js на `8082`;
- доступность WordPress на `8083`;
- наличие запущенных compose-сервисов `nginx`, `wordpress`, `database`, `app`, `node`.