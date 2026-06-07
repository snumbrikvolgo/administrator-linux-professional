# Задание 6: Сборка RPM-пакета и создание репозитория

## Цель домашнего задания

Научиться собирать RPM-пакеты. Создавать собственный RPM-репозиторий.

## Описание домашнего задания

1. Создать свой RPM-пакет.
2. Создать собственный RPM-репозиторий. Разместить в созданном репозитории ранее собранные RPM-пакеты.
3. Опубликовать репозиторий.

## Используемое окружение

Решение реализовано через Vagrant.

Используемая виртуальная машина:

- ОС: AlmaLinux 9;
- hostname: `packages`;
- провайдер: VirtualBox;
- CPU: 2;
- RAM: 4096 МБ;
- публикация HTTP с гостевой машины: `127.0.0.1:8080 -> 80`.

## Запуск стенда

Из каталога с `Vagrantfile` выполнить:

```bash
vagrant up
```

После завершения provisioning подключиться к виртуальной машине:

```bash
vagrant ssh
```

Проверить опубликованный репозиторий с хостовой машины:

```bash
curl http://127.0.0.1:8080/repo/
```

Проверить опубликованный репозиторий внутри виртуальной машины:

```bash
curl -a http://localhost/repo/
```

## Описание процесса сборки RPM-пакета

Все действия выполняются автоматически при разворачивании среды с помощью provisioning, см. скрипт [provision.sh](provision.sh).

### Установка необходимых пакетов

Сначала устанавливаются пакеты, необходимые для скачивания SRPM, сборки RPM и создания репозитория:

```bash
yum install -y wget rpmdevtools rpm-build createrepo yum-utils cmake gcc git nano dnf-plugins-core curl
```

### Включение необходимых репозиториев

В AlmaLinux 9 исходные репозитории могут быть выключены по умолчанию. Поэтому в скрипте выполняется включение CRB репозитория:

```bash
dnf config-manager --set-enabled crb || true
```

### Скачивание SRPM Apache/httpd

Создается рабочий каталог и скачивается SRPM-пакет Apache HTTP Server:

```bash
mkdir -p /root/rpm
cd /root/rpm
yumdownloader --source httpd
```

В AlmaLinux/RHEL Apache поставляется как пакет `httpd`, поэтому вместо `apache` используется имя `httpd`.

### Установка SRPM и зависимостей сборки

После скачивания SRPM устанавливается исходный пакет:

```bash
rpm -Uvh httpd*.src.rpm
```

После установки SRPM в домашней директории root создается дерево каталогов RPM-сборки:

```text
/root/rpmbuild/
├── BUILD
├── BUILDROOT
├── RPMS
├── SOURCES
├── SPECS
└── SRPMS
```

Далее устанавливаются зависимости для сборки:

```bash
yum-builddep -y httpd
```

### Изменение spec-файла

Основной spec-файл находится здесь:

```text
/root/rpmbuild/SPECS/httpd.spec
```

Перед изменениями создается копия исходного spec-файла:

```bash
cd /root/rpmbuild/SPECS/
cp httpd.spec httpd.spec.orig
```

Чтобы собранный RPM был отличим от стандартного пакета, меняется `Release`:

```bash
sed -i '0,/^Release:/s/^Release:.*/Release: 1%{?dist}.otus/' httpd.spec
```

Также в секцию `/configure` добавляется дополнительная configure-опция Apache:

```bash
--enable-asis=shared \
```

Эта опция включает сборку модуля `mod_asis` как shared-модуля Apache.

В скрипте добавление выполняется автоматически:

```bash
if ! grep -q -- '--enable-asis=shared' httpd.spec; then
  sed -i '/--enable-layout=Fedora/a\        --enable-asis=shared \\' httpd.spec
fi
```

### Сборка RPM

Сборка RPM-пакетов выполняется командой:

```bash
rpmbuild -ba httpd.spec -D 'debug_package %{nil}'
```

После успешной сборки RPM-пакеты появляются в каталоге:

```text
/root/rpmbuild/RPMS/x86_64/
```

Проверка:

```bash
ls -lah /root/rpmbuild/RPMS/x86_64/
```

### Установка собранного Apache/httpd

