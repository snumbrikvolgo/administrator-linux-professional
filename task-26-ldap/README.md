# Задание 26: LDAP. Централизованная авторизация и аутентификация

## Цель домашнего задания

Научиться настраивать LDAP-сервер и подключать к нему LDAP-клиентов на примере FreeIPA.

## Что настраивает Ansible

- задает часовой пояс `Europe/Moscow`;
- прописывает все узлы стенда в `/etc/hosts`;
- устанавливает и включает `chrony` и `firewalld`;
- оставляет SELinux в режиме `enforcing`;
- на сервере устанавливает FreeIPA с доменом `otus.lan` и realm `OTUS.LAN`;
- включает DNS внутри FreeIPA, чтобы клиенты могли корректно работать с доменом без отдельного DNS-сервера;
- открывает в firewall сервисы FreeIPA, DNS, HTTP/HTTPS, Kerberos, kpasswd и NTP;
- создает тестового пользователя `otus-user`;
- добавляет пользователю SSH public key из `ansible/files/otus-user.pub`;
- на клиентах устанавливает `freeipa-client`, подключает их к домену и включает `oddjobd` для создания домашних каталогов;
- на клиентах включает получение SSH-ключей через SSSD (`sss_ssh_authorizedkeys`).

Пароли для лабораторного стенда вынесены в `ansible/inventory.ini`:

- `ipa_admin_password=otus2026`;
- `ipa_dm_password=otus2026`;
- `ldap_test_password=Otus2026!`.

## Запуск

В Windows:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-26-ldap
vagrant up
```

В WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-26-ldap
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-26-ldap/ansible.cfg ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

## Проверка

Автоматическая проверка:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-26-ldap
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-26-ldap/ansible.cfg ansible-playbook -i ansible/inventory.ini ansible/test.yml
```

Проверяется:

- статус FreeIPA через `ipactl status`;
- получение Kerberos-билета для `admin`;
- наличие пользователя `otus-user` в IPA;
- разрешение LDAP-пользователя на клиентах через `getent passwd`;
- выдача SSH-ключа через `sss_ssh_authorizedkeys`;
- включенный firewall на сервере и клиентах;
- создание домашнего каталога LDAP-пользователя через `oddjob-mkhomedir`.

Ручная проверка:

```powershell
vagrant ssh client1
getent passwd otus-user
echo 'Otus2026!' | kinit otus-user
sss_ssh_authorizedkeys otus-user
su - otus-user
```

Ожидается, что пользователь находится через SSSD, его SSH-ключ доступен через SSSD, а при первом входе создается `/home/otus-user`.