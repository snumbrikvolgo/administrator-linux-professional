# Задание 18: Резервное копирование с BorgBackup

## Цель домашнего задания

Научиться настраивать резервное копирование с помощью `BorgBackup`.

## Описание домашнего задания

Нужно подготовить `Vagrant`-стенд с двумя виртуальными машинами на базе `Debian 12 (bookworm)`:

- `backup_server` -- сервер хранения резервных копий;
- `client` -- сервер, с которого снимается резервная копия каталога `/opt/backup-data`.

## Что настраивается

На `backup_server` Ansible:

- устанавливает `borgbackup` и `openssh-server`;
- создает пользователя `borg`;
- подключает отдельный диск размером `2 GB`;
- создает на нем раздел и файловую систему `ext4`;
- монтирует диск в `/var/backup`;
- подготавливает `/home/borg/.ssh/authorized_keys` для доступа клиента.

На `client` Ansible:

- устанавливает `borgbackup` и `openssh-client`;
- создает отдельную SSH-ключевую пару `/root/.ssh/id_ed25519_borg`;
- добавляет публичный ключ клиента в `/home/borg/.ssh/authorized_keys` на `backup_server`;
- создает каталог `/opt/backup-data` для демонстрационного резервного копирования;
- инициализирует удаленный репозиторий `borg` с шифрованием `repokey`;
- создает `systemd`-юниты `borg-backup.service` и `borg-backup.timer`;
- в штатном режиме включает таймер с запуском каждые `5` минут.

## Логика резервного копирования

Копия снимается с каталога:

```text
/opt/backup-data
```

Имя архива формируется прямо в `systemd service`:

```text
${REPO}::backup-data-{now:%Y-%m-%d_%H:%M:%S}
```

Репозиторий:

```text
borg@192.168.57.20:/var/backup/borg-repo
```

Удаление старых архивов выполняется автоматически через `borg prune` со следующей политикой:

- `--keep-daily 90`
- `--keep-monthly 6`

## Запуск

### 1. Поднять виртуальные машины из Windows PowerShell

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-18-backup
vagrant up
```

### 2. Перейти в каталог задания из WSL

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-18-backup
```

### 3. Запустить настройку Ansible

```bash
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-18-backup/ansible.cfg ansible-playbook ansible/playbook.yml
```

### 4. Запустить экспериментальный тест

```bash
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-18-backup/ansible.cfg ansible-playbook ansible/test.yml
```

## Что делает экспериментальный тест

1. Полностью очищает репозиторий Borg перед стартом эксперимента.
2. Временно переключает `borg-backup.timer` с `5` минут на `30` секунд.
3. Временно подменяет префикс архивов на `backup-data-test`.
4. В течение `2` минут каждые `10` секунд создает новый файл в `/opt/backup-data`.
5. Собирает список созданных архивов и для каждого архива считает количество файлов.
6. Останавливает таймер, очищает каталог `/opt/backup-data` и восстанавливает его из последнего архива.
7. Проверяет, что после восстановления файлов стало меньше или столько же, сколько было перед очисткой.
8. Возвращает исходный интервал таймера `5` минут и удаляет временные override-файлы.
9. Печатает итоговый отчет:
   - сколько файлов было создано;
   - раз в сколько секунд создавались файлы;
   - сколько длился тест;
   - сколько раз сработал таймер;
   - сколько архивов было создано;
   - сколько файлов восстановилось;
   - имена архивов и количество файлов внутри каждого.