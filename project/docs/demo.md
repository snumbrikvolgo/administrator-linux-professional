# Сценарий полной демонстрации

Этот документ оформлен как отчёт о последовательной демонстрации: запуск стенда, проверка всех подсистем, контролируемые отказы и редеплой через «голый» snapshot `preprovisioning` и Ansible.

> Команды остановки VM и восстановления snapshot ниже при подготовке документа не выполнялись. Выполнены только проверки работающей системы и создание скриншотов.

## URL для просмотра из Windows

Адреса соответствуют `Vagrantfile` и пробросу портов на `127.0.0.1`:

| Компонент | URL в браузере Windows |
| --- | --- |
| CMS HTTP / HTTPS | `http://localhost:5666` / `https://localhost:5777` |
| Prometheus Targets / Alerts | `http://localhost:9090/targets` / `http://localhost:9090/alerts` |
| Alertmanager | `http://localhost:9093` |
| Grafana | `http://localhost:3000/d/cms-overview/cms-infrastructure-overview` (автоматический Viewer-вход) |
| Kibana | `http://localhost:5601` |
| Elasticsearch API | `http://localhost:9200` |

Сертификат CMS самоподписанный, поэтому использовать в командах `curl.exe -k`. Предупреждение браузера подтвердить до начала записи. Адреса `192.168.57.10`–`192.168.57.13` относятся к внутренней сети VM; в браузере Windows их не использовать.

## Организация пространства записи

Разделить запись на четыре самостоятельных видео:

1. `01-working-system.mkv` — полностью рабочая система.
2. `02-web-redeploy.mkv` — отказ и редеплой `web`.
3. `03-app-redeploy.mkv` — последовательный отказ `app2`, затем `app1`, восстановление одной и обеих VM.
4. `04-elk-redeploy.mkv` — отказ и редеплой `elk`.

Организовать на одном виртуальном рабочем столе три зоны: PowerShell слева, WSL справа, браузер в отдельном полноэкранном окне. Увеличить шрифт терминалов, сократить prompt, отключить уведомления Windows, убрать лишние вкладки и секреты. Заранее открыть CMS, Grafana dashboard, Kibana Discover, Prometheus Targets/Alerts и Alertmanager. В OBS записывать весь экран в 1920×1080, 30 FPS, MKV; курсор оставить видимым.

> **Команда оператору MCP/OBS.** Перед каждым видео проверяется имя выходного файла, запускается запись OBS, затем кадр удерживается 2–3 секунды. Новое действие не выполняется, пока предыдущая команда не завершилась и её итог не появился в терминале или браузере. Длительные `ansible-playbook`, `vagrant`, `sleep` и `curl` с timeout не прерываются. После каждой команды заново считывается состояние окна; старые координаты элементов не используются.
>
> Терминалы захватываются как окна Windows Terminal: отдельная вкладка PowerShell и отдельная вкладка WSL. Браузер захватывается отдельным источником. Переключение сцен OBS выполняется только после появления нужного результата. В отчёт копируется полный текст команды и относящийся к ней вывод без prompt предыдущей команды.
>
> Если MCP не видит OBS, Windows Terminal или браузер, запись не начинается. Сначала восстанавливается доступ к окнам, затем повторно проверяется кадр. Остановка VM или restore snapshot не запускаются «вслепую».

Использовать путь репозитория `C:\Users\dandy\administrator-linux-professional\project`.

### Единый блок поднятия системы: Windows + WSL

Windows PowerShell:

```powershell
cd C:\Users\dandy\administrator-linux-professional\project
vagrant up
vagrant status
wsl bash -lc 'cd /mnt/c/Users/dandy/administrator-linux-professional/project && export ANSIBLE_CONFIG=./ansible.cfg && ./scripts/generate_inventory.sh && ansible-playbook -i inventory/hosts.ini playbooks/site.yml && ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml && ansible-playbook -i inventory/hosts.ini playbooks/verify.yml'
```

Затем подготовить в WSL окружение для остальных сцен:

