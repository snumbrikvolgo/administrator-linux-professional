# Задание 23: VPN

## Цель домашнего задания

Создать домашнюю сетевую лабораторию и научиться настраивать VPN-сервер в Linux-based системах.

## Цель задания

- настроить VPN между двумя ВМ в режимах `tap` и `tun`;
- измерить скорость в туннеле с помощью `iperf3`;
- сделать вывод об отличающихся показателях;
- поднять RAS на базе OpenVPN с клиентскими сертификатами;
- подключиться к RAS и проверить доступность внутреннего адреса сервера в туннеле.

## Что настраивает Ansible

- устанавливает `openvpn`, `easy-rsa`, `iperf3`, `iproute2`, `net-tools`, `selinux-utils`;
- отключает `ufw` и включает IPv4 forwarding;
- создает static key для site-to-site OpenVPN;
- настраивает режим `tap` как режим по умолчанию для сервиса `openvpn@site`;
- кладет готовые конфиги `/etc/openvpn/site-tap.conf` и `/etc/openvpn/site-tun.conf`;
- добавляет helper `/usr/local/sbin/openvpn-site-mode tap|tun` для переключения режима;
- создает PKI через Easy-RSA для RAS-сервера;
- выпускает сертификаты `server` и `client`;
- запускает RAS-сервер `openvpn@ras` на UDP-порту `1207`;
- формирует клиентский bundle в `/home/vagrant/ras-client`.

## Запуск

В Windows:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-23-vpn
vagrant up
```

В WSL:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-23-vpn
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-23-vpn/ansible.cfg ansible-playbook ansible/playbook.yml
```

## Проверка

Автоматическая проверка:

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-23-vpn
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-23-vpn/ansible.cfg ansible-playbook ansible/test.yml
```

Что делает `ansible/test.yml`:

1. Переключает site-to-site VPN в `tap`.
2. Проверяет ping между `10.10.10.1` и `10.10.10.2`.
3. Запускает `iperf3` на `server` и замеряет скорость с `client`.
4. Переключает site-to-site VPN в `tun`.
5. Повторяет ping и замер `iperf3`.
6. Возвращает режим по умолчанию `tap`.
7. Запускает RAS-клиент из `/home/vagrant/ras-client/client.conf` и проверяет ping `10.20.20.1`.

Ручные команды для site-to-site:

```bash
vagrant ssh server
sudo /usr/local/sbin/openvpn-site-mode tap
sudo systemctl status openvpn@site
ping -c 4 10.10.10.2
iperf3 -s
```

Во втором окне:

```bash
vagrant ssh client
iperf3 -c 10.10.10.1 -t 40 -i 5
sudo /usr/local/sbin/openvpn-site-mode tun
iperf3 -c 10.10.10.1 -t 40 -i 5
```

Ручная проверка RAS на сервере:

```bash
vagrant ssh server
sudo openvpn --config /home/vagrant/ras-client/client.conf
ping -c 4 10.20.20.1
ip route
```

Если нужно подключаться к RAS с хостовой машины, нужно перенести из `server:/home/vagrant/ras-client` файлы `client.conf`, `ca.crt`, `client.crt`, `client.key` в одну директорию на хосте и запустить OpenVPN-клиент с правами администратора. В конфиге указан сервер `192.168.80.10:1207`.

## Вывод по режимам TUN/TAP

`tap` работает на L2 и переносит Ethernet-кадры. Он удобен, когда нужно объединить сегменты как одну широковещательную сеть, но несет больше служебного трафика и обычно показывает меньшую полезную пропускную способность.

`tun` работает на L3 и переносит IP-пакеты. Для маршрутизируемого VPN это более простой и экономный режим: меньше broadcast-трафика, меньше накладных расходов, как правило лучше результаты `iperf3`.

Для этой лабораторной режим `tap` оставлен дефолтным, потому что первый пункт методички начинается с `tap`; для практической routed-схемы обычно предпочтительнее `tun`.

Фактический замер в текущем стенде:

```text
TAP: sender 3.60 Mbits/sec, receiver 3.29 Mbits/sec
TUN: sender 4.22 Mbits/sec, receiver 3.93 Mbits/sec
```

В этом прогоне `tun` оказался быстрее, что соответствует ожидаемой картине для routed VPN: у него меньше накладных расходов, чем у L2-туннеля `tap`.
