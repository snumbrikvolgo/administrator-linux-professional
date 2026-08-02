# Задание 29: PostgreSQL. Репликация и резервное копирование

## Цель домашнего задания

Научиться настраивать hot standby репликацию PostgreSQL с использованием физических replication slots и организовать корректное резервное копирование через Barman.

## Что настраивает Ansible

`ansible/playbook.yml` выполняет всю настройку после создания VM:

- устанавливает PostgreSQL 14, `postgresql-contrib`, `barman-cli` и Python/ACL-пакеты;
- рендерит `/etc/postgresql/14/main/postgresql.conf` с `wal_level = replica`, `hot_standby = on`, `max_wal_senders` и `max_replication_slots`;
- рендерит `/etc/postgresql/14/main/pg_hba.conf` с доступом для пользователей `replication` и `barman`;
- на `node1` создает пользователей `replication` и `barman`, базу `otus`, таблицу `otus.test`;
- создает physical slot `node2`;
- на `node2` очищает старый data directory и выполняет `pg_basebackup -R -S node2`;
- на `barman` настраивает `/etc/barman.conf`, `/etc/barman.d/node1.conf`, `.pgpass`, WAL receiver и первичный backup.

## Запуск

Из Windows PowerShell:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-29-postgresql-replication
vagrant up
vagrant validate
```

Из WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-29-postgresql-replication
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```
## Проверка

Автоматическая проверка:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-29-postgresql-replication
ansible-playbook -i ansible/inventory.ini ansible/test.yml
```

`ansible/test.yml` проверяет практический результат:

- создает на primary базу `otus_test` и строку в таблице `replication_check`;
- ждет появления строки на standby;
- проверяет, что `node2` находится в recovery-режиме;
- проверяет `pg_stat_replication` и physical slot `node2`;
- запускает `barman check node1` и проверяет наличие backup в `barman list-backup node1`.

Ручные команды для просмотра состояния:

```bash
sudo -u postgres psql -c "select * from pg_stat_replication;"
sudo -u postgres psql -c "select slot_name, slot_type, active from pg_replication_slots;"
sudo -u postgres psql -d otus_test -c "select * from replication_check;"
```

На standby:

```bash
sudo -u postgres psql -c "select pg_is_in_recovery();"
sudo -u postgres psql -d otus_test -c "select * from replication_check;"
```

На Barman:

```bash
sudo -u barman barman check node1
sudo -u barman barman list-backup node1
```