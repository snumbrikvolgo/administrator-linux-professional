# Задание 19: Разворачиваем сетевую лабораторию

## Цель домашнего задания

Научиться настраивать статическую маршрутизацию, NAT и транзитную маршрутизацию в Linux.

## Текст задания

Нужно развернуть полную сетевую схему из методички и настроить:

- `inetRouter`
- `centralRouter`
- `office1Router`
- `office2Router`
- `centralServer`
- `office1Server`
- `office2Server`

Требования:

- интернет-трафик со всех серверов должен идти через `inetRouter`;
- все сервера должны видеть друг друга;
- у всех новых серверов должен быть отключен default route через NAT-интерфейс `enp0s3`, который Vagrant поднимает для связи;
- настройка выполняется через `Vagrant` и `Ansible`.

## Схема сети

```mermaid
flowchart TB
  inet((Internet))
  nat((Vagrant NAT<br/>10.0.2.0/24))
  ir[inetRouter<br/>mgmt: 192.168.50.10]
  cr[centralRouter<br/>mgmt: 192.168.50.11]
  o1r[office1Router<br/>mgmt: 192.168.50.20]
  o2r[office2Router<br/>mgmt: 192.168.50.30]

  tr0((inet-central<br/>192.168.255.0/30))
  tr1((office1-central<br/>192.168.255.8/30))
  tr2((office2-central<br/>192.168.255.4/30))

  inet --> nat --> ir
  ir -- "eth1<br/>192.168.255.1/30" --> tr0
  tr0 == "192.168.255.2/30<br/>eth1" ==> cr
  cr == "eth5<br/>192.168.255.9/30" ==> tr1
  tr1 == "192.168.255.10/30<br/>eth1" ==> o1r
  cr == "eth6<br/>192.168.255.5/30" ==> tr2
  tr2 == "192.168.255.6/30<br/>eth1" ==> o2r

  subgraph central["Central"]
    direction LR
    dnet((directors<br/>192.168.0.0/28))
    hnet((office hardware<br/>192.168.0.32/28))
    mnet((wifi / mgt<br/>192.168.0.64/26))
    cs[centralServer<br/>192.168.0.2/28<br/>mgmt: 192.168.50.12]
    cr ---|"eth2<br/>192.168.0.1/28"| dnet
    dnet --- cs
    cr ---|"eth3<br/>192.168.0.33/28"| hnet
    cr ---|"eth4<br/>192.168.0.65/26"| mnet
  end

  subgraph office1["Office1"]
    direction LR
    o1dev((dev<br/>192.168.2.0/26))
    o1test((test servers<br/>192.168.2.64/26))
    o1mgr((managers<br/>192.168.2.128/26))
    o1hw((office hardware<br/>192.168.2.192/26))
    o1s[office1Server<br/>192.168.2.130/26<br/>mgmt: 192.168.50.21]
    o1r ---|"eth2<br/>192.168.2.1/26"| o1dev
    o1r ---|"eth3<br/>192.168.2.65/26"| o1test
    o1r ---|"eth4<br/>192.168.2.129/26"| o1mgr
    o1mgr --- o1s
    o1r ---|"eth5<br/>192.168.2.193/26"| o1hw
  end

  subgraph office2["Office2"]
    direction LR
    o2dev((dev<br/>192.168.1.0/25))
    o2test((test servers<br/>192.168.1.128/26))
    o2hw((office hardware<br/>192.168.1.192/26))
    o2s[office2Server<br/>192.168.1.2/25<br/>mgmt: 192.168.50.31]
    o2r ---|"eth2<br/>192.168.1.1/25"| o2dev
    o2dev --- o2s
    o2r ---|"eth3<br/>192.168.1.129/26"| o2test
    o2r ---|"eth4<br/>192.168.1.193/26"| o2hw
  end

  classDef transit fill:#ffe7cc,stroke:#d97706,stroke-width:4px,color:#7c2d12;
  classDef network fill:#ecfeff,stroke:#0891b2,stroke-width:2px,color:#164e63;
  classDef router fill:#f8fafc,stroke:#334155,stroke-width:2px,color:#0f172a;
  classDef server fill:#eef2ff,stroke:#4f46e5,stroke-width:2px,color:#312e81;
  class tr0,tr1,tr2 transit;
  class nat,dnet,hnet,mnet,o1dev,o1test,o1mgr,o1hw,o2dev,o2test,o2hw network;
  class ir,cr,o1r,o2r router;
  class cs,o1s,o2s server;
```

## Теоретическая часть

### Используемые подсети

