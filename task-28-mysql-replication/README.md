# Задание 28: MySQL

## Цель домашнего задания

Настроить MySQL-репликацию с использованием GTID и проверить, что изменения с master-сервера попадают на slave-сервер.

## Что настраивает Ansible

Playbook устанавливает `mysql-server`, включает GTID и бинарные логи, задает разные `server-id`, открывает MySQL на host-only интерфейсе и включает на slave:

```ini
replicate-ignore-table = bet.events_on_demand
replicate-ignore-table = bet.v_same_event
```

На master создается база `bet`, пользователь `repl`, затем формируется `/tmp/master.sql` без игнорируемых таблиц. Dump переносится через Ansible-controller на slave, импортируется, после чего slave подключается к master с `SOURCE_AUTO_POSITION = 1`.

## Запуск

Из Windows PowerShell:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-28-mysql-replication
vagrant up
```

Из WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-28-mysql-replication
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

## Проверка

Автоматическая проверка:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-28-mysql-replication
ansible-playbook -i ansible/inventory.ini ansible/test.yml
```

`test.yml` выполняет практическую проверку из методички:

- добавляет на master строку `1, '1xbet'` в `bet.bookmaker`;
- ждет появления строки на slave;
- проверяет `SHOW REPLICA STATUS`;
- проверяет, что на slave отсутствуют таблицы `events_on_demand` и `v_same_event`.

Ручные команды для просмотра состояния:

```bash
sudo mysql -e "SHOW VARIABLES LIKE 'gtid_mode';"
sudo mysql -e "SHOW REPLICA STATUS\G"
sudo mysql -D bet -e "SHOW TABLES;"
sudo mysql -D bet -e "SELECT * FROM bookmaker;"
```