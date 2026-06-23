# Задание 17: Централизованный сбор логов

## Цель домашнего задания

Настроить централизованный сбор логов с `nginx`, `auditd`, `rsyslog` и выполнить задание со звездочкой с отдельным `ELK`.

## Схема стенда

Используются четыре виртуальные машины на базе `AlmaLinux 9`:

- `web` — источник логов `nginx`, `audit` и системных логов;
- `client` — источник обычных системных логов через `rsyslog`;
- `log` — центральный сервер приема и хранения удаленных логов;
- `elk` — отдельная система для приема только `nginx`-логов.

Разделение потоков логов

- `web -> elk`: только `nginx access` и `nginx error`
- `web -> log`: audit и обычные системные логи
- `client -> log`: обычные системные логи

## Что настраивается

На `web` Ansible:

- устанавливает `nginx`, `audit`, `rsyslog`;
- включает `nginx`;
- настраивает `nginx` на отправку `access` и `error` логов в `ELK` по syslog;
- оставляет локально только критичные `nginx error` логи;
- настраивает `rsyslog` на отправку audit и системных логов на `log`;
- добавляет audit rule на каталог `/etc/nginx/`.

На `client` Ansible:

- устанавливает `rsyslog`;
- настраивает пересылку всех логов на `log`.

На `log` Ansible:

- устанавливает `rsyslog`;
- включает прием логов по `TCP/UDP 514`;
- сохраняет их в каталог `/var/log/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log`.

На `elk` Ansible:

- устанавливает `Elasticsearch`, `Kibana`, `Logstash`;
- настраивает `Logstash` на прием syslog-сообщений от `nginx` по `TCP/UDP 5140`;
- сохраняет их в индексы `nginx-logs-*`.

## Запуск

### 1. Поднять виртуальные машины из Windows PowerShell

```powershell
vagrant up
```

### 2. Перейти в каталог задания из WSL

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-17-logs
```

### 3. Запустить настройку Ansible

```bash
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-17-logs/ansible.cfg ansible-playbook ansible/playbook.yml
```

### 4. Запустить проверки

```bash
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-17-logs/ansible.cfg ansible-playbook ansible/test.yml
```

## Что проверяет `ansible/test.yml`

1. На `web` генерируется HTTP-запрос в `nginx`.
2. На `web` создается изменение в `/etc/nginx/conf.d/` для audit-события.
3. На `client` создается системное сообщение через `logger`.
4. На `log` проверяется получение:
   - audit-лога от `web`;
   - тестового системного лога от `client`.
5. На `elk` проверяется появление хотя бы одного документа в `nginx-logs-*`.
