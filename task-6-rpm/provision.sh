#!/usr/bin/env bash
set -euo pipefail

yum install -y wget rpmdevtools rpm-build createrepo yum-utils cmake gcc git nano dnf-plugins-core curl

dnf config-manager --set-enabled crb || true

mkdir -p /root/rpm
cd /root/rpm
yumdownloader --source httpd

rpm -Uvh httpd*.src.rpm
yum-builddep -y httpd

cd /root/rpmbuild/SPECS/

cp -f httpd.spec httpd.spec.orig

sed -i '0,/^Release:/s/^Release:.*/Release: 1%{?dist}.otus/' httpd.spec

if ! grep -q -- '--enable-asis=shared' httpd.spec; then
  sed -i '/--enable-layout=Fedora/a\        --enable-asis=shared \\' httpd.spec
fi

grep -n -- '--enable-asis=shared' httpd.spec

rpmbuild -ba httpd.spec -D 'debug_package %{nil}'

cd /root/rpmbuild/RPMS

ls -la noarch/
ls -la x86_64/

yum localinstall -y noarch/*.rpm x86_64/*.rpm

mkdir -p /var/www/html/repo
cp /root/rpmbuild/RPMS/x86_64/*.rpm /var/www/html/repo/
cp /root/rpmbuild/RPMS/noarch/*.rpm /var/www/html/repo/

createrepo /var/www/html/repo/

cat > /etc/httpd/conf.d/repo.conf <<'REPOCONF'
Alias /repo/ "/var/www/html/repo/"

<Directory "/var/www/html/repo/">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
REPOCONF

mkdir -p /etc/pki/tls/certs
mkdir -p /etc/pki/tls/private

openssl req -newkey rsa:2048 -nodes -keyout /etc/pki/tls/private/localhost.key \
  -x509 -days 365 \
  -out /etc/pki/tls/certs/localhost.crt \
  -subj "/CN=localhost"

httpd -t
systemctl enable --now httpd
systemctl reload httpd

curl -a http://localhost/repo/

cat > /etc/yum.repos.d/otus.repo <<'EOF_REPO'
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF_REPO

yum clean all
yum makecache
yum repolist enabled | grep otus

cd /var/www/html/repo/
wget -N https://repo.percona.com/yum/percona-release-latest.noarch.rpm
createrepo /var/www/html/repo/
yum makecache
yum list | grep otus
yum install -y percona-release.noarch
