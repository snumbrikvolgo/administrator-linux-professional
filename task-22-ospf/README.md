# Задание 22: OSPF

## Цель домашнего задания

Создать домашнюю сетевую лабораторию и научиться настраивать протокол OSPF в Linux-based системах.

## Что нужно сделать

Нужно развернуть стенд `Vagrant + Ansible` из 3 виртуальных машин:

- `router1`;
- `router2`;
- `router3`.

Требования из методички:

- объединить роутеры разными VLAN/private networks;
- настроить OSPF между машинами на базе FRR, преемника Quagga;
- показать асимметричный роутинг;
- сделать один из линков дорогим так, чтобы итоговая маршрутизация была симметричной.

## Схема сети

```mermaid
flowchart TB
  r1[router1<br/>mgmt: 192.168.70.10<br/>router-id: 1.1.1.1]
  r2[router2<br/>mgmt: 192.168.70.11<br/>router-id: 2.2.2.2]
  r3[router3<br/>mgmt: 192.168.70.12<br/>router-id: 3.3.3.3]

  r1r2((r1-r2<br/>10.0.10.0/30))
  r2r3((r2-r3<br/>10.0.11.0/30))
  r1r3((r1-r3<br/>10.0.12.0/30))

  net1((net1<br/>192.168.10.0/24))
  net2((net2<br/>192.168.20.0/24))
  net3((net3<br/>192.168.30.0/24))

  r1 -->|eth1<br/>10.0.10.1/30| r1r2
  r1r2 -->|10.0.10.2/30<br/>eth1| r2
  r2 -->|eth2<br/>10.0.11.2/30| r2r3
  r2r3 -->|10.0.11.1/30<br/>eth1| r3
  r1 -->|eth2<br/>10.0.12.1/30| r1r3
  r1r3 -->|10.0.12.2/30<br/>eth2| r3

  r1 ---|eth3<br/>192.168.10.1/24| net1
  r2 ---|eth3<br/>192.168.20.1/24| net2
  r3 ---|eth3<br/>192.168.30.1/24| net3

  classDef transit fill:#ecfeff,stroke:#0891b2,stroke-width:2px,color:#164e63;
  classDef router fill:#f8fafc,stroke:#334155,stroke-width:2px,color:#0f172a;
  classDef lan fill:#eef2ff,stroke:#4f46e5,stroke-width:2px,color:#312e81;
  class r1r2,r2r3,r1r3 transit;
  class r1,r2,r3 router;
  class net1,net2,net3 lan;
```

## Что настраивает Ansible

- устанавливает базовые пакеты `curl`, `gnupg`, `iproute2`, `netplan.io`, `traceroute`;
- добавляет репозиторий FRR из методички и устанавливает `frr`, `frr-pythontools`;
- включает IPv4 forwarding и отключает `rp_filter`;
- включает демоны `zebra` и `ospfd` в `/etc/frr/daemons`;
- создает `/etc/frr/frr.conf` для каждого роутера;
- на обоих концах линка `router1-router2` задает OSPF cost `1000`, поэтому трафик между `router1` и `router2` идет симметрично через `router3`.

## Запуск

В Windows:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-22-ospf
vagrant up
```

В WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-22-ospf
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-22-ospf/ansible.cfg ansible-playbook ansible/playbook.yml
```

## Проверка

Запустить автоматические проверки:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-22-ospf
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-22-ospf/ansible.cfg ansible-playbook ansible/test.yml
```

Что делает `ansible/test.yml`:

1. Проверяет, что сервис `frr` запущен на всех трех роутерах.
2. Проверяет, что FRR видит OSPF-маршруты командой `vtysh -c "show ip route ospf"`.
3. Проверяет доступность локальных сетей `192.168.10.0/24`, `192.168.20.0/24`, `192.168.30.0/24` через `ping`.
4. Проверяет постоянное состояние: дорогой линк `router1-router2` настроен симметрично, поэтому `router1 -> router2` и `router2 -> router1` идут через `router3`.
5. Временно делает cost на `router2 eth1` равным `100`.
6. Проверяет асимметрию: `router1 -> router2` идет через `router3`, а `router2 -> router1` выбирает прямой next-hop `10.0.10.1` через `eth1`.
7. Возвращает cost на `router2 eth1` обратно в `1000`.

Ручные проверки из методички:

```bash
vagrant ssh router1
sudo -i
ping -c 2 192.168.30.1
traceroute -n 192.168.20.1
vtysh -c "show ip route ospf"
```

Ожидаемо `traceroute -n 192.168.20.1` с `router1` идет через `10.0.12.2`, потому что прямой линк `router1-router2` сделан дорогим с обеих сторон.

Для демонстрации асимметричного роутинга по методичке можно временно сделать дорогим только интерфейс `router1 -> router2`:

```bash
vagrant ssh router2
sudo vtysh
conf t
interface eth1
ip ospf cost 100
end
write memory
show ip route ospf
```

После этого путь `router1 -> router2` останется через `router3`, а обратный путь `router2 -> router1` сможет идти напрямую через `10.0.10.1`.
