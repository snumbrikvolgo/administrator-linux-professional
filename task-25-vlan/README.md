# Задание 25: VLAN и LACP

## Цель домашнего задания

Научиться настраивать VLAN и агрегирование сетевых интерфейсов в Linux.

## Что настраивает Ansible

- устанавливает `vim`, `traceroute`, `tcpdump`, `net-tools`;
- на `testClient1` и `testServer1` создает VLAN-интерфейсы `eth1.1`;
- на `testClient2` и `testServer2` создает VLAN-интерфейсы `vlan2` через netplan;
- на `inetRouter` и `centralRouter` создает `bond0` поверх `eth1` и `eth2`;
- задает для bond режим `active-backup`: `mode=1 miimon=100 fail_over_mac=1`;
- перезагружает маршрутизаторы после настройки bond, так как NetworkManager на CentOS не всегда поднимает bond корректно простым restart.

## Запуск

В Windows:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-25-vlan
vagrant up
```

В WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-25-vlan
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-25-vlan/ansible.cfg ansible-playbook ansible/playbook.yml
```

## Проверка

Автоматическая проверка:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-25-vlan
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-25-vlan/ansible.cfg ansible-playbook ansible/test.yml
```

Проверка VLAN вручную:

```bash
vagrant ssh testClient1
ping -c 4 10.10.10.1

vagrant ssh testClient2
ping -c 4 10.10.10.1
```

Проверка bond вручную:

```bash
vagrant ssh inetRouter
ping 192.168.255.2
```

Во втором окне:

```bash
vagrant ssh centralRouter
sudo ip link set eth1 down
cat /proc/net/bonding/bond0
sudo ip link set eth1 up
```

Ping между `192.168.255.1` и `192.168.255.2` должен продолжить работу после отключения `eth1`, потому что трафик переключается на второй slave-интерфейс.