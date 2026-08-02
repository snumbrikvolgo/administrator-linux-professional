# Задание 11: Практика с SELinux

## Цель домашнего задания

Диагностировать проблемы SELinux и модифицировать политики так, чтобы приложения работали в режиме `Enforcing`.

## Текст задания

1. Запустить nginx на нестандартном порту `4881` тремя разными способами:
- через переключатель `setsebool`;
- через добавление нестандартного порта в существующий тип;
- через формирование и установку SELinux-модуля.

2. Обеспечить работоспособность DNS-приложения при включенном SELinux:
- развернуть стенд по мотивам `vagrant_selinux_dns_problems`;
- найти причину ошибки динамического обновления зоны;
- предложить варианты решения;
- выбрать и реализовать один вариант;
- продемонстрировать работоспособность.

## Запуск

Из Windows PowerShell:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-11-selinux
vagrant up
```

Из WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-11-selinux
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
ansible-playbook -i ansible/inventory.ini ansible/test.yml
```

## Проверка

Автоматический тест `ansible/test.yml` проверяет:
- SELinux находится в `Enforcing` на всех nginx- и DNS-VM;
- на `nginx-bool` включен `nis_enabled`;
- на `nginx-port` порт `4881/tcp` добавлен в `http_port_t`;
- на `nginx-module` установлен модуль `nginx_4881`;
- каждый nginx отвечает на `http://127.0.0.1:4881/` внутри своей VM;
- каталог `/etc/named` размечен как `named_zone_t`;
- `named` запущен;
- клиент успешно добавляет запись `www.ddns.lab` через `nsupdate`;
- `dig @10.11.0.20 www.ddns.lab A` возвращает `10.11.0.21`.

Ручная проверка nginx с Windows host:

```powershell
curl http://127.0.0.1:4881/
curl http://127.0.0.1:4882/
curl http://127.0.0.1:4883/
```

Ручная проверка DNS с клиента:

```bash
sudo nsupdate -k /etc/named.zonetransfer.key
server 10.11.0.20
zone ddns.lab
update add www.ddns.lab. 60 A 10.11.0.21
send
quit

dig @10.11.0.20 www.ddns.lab A
```