| Name | Network | Netmask | Hostmin | Hostmax | Hosts | Broadcast |
| --- | --- | --- | --- | --- | --- | --- |
| Directors | `192.168.0.0/28` | `255.255.255.240` | `192.168.0.1` | `192.168.0.14` | 14 | `192.168.0.15` |
| Office hardware | `192.168.0.32/28` | `255.255.255.240` | `192.168.0.33` | `192.168.0.46` | 14 | `192.168.0.47` |
| Wifi (mgt) | `192.168.0.64/26` | `255.255.255.192` | `192.168.0.65` | `192.168.0.126` | 62 | `192.168.0.127` |
| Office1 dev | `192.168.2.0/26` | `255.255.255.192` | `192.168.2.1` | `192.168.2.62` | 62 | `192.168.2.63` |
| Office1 test | `192.168.2.64/26` | `255.255.255.192` | `192.168.2.65` | `192.168.2.126` | 62 | `192.168.2.127` |
| Office1 managers | `192.168.2.128/26` | `255.255.255.192` | `192.168.2.129` | `192.168.2.190` | 62 | `192.168.2.191` |
| Office1 hardware | `192.168.2.192/26` | `255.255.255.192` | `192.168.2.193` | `192.168.2.254` | 62 | `192.168.2.255` |
| Office2 dev | `192.168.1.0/25` | `255.255.255.128` | `192.168.1.1` | `192.168.1.126` | 126 | `192.168.1.127` |
| Office2 test | `192.168.1.128/26` | `255.255.255.192` | `192.168.1.129` | `192.168.1.190` | 62 | `192.168.1.191` |
| Office2 hardware | `192.168.1.192/26` | `255.255.255.192` | `192.168.1.193` | `192.168.1.254` | 62 | `192.168.1.255` |
| Inet-central | `192.168.255.0/30` | `255.255.255.252` | `192.168.255.1` | `192.168.255.2` | 2 | `192.168.255.3` |
| Office2-central | `192.168.255.4/30` | `255.255.255.252` | `192.168.255.5` | `192.168.255.6` | 2 | `192.168.255.7` |
| Office1-central | `192.168.255.8/30` | `255.255.255.252` | `192.168.255.9` | `192.168.255.10` | 2 | `192.168.255.11` |

### Свободные подсети

| Network | Netmask | Hostmin | Hostmax | Broadcast |
| --- | --- | --- | --- | --- |
| `192.168.0.16/28` | `255.255.255.240` | `192.168.0.17` | `192.168.0.30` | `192.168.0.31` |
| `192.168.0.48/28` | `255.255.255.240` | `192.168.0.49` | `192.168.0.62` | `192.168.0.63` |
| `192.168.0.128/25` | `255.255.255.128` | `192.168.0.129` | `192.168.0.254` | `192.168.0.255` |
| `192.168.255.12/30` | `255.255.255.252` | `192.168.255.13` | `192.168.255.14` | `192.168.255.15` |
| `192.168.255.16/28` | `255.255.255.240` | `192.168.255.17` | `192.168.255.30` | `192.168.255.31` |
| `192.168.255.32/27` | `255.255.255.224` | `192.168.255.33` | `192.168.255.62` | `192.168.255.63` |
| `192.168.255.64/26` | `255.255.255.192` | `192.168.255.65` | `192.168.255.126` | `192.168.255.127` |

Ошибок в разбиении сетей нет.

## Что настраивается

- все 7 виртуальных машин поднимаются на `generic/ubuntu2004`;
- `Ansible` подключается по отдельной management-сети `192.168.50.0/24`;
- `Vagrant SSH forwarded ports` (`2230-2236`) остаются как аварийный доступ для ручного восстановления;
- сетевые настройки и маршруты задаются через `netplan` файлами `00-installer-config.yaml` и `50-vagrant_<host>.yaml`;
- на всех хостах, кроме `inetRouter`, отключается получение default route через `enp0s3`;
- на роутерах включается IP forwarding;
- на `inetRouter` настраивается NAT через `iptables`;
- на `centralRouter` добавляются маршруты в сети `office1` и `office2`;
- на `office1Router` и `office2Router` трафик в центральные и внешние сети идет через `centralRouter`;
- на серверах прописывается default route в сторону своего роутера.

## Запуск

### 1. Поднять стенд

```bash
vagrant up
```

### 2. Запустить настройку из WSL

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-19-network-lab
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-19-network-lab/ansible.cfg ansible-playbook ansible/playbook.yml
```

### 3. Запустить проверки

```bash
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-19-network-lab/ansible.cfg ansible-playbook ansible/test.yml
```