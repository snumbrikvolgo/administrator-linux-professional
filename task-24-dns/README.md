# Задание 24: DNS. Настраиваем split-DNS

## Цель домашнего задания

Создать домашнюю сетевую лабораторию, изучить основы DNS и настроить Split-DNS в Linux-based системах.

## Что настраивает Ansible

- устанавливает `bind`, `bind-utils`, `chrony`;
- переводит CentOS 7 yum-репозитории на `vault.centos.org`, так как обычные mirrorlist для CentOS 7 больше неактуальны;
- настраивает `/etc/resolv.conf`;
- поднимает master DNS `ns01` и slave DNS `ns02`;
- создает зоны `dns.lab`, `newdns.lab`, `ddns.lab` и reverse-зону `90.168.192.in-addr.arpa`;
- настраивает TSIG-ключи для zone transfer и view-запросов;
- включает Split-DNS через BIND `view`;
- проверяет конфигурацию командой `named-checkconf`;
- проверяет master-зоны командой `named-checkzone`;
- восстанавливает стандартные SELinux-контексты через `restorecon`.

## Запуск

В Windows:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-24-dns
vagrant up
```

В WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-24-dns
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-24-dns/ansible.cfg ansible-playbook ansible/playbook.yml
```

## Проверка

Автоматическая проверка:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-24-dns
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-24-dns/ansible.cfg ansible-playbook ansible/test.yml
```

Ожидаемый результат для `client`:

```bash
dig +short web1.dns.lab
# 192.168.90.15

dig +short web2.dns.lab
# пустой ответ

dig +short www.newdns.lab
# 192.168.90.15
# 192.168.90.16
```

Ожидаемый результат для `client2`:

```bash
dig +short web1.dns.lab
# 192.168.90.15

dig +short web2.dns.lab
# 192.168.90.16

dig +short www.newdns.lab
# пустой ответ
```

Дополнительно можно проверить, что slave-сервер отдает такую же split-DNS картину:

```bash
dig @192.168.90.11 +short web1.dns.lab
dig @192.168.90.11 +short web2.dns.lab
dig @192.168.90.11 +short www.newdns.lab
```