```bash
cd /mnt/c/Users/dandy/administrator-linux-professional/project
export ANSIBLE_CONFIG=./ansible.cfg
./scripts/generate_inventory.sh

W='ssh.exe -p 50001 -i C:/Users/dandy/administrator-linux-professional/project/.vagrant/machines/web/virtualbox/private_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL vagrant@127.0.0.1'
A1='ssh.exe -p 50100 -i C:/Users/dandy/administrator-linux-professional/project/.vagrant/machines/app1/virtualbox/private_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL vagrant@127.0.0.1'
A2='ssh.exe -p 50400 -i C:/Users/dandy/administrator-linux-professional/project/.vagrant/machines/app2/virtualbox/private_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL vagrant@127.0.0.1'
E='ssh.exe -p 50500 -i C:/Users/dandy/administrator-linux-professional/project/.vagrant/machines/elk/virtualbox/private_key -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL vagrant@127.0.0.1'
```

## Полностью рабочая система

### 1. VM и сервисы

Windows PowerShell:

```powershell
vagrant status
vagrant ssh web -c "sudo systemctl is-active nginx filebeat node_exporter"
vagrant ssh app1 -c "sudo systemctl is-active cms-backend postgresql filebeat node_exporter cms-backup.timer"
vagrant ssh app2 -c "sudo systemctl is-active cms-backend postgresql filebeat node_exporter"
vagrant ssh elk -c "sudo systemctl is-active prometheus alertmanager grafana-server elasticsearch logstash kibana blackbox_exporter node_exporter"
```

### 2. CMS, API и балансировка

Windows PowerShell:

