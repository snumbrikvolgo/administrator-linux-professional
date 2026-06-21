# Задание 16: PAM

## Цель домашнего задания

Научиться создавать пользователей и добавлять им ограничения через PAM.

## Описание домашнего задания

Необходимо подготовить Vagrant-стенд с Ansible, который ограничивает доступ к системе для всех пользователей, кроме группы администраторов, в выходные дни, за исключением праздничных дней.

Задание со звездочкой: предоставить отдельному пользователю доступ к Docker и право перезапускать Docker-сервис.

## Стенд

Для создания виртуальной машины используется `Vagrantfile`.

В стенде создается одна виртуальная машина:

- имя хоста: `pam`;
- box: `bento-ubuntu-24.04-local`;
- локальный box: `file:///C:/Users/zazhigina/Downloads/ubuntu-24.04`;
- оперативная память: `1024 MB`;
- CPU: `2`;
- приватная сеть: `192.168.57.10`.

Provisioning выполняется через Ansible playbook `ansible/playbook.yml`. В этот же playbook импортирован `ansible/test_access.yml`, поэтому при обычном запуске основного playbook сначала выполняется настройка стенда, затем выполняются тесты. Тестовый play дополнительно помечен тегом `test`, поэтому проверки можно запустить отдельно через `--tags test`.

## Основная логика работы

Ansible выполняет следующие действия:

- устанавливает Docker;
- создает группу `admin`;
- создает пользователей `otus`, `otusadm` и `dockeradm`;
- добавляет пользователей `vagrant` и `otusadm` в группу `admin`;
- включает SSH-аутентификацию по паролю;
- добавляет список праздничных дат в `/etc/security/pam_holidays.conf`;
- устанавливает PAM-скрипт `/usr/local/bin/login.sh`;
- подключает скрипт в `/etc/pam.d/sshd` через `pam_exec`;
- добавляет пользователя `dockeradm` в группу `docker`;
- выдает пользователю `dockeradm` точечное sudo-право на перезапуск Docker.

В результате создаются три новых пользователя:

- `otus` -- обычный пользователь для проверки запрета входа в обычные выходные дни;
- `otusadm` -- пользователь из группы `admin` для проверки разрешенного входа в выходные дни;
- `dockeradm` -- пользователь для задания со звездочкой: доступ к Docker и право перезапуска Docker-сервиса.

Пользователь `vagrant` не создается playbook. Он добавляется в группу `admin`, чтобы управление стендом через `vagrant ssh` не блокировалось в обычные выходные дни.

Пароль для созданных пользователей `otus`, `otusadm` и `dockeradm`:

```text
Otus2022!
```

## Реализация ограничения доступа

В `/etc/pam.d/sshd` добавляется строка:

```text
account required pam_exec.so quiet /usr/local/bin/login.sh
```

Скрипт `/usr/local/bin/login.sh` проверяет пользователя из переменной `PAM_USER`.

Логика работы:

- если сегодня будний день, вход разрешен всем пользователям;
- если сегодня суббота или воскресенье и дата есть в `/etc/security/pam_holidays.conf`, вход разрешен всем пользователям;
- если сегодня обычная суббота или обычное воскресенье, вход разрешен только пользователям из группы `admin`;
- в остальных случаях вход запрещен.

Праздники хранятся в формате `MM-DD`, например:

```text
01-01
01-07
05-09
06-12
11-04
```

## Инструкция по запуску стенда

Из папки задания:

```bash
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export VAGRANT_DEFAULT_PROVIDER="virtualbox"
export PATH="/mnt/c/Program Files/Oracle/VirtualBox:$PATH"
export VAGRANT_WSL_HOST_IP=$(awk '/nameserver/{print $2; exit}' /etc/resolv.conf)
vagrant up
```

Подключиться к виртуальной машине:

```bash
vagrant ssh pam
```

## Проверка пользователей и групп

Проверка группы `admin`:

```bash
$ getent group admin
admin:x:1001:otusadm,vagrant
```

Проверка пользователей:

```bash
$ id otus
uid=1001(otus) gid=1002(otus) groups=1002(otus)

$ id otusadm
uid=1002(otusadm) gid=1003(otusadm) groups=1003(otusadm),1001(admin)

$ id dockeradm
uid=1003(dockeradm) gid=1004(dockeradm) groups=1004(dockeradm),999(docker)
```

Числовые `uid`, `gid` и `gid` группы `docker` могут отличаться в зависимости от образа и порядка создания пользователей. Важны сами группы: `otusadm` должен входить в `admin`, `dockeradm` должен входить в `docker`, а `otus` не должен входить в `admin`.

## Проверка PAM-скрипта

Проверки доступа оформлены отдельным Ansible playbook `ansible/test_access.yml`, который импортирован в основной `ansible/playbook.yml`.

Запуск только тестов после `vagrant up`:

```bash
ansible-playbook -i .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory ansible/playbook.yml --tags test
```

Playbook проверяет следующие сценарии:

| День | Пользователь | Ожидаемый результат |
| --- | --- | --- |
| Пятница | `otus` | вход разрешен |
| Обычная суббота | `otus` | вход запрещен |
| Обычное воскресенье | `otus` | вход запрещен |
| Обычная суббота | `otusadm` | вход разрешен |
| Праздничная суббота | `otus` | вход разрешен |

Для ручной проверки без изменения системной даты в скрипте предусмотрена переменная `PAM_CHECK_DATE`.

Суббота, обычный пользователь `otus`:

```bash
$ sudo PAM_USER=otus PAM_CHECK_DATE=2026-06-20 /usr/local/bin/login.sh; echo $?
1
```

Суббота, пользователь из группы `admin`:

```bash
$ sudo PAM_USER=otusadm PAM_CHECK_DATE=2026-06-20 /usr/local/bin/login.sh; echo $?
0
```

Будний день, обычный пользователь:

```bash
$ sudo PAM_USER=otus PAM_CHECK_DATE=2026-06-22 /usr/local/bin/login.sh; echo $?
0
```

Праздничный день, даже если он выпал на выходной:

```bash
$ sudo PAM_USER=otus PAM_CHECK_DATE=2027-05-09 /usr/local/bin/login.sh; echo $?
0
```

Проверка реального SSH-доступа с хостовой машины:

```bash
ssh otus@192.168.57.10
ssh otusadm@192.168.57.10
```

## Задание со звездочкой: доступ к Docker

Пользователь `dockeradm` добавляется в группу `docker`, поэтому может выполнять Docker-команды без `sudo` после нового входа в систему.

Проверка:

```bash
$ id dockeradm
uid=1003(dockeradm) gid=1004(dockeradm) groups=1004(dockeradm),999(docker)

$ sudo -iu dockeradm docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

Право на перезапуск Docker выдается через `/etc/sudoers.d/dockeradm-docker-restart`:

```text
dockeradm ALL=(root) NOPASSWD: /bin/systemctl restart docker.service, /usr/bin/systemctl restart docker.service, /bin/systemctl restart docker, /usr/bin/systemctl restart docker
```

Проверка:

```bash
$ sudo -iu dockeradm
$ sudo systemctl restart docker.service
```

Команда выполняется без запроса пароля. В тестовом playbook это проверяется через `become_user: dockeradm` и команду `sudo systemctl restart docker.service`.
