# Задание 8: Работа с загрузчиком

## Цель домашнего задания

Научиться управлять параметрами загрузчика GRUB, попадать в систему без пароля разными способами, а также работать с LVM на этапе загрузки системы: проверить текущую Volume Group и переименовать ее.

## Описание домашнего задания

1. Включить отображение меню GRUB.
2. Попасть в систему без пароля несколькими способами.
3. Установить систему с LVM или использовать готовую VM с LVM.
4. Переименовать Volume Group.
5. Описать разницу между способами получения shell в процессе загрузки.

## Используемое окружение

Работа выполнялась в виртуальной машине, запущенной через Vagrant и VirtualBox.

Запуск виртуальной машины:

```bash
vagrant up
vagrant ssh
```

## 1. Включение отображения меню GRUB

По умолчанию меню GRUB может быть скрыто, а таймаут выбора пункта загрузки может быть равен нулю. Для выполнения задания меню нужно сделать видимым.

Открываем конфигурационный файл GRUB:

```bash
nano /etc/default/grub
```

Находим параметры:

```bash
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
```

Изменяем их следующим образом:

```bash
#GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=10
```

Применяем настройки:

```bash
update-grub
```

```text
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.0-86-generic
Found initrd image: /boot/initrd.img-6.8.0-86-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
```

Перезагружаем VM:

```bash
reboot
```

При следующей загрузке в окне VirtualBox должно появиться меню GRUB с задержкой 10 секунд.

## 2. Попадание в систему без пароля. Способ 1: `init=/bin/bash`

Этот способ выполняется через редактирование параметров загрузки ядра в GRUB.

Порядок действий:

1. Включить VM.
2. Дождаться меню GRUB.
3. Выбрать обычный пункт загрузки Ubuntu.
4. Нажать `e`.
5. Найти строку, которая начинается с `linux`.
6. В конец этой строки добавить параметр init и поменять монтирование на `rw`:

```text
rw init=/bin/bash
```

Пример строки после изменения:

```text
linux /vmlinuz-6.8.0-86-generic root=/dev/mapper/ubuntu--vg-ubuntu--lv rw init=/bin/bash console=tty1
```

После этого нажимаем `Ctrl+x` или `F10`.

Система загружается не через обычный init-процесс, а сразу запускает `/bin/bash`. В результате появляется shell с правами root без ввода пароля.

Проверка пользователя:

```bash
$ whoami
root
```

Проверка режима монтирования корневой файловой системы:

```bash
$ mount | grep ' / '
```

Обычно корневая файловая система в этом режиме смонтирована только для чтения:

```text
/dev/mapper/ubuntu--vg-ubuntu--lv on / type ext4 (rw,relatime)
```

Проверяем возможность записи:

```bash
$ echo "init bash test" > /root/init_bash_test.txt
$ cat /root/init_bash_test.txt
init bash test
```

Перезагрузка из такого режима:

```bash
sync
reboot -f
```

Вывод: способ `init=/bin/bash` дает самый прямой доступ к root shell без пароля. Корневая файловая система сначала доступна только для чтения (если руками не исправить на rw, как сделала я).

## 3. Попадание в систему без пароля. Способ 2: Recovery mode

Этот способ использует штатный режим восстановления Ubuntu.

Порядок действий:

1. Включить VM.
2. В меню GRUB выбрать пункт `Advanced options for Ubuntu`.
3. Выбрать ядро с пометкой `recovery mode`.
4. Дождаться меню восстановления.
5. Выбрать пункт `root`.
6. Получить root shell.

Проверяем пользователя:

```bash
$ whoami
root
```

Проверяем возможность записи:

```bash
$ echo "recovery mode test" > /root/recovery_mode_test.txt
$ cat /root/recovery_mode_test.txt
recovery mode test
```

После завершения работы можно продолжить обычную загрузку или перезагрузить систему:

```bash
reboot
```

Вывод: Recovery mode удобнее и безопаснее для обслуживания системы, чем `init=/bin/bash`, потому что он запускается через штатное меню восстановления. При этом доступ к root shell также можно получить без обычного входа в систему.

