# Задание 21: iptables

Цель задания:

- реализовать port knocking;
- `centralRouter` должен попадать на SSH `inetRouter` только после knock-скрипта;
- добавить `inetRouter2`, который виден с хоста через host-only сеть;
- запустить `nginx` на `centralServer`;
- пробросить порт `8080` на `inetRouter2` на порт `80` `centralServer`;
- default route в интернет оставить через `inetRouter`.

## Схема сети

```text
Host
  |
  | http://192.168.56.10:8080
  |
inetRouter2
  | 192.168.255.6/30
  |
  | 192.168.255.5/30
centralRouter
  | 192.168.0.1/28
  |
centralServer
  nginx: 192.168.0.2:80

centralRouter
  | 192.168.255.2/30
  |
inetRouter
  192.168.255.1/30
  default internet gateway
```

## Запуск

В Windows:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-21-iptables
vagrant up
```

В WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-21-iptables
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-21-iptables/ansible.cfg ansible-playbook ansible/playbook.yml
```

## Проверка

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-21-iptables
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-21-iptables/ansible.cfg ansible-playbook ansible/test.yml
```

Проверка HTTP с хоста:

```powershell
curl http://192.168.56.10:8080/
```

Ожидаемый ответ:

```text
task-21 iptables: centralServer nginx
```
