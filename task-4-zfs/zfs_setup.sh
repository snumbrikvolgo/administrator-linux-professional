#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y zfsutils-linux wget ca-certificates
zfs version || true

sudo zpool create -f otus1 mirror /dev/sdb /dev/sdc
sudo zpool create -f otus2 mirror /dev/sdd /dev/sde
sudo zpool create -f otus3 mirror /dev/sdf /dev/sdg
sudo zpool create -f otus4 mirror /dev/sdh /dev/sdi

zpool list

sudo zfs set compression=lzjb otus1
sudo zfs set compression=lz4 otus2
sudo zfs set compression=gzip-9 otus3
sudo zfs set compression=zle otus4

zfs get compression otus1 otus2 otus3 otus4

sudo wget -O /otus1/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'
sudo wget -O /otus2/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'
sudo wget -O /otus3/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'
sudo wget -O /otus4/pg2600.converter.log 'https://gutenberg.org/cache/epub/2600/pg2600.converter.log'

zfs list
zfs get all | grep compressratio | grep -v ref

sudo wget -O /root/archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download'
sudo tar -xzf /root/archive.tar.gz -C /root
sudo ls /root

sudo zpool import -d /root/zpoolexport
sudo zpool import -d /root/zpoolexport otus

zpool status otus
zpool get size,allocated,free,health otus
zfs get available,recordsize,compression,checksum otus

sudo wget -O /root/otus_task2.file --no-check-certificate 'https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download'

sudo zfs receive otus/test@today < /root/otus_task2.file

find /otus/test -type f -name secret_message -print
cat "$(find /otus/test -type f -name secret_message -print -quit)"