Собранные RPM-пакеты устанавливаются локально:

```bash
cd /root/rpmbuild/RPMS
ls -la noarch/
ls -la x86_64/
yum localinstall -y noarch/*.rpm x86_64/*.rpm
```

После этого Apache используется не только как результат сборки, но и как HTTP-сервер для публикации собственного репозитория.

## Описание созданного репозитория и способа публикации

### Создание каталога репозитория

Для Apache стандартная директория веб-документов:

```text
/var/www/html/
```

В ней создается каталог репозитория:

```bash
mkdir -p /var/www/html/repo
```

### Копирование RPM-пакетов в репозиторий

Собранные RPM-пакеты копируются в каталог репозитория:

```bash
cp /root/rpmbuild/RPMS/x86_64/*.rpm /var/www/html/repo/
cp /root/rpmbuild/RPMS/noarch/*.rpm /var/www/html/repo/
```

### Создание metadata репозитория

Для работы `yum`/`dnf` нужна metadata в каталоге `repodata`.

Metadata создается командой:

```bash
createrepo /var/www/html/repo/
```

После этого появляется каталог:

```text
/var/www/html/repo/repodata/
```

### Настройка Apache для публикации репозитория

Создается файл:

```text
/etc/httpd/conf.d/repo.conf
```

Содержимое:

```apache
Alias /repo/ "/var/www/html/repo/"

<Directory "/var/www/html/repo/">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
```

Проверка конфигурации Apache:

```bash
mkdir -p /etc/pki/tls/certs
mkdir -p /etc/pki/tls/private

openssl req -newkey rsa:2048 -nodes -keyout /etc/pki/tls/private/localhost.key \
  -x509 -days 365 \
  -out /etc/pki/tls/certs/localhost.crt \
  -subj "/CN=localhost"

httpd -t
```

Запуск Apache:

```bash
systemctl enable --now httpd
systemctl reload httpd
```

Проверка HTTP-доступа:

```bash
curl -a http://localhost/repo/
```

С хостовой машины после `vagrant up` можно открыть:

```text
http://127.0.0.1:8080/repo/
```

## Подключение собственного репозитория

Создается файл:

```text
/etc/yum.repos.d/otus.repo
```

Содержимое:

```ini
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
```

После этого выполняется обновление cache:

```bash
yum clean all
yum makecache
```

Проверка, что репозиторий подключен:

```bash
yum repolist enabled | grep otus
```

## Добавление пакета в собственный репозиторий

Для проверки обновления репозитория в каталог `/var/www/html/repo/` добавляется внешний RPM-пакет `percona-release`:

```bash
cd /var/www/html/repo/
wget -N https://repo.percona.com/yum/percona-release-latest.noarch.rpm
```

После добавления любого нового RPM-файла metadata репозитория нужно пересоздать:

```bash
createrepo /var/www/html/repo/
```

Далее обновляется cache:

```bash
yum makecache
```

Проверяется наличие пакетов из собственного репозитория:

```bash
yum list | grep otus
```

Проверяется установка пакета из собственного репозитория:

```bash
yum install -y percona-release.noarch
```

## Проверка результата

После выполнения `vagrant up` можно проверить состояние стенда:

```bash
vagrant ssh
```

```bash
systemctl status httpd --no-pager
httpd -t
ls -lah /var/www/html/repo/
ls -lah /var/www/html/repo/repodata/
curl -a http://localhost/repo/
yum repolist enabled | grep otus
yum makecache
yum list | grep otus
find /var/www/html/repo -maxdepth 1 -type f -name 'httpd*.rpm' -print
```

Результат:

1. Сервис `httpd` запущен.
2. Конфигурация Apache корректна.
3. Каталог `/var/www/html/repo/` содержит собранные RPM-пакеты `httpd`.
4. В каталоге `/var/www/html/repo/repodata/` есть metadata репозитория.
5. URL `http://localhost/repo/` внутри VM открывается.
6. URL `http://127.0.0.1:8080/repo/` открывается с хостовой машины.
7. Репозиторий `otus` виден через `yum repolist enabled`.
8. Пакет `percona-release.noarch` устанавливается из собственного репозитория.