## 4. Проверка LVM

Перед переименованием Volume Group проверяем, что система действительно использует LVM.

Команды:

```bash
lsblk
vgs
lvs
```

```text
NAME                      MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0  64G  0 disk 
├─sda1                      8:1    0   1M  0 part 
├─sda2                      8:2    0   2G  0 part /boot
└─sda3                      8:3    0  62G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0  31G  0 lvm  /
VG        #PV #LV #SN Attr   VSize   VFree
ubuntu-vg   1   1   0 wz--n- <62.00g 31.00g
LV        VG        Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
ubuntu-lv ubuntu-vg -wi-ao---- <31.00g   
```

## 5. Переименование Volume Group

В примере исходное имя VG:

```text
ubuntu-vg
```

Новое имя VG:

```text
ubuntu-otus
```

Переходим в root:

```bash
sudo -i
```

Переименовываем Volume Group:

```bash
$ vgrename ubuntu-vg ubuntu-otus
Volume group "ubuntu-vg" successfully renamed to "ubuntu-otus"
```

Проверяем результат:

```bash
$ vgs
VG           #PV #LV #SN Attr   VSize   VFree
ubuntu-otus   1   1   0 wz--n- <62.00g 31.00g
```

## 6. Исправление конфигурации загрузчика после переименования VG

После переименования VG нужно исправить ссылки на старое имя VG в конфигурации загрузчика.

Проверяем старые упоминания:

```bash
$ grep -n "ubuntu--vg\|ubuntu-vg" /boot/grub/grub.cfg /etc/fstab
/boot/grub/grub.cfg:170:        linux   /vmlinuz-6.8.0-86-generic root=/dev/mapper/ubuntu--vg-ubuntu--lv ro net.ifnames=0 biosdevname=0  autoinstall ds=nocloud-net;s=http://10.0.2.2:8648/ubuntu/
/boot/grub/grub.cfg:189:                linux   /vmlinuz-6.8.0-86-generic root=/dev/mapper/ubuntu--vg-ubuntu--lv ro net.ifnames=0 biosdevname=0  autoinstall ds=nocloud-net;s=http://10.0.2.2:8648/ubuntu/
/boot/grub/grub.cfg:207:                linux   /vmlinuz-6.8.0-86-generic root=/dev/mapper/ubuntu--vg-ubuntu--lv ro single nomodeset dis_ucode_ldr net.ifnames=0 biosdevname=0 
/etc/fstab:8:# / was on /dev/ubuntu-vg/ubuntu-lv during curtin installation
```

Заменяем старое имя:

```bash
sed -i 's/ubuntu--vg/ubuntu--otus/g' /boot/grub/grub.cfg
sed -i 's/ubuntu-vg/ubuntu-otus/g; s/ubuntu--vg/ubuntu--otus/g' /etc/fstab
```

Перезагружаем систему:

```bash
reboot
```

## 7. Проверка после перезагрузки

После перезагрузки подключаемся к VM:

```bash
vagrant ssh
sudo -i
```

Проверяем Volume Group:

```bash
vgs
```

Ожидаемый результат:

```text
VG           #PV #LV #SN Attr   VSize   VFree
ubuntu-otus   1   1   0 wz--n- <62.00g 31.00g
```

Проверяем Logical Volume:

```bash
lvs
```

Ожидаемый результат:

```text
LV          VG          Attr       LSize
  ubuntu-lv ubuntu-otus -wi-ao---- <31.00g
```

Проверяем, что корневая файловая система загружена с нового имени VG:

```bash
findmnt /
```

```text
TARGET SOURCE                                      FSTYPE OPTIONS
/      /dev/mapper/ubuntu--otus-ubuntu--lv         ext4   rw,relatime
```

Проверяем, что старое имя больше не используется в GRUB:

```bash
grep -n "ubuntu--vg\|ubuntu-vg" /boot/grub/grub.cfg /etc/fstab
```

Если команда ничего не выводит, старые ссылки удалены.

Обновляем initramfs и конфигурацию GRUB:

```bash
update-initramfs -u
update-grub
```