```powershell
curl.exe -sS -o NUL -w "HTTP %{http_code}; redirect=%{redirect_url}`n" http://localhost:5666/
curl.exe -k -sS -o NUL -w "HTTPS %{http_code}`n" https://localhost:5777/
1..8 | ForEach-Object { curl.exe -k -sS https://localhost:5777/api/whoami; "" }
curl.exe -k -sS https://localhost:5777/api/health
curl.exe -k -sS https://localhost:5777/api/articles
```

Открыть в браузере `https://localhost:5777`, создать статью, затем несколько раз обновить страницу. Зафиксировать переключение поля `Backend` между `app1` и `app2`.

### 3. БД, репликация и backup

WSL:

```bash
$A1 "sudo -u postgres psql -d cms -c 'TABLE articles;'"
$A1 "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery();'"
$A2 "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery();'"
$A1 "sudo -u postgres psql -x -c 'SELECT client_addr,state,sync_state FROM pg_stat_replication;'"
$A2 "sudo -u postgres psql -d cms -c 'TABLE articles;'"
$A1 'sudo systemctl status cms-backup.timer --no-pager'
$A1 'sudo ls -lh /var/backups/cms/'
```

### 4. Мониторинг и алерты в норме

Windows PowerShell:

```powershell
curl.exe -sS http://localhost:9090/api/v1/targets?state=active
curl.exe -sS http://localhost:9090/api/v1/alerts
curl.exe -sS http://localhost:9093/api/v2/alerts
curl.exe -sS http://localhost:3000/api/health
```

В браузере зафиксировать следующие результаты:

1. Prometheus Targets: `backend (2/2 up)`, `cms (1/1 up)`, `node (4/4 up)`.
2. Prometheus Alerts: `InstanceDown`, `BackendDown`, `CmsDown`, `HighDiskUsage` не firing.
3. Alertmanager: активных групп нет.
4. Grafana dashboard `CMS infrastructure overview`: 7 healthy targets, CMS probe `1`, два healthy backend и ноль firing alerts.

### 5. Централизованные логи

WSL:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
curl -s 'http://localhost:9200/_cat/indices/cms-*?v'
curl -s 'http://localhost:9200/cms-nginx-*/_count?pretty'
curl -s 'http://localhost:9200/cms-backend-*/_count?pretty'
curl -s -H 'Content-Type: application/json' 'http://localhost:9200/cms-nginx-*/_search?pretty' -d '{"size":5,"sort":[{"@timestamp":"desc"}],"query":{"range":{"status":{"gte":500}}}}'
$W 'sudo tail -n 10 /var/log/nginx/cms_access.log'
$W 'sudo tail -n 10 /var/log/nginx/cms_error.log'
```

В Kibana открыть Discover → data view `CMS logs` (`cms-*`). Зафиксировать свежие документы, гистограмму поступления событий и разобранные Logstash поля `service`, `backend`, `method`, `request`, `status`. Применить фильтры `service: nginx`, `service: backend`, `status >= 500`.

### 6. Полная автоматическая проверка

```bash
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

> **Съёмка видео 01.** После `vagrant status` вывод копируется в этот отчёт. После `verify.yml` копируется весь `PLAY RECAP`. Затем MCP переключается на CMS и снимает скриншот, на Prometheus Targets и снимает скриншот, на Grafana dashboard и снимает скриншот, на Kibana Discover и снимает скриншот. Запись OBS останавливается только после последнего скриншота.

### Скриншоты рабочего состояния

![Работающая CMS](screenshots/cms-working.png)

![Все цели Prometheus работают](screenshots/prometheus-targets-working.png)

![Доступная Grafana](screenshots/grafana-working.png)

![Доступная Kibana](screenshots/kibana-working.png)

## Редеплой web

Перед второй записью открыть CMS, Prometheus Targets/Alerts, Alertmanager, Grafana dashboard и Kibana.

### 1. Остановить web

Windows PowerShell:

```powershell
vagrant halt web
vagrant status web
curl.exe -k -sS --max-time 5 -o NUL -w "%{http_code}`n" https://localhost:5777/
```

Вывод:

```text
web                       poweroff (virtualbox)
curl: (7) Failed to connect to localhost port 5777
000
```

### 2. Показать связанные последствия

Ожидание составляло не менее 75 секунд: `CmsDown` имеет `for: 30s`, `InstanceDown` — `for: 1m`.

WSL:

```bash
sleep 75
curl -s 'http://localhost:9090/api/v1/query?query=probe_success%7Bjob%3D%22cms%22%7D' | python3 -m json.tool
curl -s 'http://localhost:9090/api/v1/query?query=up%7Binstance%3D%22web%3A9100%22%7D' | python3 -m json.tool
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
$E 'sudo tail -n 80 /var/spool/mail/root'
```

Вывод:

```text
probe_success{job="cms"} = 0
up{instance="web:9100"} = 0
CmsDown      state=firing
InstanceDown state=firing
Subject: [FIRING:1] CmsDown
Subject: [FIRING:1] InstanceDown
```

В браузере зафиксировать недоступную CMS, красные цели `cms` и `web:9100`, алерты `CmsDown` и `InstanceDown`, группу Alertmanager. В Kibana зафиксировать прекращение новых nginx-логов. БД в этой сцене не проверять.

> **Съёмка видео 02 — момент отказа.** Сразу после `vagrant halt web` в отчёт копируются вывод `vagrant status web` и ошибка `curl`. После 75 секунд копируются JSON активных алертов и темы писем. MCP снимает скриншоты Prometheus Targets, Prometheus Alerts, Alertmanager и Grafana с упавшими значениями. Скриншот ошибки браузера CMS делается только если interstitial не перекрывает страницу.

### 3. Snapshot и настройка Ansible

Windows PowerShell:

```powershell
vagrant snapshot restore web preprovisioning --no-provision
vagrant status web
```

WSL:

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit web
```

### 4. Показать восстановление тех же сигналов

```bash
curl -ksS -o /dev/null -w '%{http_code}\n' https://192.168.57.10/
sleep 75
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
$E 'sudo tail -n 80 /var/spool/mail/root'
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
curl -s 'http://localhost:9200/cms-nginx-*/_count?pretty'
```

После обновления тех же вкладок зафиксировать доступную CMS, зелёные цели, resolved/inactive алерты и возобновление появления nginx-документов.

> **Съёмка видео 02 — восстановление.** Полный `PLAY RECAP` редеплоя копируется после завершения Ansible, затем копируются resolved-письма и результаты повторных `curl`. MCP снимает Grafana после возврата значений `7/1/2/0` и Kibana с возобновившимся потоком логов. После этого запись OBS завершается.

## Редеплой app

Сначала останавливается `app2`: primary-БД находится на `app1`, поэтому остановка `app1` первой сразу лишила бы оба backend доступа к данным.

### 1. Остановить app2: система работает через app1

Windows PowerShell:

```powershell
vagrant halt app2
vagrant status app1
vagrant status app2
1..8 | ForEach-Object { curl.exe -k -sS https://localhost:5777/api/whoami; "" }
curl.exe -k -sS -o NUL -w "frontend=%{http_code}`n" https://localhost:5777/
curl.exe -k -sS -o NUL -w "articles=%{http_code}`n" https://localhost:5777/api/articles
curl.exe -k -sS https://localhost:5777/api/health
```

WSL:

```bash
sleep 75
$A1 "sudo -u postgres psql -tAc 'SELECT count(*) FROM pg_stat_replication;'"
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
$E 'sudo tail -n 80 /var/spool/mail/root'
```

Вывод:

```text
{"backend":"app1"}
frontend=200
articles=200
0
BackendDown  instance=http://app2:8000/api/health  state=firing
InstanceDown instance=app2:9100                      state=firing
```

Зафиксировать доступность CMS и БД, значение `Backend: app1` и сообщения мониторинга об отказе `app2` и его backend.

> **Съёмка видео 03 — отказ app2.** В отчёт копируются `vagrant status app2`, серия `whoami`, HTTP-коды, число реплик `0`, активные алерты и темы писем. MCP снимает CMS с `Backend: app1` и Grafana, где healthy backends стало `1`, а firing alerts стало больше нуля. Переход к остановке `app1` выполняется только после сохранения этих материалов.

### 2. Остановить app1: API и БД недоступны

Windows PowerShell:

```powershell
vagrant halt app1
vagrant status app1
vagrant status app2
curl.exe -k -sS --max-time 5 -o NUL -w "frontend=%{http_code}`n" https://localhost:5777/
curl.exe -k -sS --max-time 5 -o NUL -w "whoami=%{http_code}`n" https://localhost:5777/api/whoami
curl.exe -k -sS --max-time 5 -o NUL -w "health=%{http_code}`n" https://localhost:5777/api/health
curl.exe -k -sS --max-time 5 -o NUL -w "articles=%{http_code}`n" https://localhost:5777/api/articles
```

WSL:

```bash
sleep 75
$W 'sudo tail -n 30 /var/log/nginx/cms_error.log'
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
$E 'sudo tail -n 120 /var/spool/mail/root'
```

Вывод:

```text
frontend=200
whoami=502
health=502
articles=502
connect() failed (111: Connection refused) while connecting to upstream
BackendDown  instance=http://app1:8000/api/health  state=firing
BackendDown  instance=http://app2:8000/api/health  state=firing
InstanceDown instance=app1:9100                      state=firing
InstanceDown instance=app2:9100                      state=firing
```

Статическая страница nginx может отвечать при недоступных API. В отчёт включить коды API, nginx upstream errors, красные backend/node targets и письма.

> **Съёмка видео 03 — отказ обеих VM.** Вывод четырёх `curl`, последние строки `cms_error.log`, алерты и письма копируются в отчёт. MCP снимает ошибку загрузки статей в CMS, Prometheus Targets и красную Grafana. Восстановление `app1` начинается только после завершения этих снимков.

### 3. Восстановить app1: минимально рабочая система

Windows PowerShell:

```powershell
vagrant up app1 --no-provision
```

WSL:

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app1
curl -ksS https://192.168.57.10/api/health
curl -ksS -o /dev/null -w '%{http_code}\n' https://192.168.57.10/api/articles
for i in $(seq 1 6); do curl -ksS https://192.168.57.10/api/whoami; echo; done
```

### 4. Восстановить app2: полная система

Windows PowerShell:

```powershell
vagrant up app2 --no-provision
```

WSL:

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app2
$A1 "sudo -u postgres psql -x -c 'SELECT client_addr,state,sync_state FROM pg_stat_replication;'"
$A2 "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery();'"
for i in $(seq 1 8); do curl -ksS https://192.168.57.10/api/whoami; echo; done
sleep 75
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool
$E 'sudo tail -n 120 /var/spool/mail/root'
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

Зафиксировать возвращение обоих backend в балансировку, состояние PostgreSQL `streaming` и исчезновение тех же алертов.

> **Съёмка видео 03 — восстановление.** После восстановления только `app1` в отчёт копируются HTTP-коды и серия `whoami`, содержащая только `app1`. После восстановления `app2` копируются `pg_stat_replication`, новая серия `whoami` с обоими backend и итоговый `PLAY RECAP`. MCP снимает зелёную Grafana и рабочую CMS, затем запись OBS завершается.

> Для редеплоя без потери БД использовать `vagrant up --no-provision` и повторный Ansible-прогон. При обязательной демонстрации «голого» snapshot `preprovisioning` у `app1` одновременно восстановить `app1` и `app2`, затем выполнить `site.yml --limit app1,app2`: snapshot не содержит рабочую primary-БД, поэтому созданные после него данные теряются.

## Редеплой elk

При остановке `elk` CMS продолжает работать, но одновременно исчезают Prometheus, Alertmanager, Grafana, Elasticsearch, Logstash и Kibana. Внешний алерт или письмо об отказе самого `elk` создать некому — это важно проговорить.

### 1. Зафиксировать время и остановить elk

WSL:

```bash
date -Is
curl -s 'http://localhost:9200/cms-*/_count?pretty'
```

Windows PowerShell:

```powershell
vagrant halt elk
vagrant status elk
curl.exe -k -sS -o NUL -w "CMS=%{http_code}`n" https://localhost:5777/
foreach ($port in 9090,9093,3000,5601,9200) { curl.exe -sS --max-time 4 -o NUL -w "port=$port code=%{http_code}`n" "http://localhost:$port/" }
```

Вывод:

```text
elk                       poweroff (virtualbox)
CMS=200
port=9090 code=000
port=9093 code=000
port=3000 code=000
port=5601 code=000
port=9200 code=000
curl: (7) Failed to connect to localhost port ...
```

### 2. Показать разрыв наблюдаемости

```bash
for i in $(seq 1 20); do curl -ksS https://192.168.57.10/ >/dev/null; curl -ksS https://192.168.57.10/api/whoami >/dev/null; done
$W 'sudo journalctl -u filebeat --since "5 minutes ago" --no-pager'
$A1 'sudo journalctl -u filebeat --since "5 minutes ago" --no-pager'
$A2 'sudo journalctl -u filebeat --since "5 minutes ago" --no-pager'
date -Is
```

Зафиксировать работающую CMS и недоступные Prometheus, Alertmanager, Grafana и Kibana. Метрики в этот интервал не собираются, поэтому на графиках остаётся пробел. Filebeat может дослать неподтверждённые события после возврата Logstash, поэтому гарантированный пробел относится к метрикам; не утверждать о безвозвратной потере всех логов.

Вывод Filebeat:

```text
Failed to connect to backoff(async(tcp://192.168.57.13:5044))
connect: no route to host
publisher pipeline is blocked
```

> **Съёмка видео 04 — отказ.** В отчёт копируются время начала отказа, исходный `_count`, `vagrant status elk`, HTTP-код CMS, ошибки всех пяти портов и журнал Filebeat. MCP снимает рабочую CMS и ошибки открытия Prometheus, Grafana и Kibana. Новое действие начинается только после того, как сохранён последний кадр.

### 3. Snapshot и настройка elk Ansible

Windows PowerShell:

```powershell
vagrant snapshot restore elk preprovisioning --no-provision
vagrant status elk
```

WSL:

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit elk
```

На первичную установку ELK закладывать до 15–20 минут; следующий шаг начинать только после окончания playbook.

### 4. Показать возвращение мониторинга и логов

```bash
for p in 9090 9093 3000 5601 9200; do curl -sS -o /dev/null -w ":$p %{http_code}\n" "http://localhost:$p/"; done
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
sleep 30
curl -s 'http://localhost:9090/api/v1/targets?state=active' | python3 -m json.tool
curl -s 'http://localhost:9200/_cat/indices/cms-*?v'
curl -s 'http://localhost:9200/cms-nginx-*/_count?pretty'
curl -s 'http://localhost:9200/cms-backend-*/_count?pretty'
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

После обновления Prometheus Targets, Grafana и Kibana зафиксировать зелёные цели, разрыв графика за время простоя и снова появляющиеся свежие логи.

> **Съёмка видео 04 — восстановление.** Полный `PLAY RECAP`, ответы пяти портов, targets и новые значения `_count` копируются в отчёт. MCP снимает Grafana с пробелом в ряду доступности и Kibana Discover с новыми документами после восстановления. Запись OBS завершается после итогового `verify.yml`.

## Финальный кадр

WSL:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

Windows PowerShell:

```powershell
vagrant status
curl.exe -k -sS -o NUL -w "CMS %{http_code}`n" https://localhost:5777/
curl.exe -sS -o NUL -w "Prometheus %{http_code}`n" http://localhost:9090/-/ready
curl.exe -sS -o NUL -w "Alertmanager %{http_code}`n" http://localhost:9093/-/healthy
curl.exe -sS -o NUL -w "Grafana %{http_code}`n" http://localhost:3000/api/health
curl.exe -sS -o NUL -w "Kibana %{http_code}`n" http://localhost:5601/api/status
curl.exe -sS -o NUL -w "Elasticsearch %{http_code}`n" http://localhost:9200/_cluster/health
```
