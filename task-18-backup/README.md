# Задание 18: Резервное копирование с BorgBackup

## Цель домашнего задания

Научиться настраивать резервное копирование с помощью `BorgBackup`.

## Описание домашнего задания

Нужно подготовить `Vagrant`-стенд с двумя виртуальными машинами на базе `Debian 12 (bookworm)`:

- `backup_server` -- сервер хранения резервных копий;
- `client` -- сервер, с которого снимается резервная копия каталога `/etc`.

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
- инициализирует удаленный репозиторий `borg` с шифрованием `repokey`;
- создает `systemd`-юниты `borg-backup.service` и `borg-backup.timer`;
- включает таймер с запуском каждые `5` минут.

## Логика резервного копирования

Копия каталога `/etc` снимается командой `borg create`.

Имя архива формируется прямо в `systemd service`:

```text
${REPO}::etc-{now:%Y-%m-%d_%H:%M:%S}
```

Репозиторий:

```text
borg@192.168.57.20:/var/backup/borg-repo
```

Удаление старых архивов выполняется автоматически через `borg prune` со следующей политикой:

- `--keep-daily 90`
- `--keep-monthly 6`

Итоговая схема хранения:

- по одному бэкапу в день в течение `90` дней;
- по одному бэкапу в месяц за предыдущие `6` месяцев.

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

### 4. Запустить проверки

```bash
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-18-backup/ansible.cfg ansible-playbook ansible/test.yml
```

## Что проверяет `ansible/test.yml`

1. На `client` проверяется, что `borg-backup.timer` включен и активен.
2. На `client` сервис `borg-backup.service` запускается дважды подряд.
3. Проверяется, что после первого запуска появляется новый архив.
4. Проверяется, что после второго запуска появляется еще один новый архив.
