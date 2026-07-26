# Задание 20: PXE и UEFI

## Цель

Настроить PXE-сервер для автоматической установки Linux-дистрибутива по сети в режиме UEFI.

## Настройка

На `pxeserver` Ansible настраивает:

- `dnsmasq` для DHCP и TFTP на интерфейсе `eth1`;
- UEFI-загрузку через `bootx64.efi` и `grub/grub.cfg`;
- Apache для выдачи `preseed.cfg`;
- NAT для PXE-клиентов через внешний интерфейс сервера;
- Debian PXE installer `vmlinuz/initrd.gz`;
- Debian netinst ISO как обычный установочный дистрибутивный образ.

Для самой PXE-загрузки используются официальные Debian installer файлы из `stable/main/installer-amd64/current/images/netboot`, установка идет из HTTP-репозитория `deb.debian.org`.

## Запуск

### 1. Поднять PXE-сервер из Windows

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\task-20-pxe
vagrant up pxeserver
```

### 2. Настроить PXE-сервер из WSL

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/task-20-pxe
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-20-pxe/ansible.cfg ansible-playbook ansible/playbook.yml
```

### 3. Проверить сервер из WSL

```bash
ANSIBLE_CONFIG=/mnt/c/Users/zazhigina/administrator-linux-professional/task-20-pxe/ansible.cfg ansible-playbook ansible/test.yml
```

### 4. Создать и запустить PXE-клиент из Windows

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\create-pxeclient.ps1
powershell.exe -ExecutionPolicy Bypass -File .\start-pxeclient.ps1
```

Клиент создается с такими параметрами:

- firmware: EFI;
- boot1: net;
- boot2: disk;
- NIC1: `intnet pxenet`, `virtio-net`;
- NIC2: NAT, `virtio-net`;
- disk: пустой VDI 20 ГБ.

После запуска клиент получает DHCP-адрес, забирает `bootx64.efi`, затем `grub/grub.cfg`, `debian/vmlinuz` и `debian/initrd.gz`. В рабочем варианте Debian installer доходит до этапа `Loading additional components`.

## После установки

После завершения установки можно переключить порядок загрузки клиента на диск:

```powershell
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' modifyvm task-20-pxeclient --boot1 disk --boot2 net
```

Пользователь установленной системы:

- логин: `otus`
- пароль: `123`