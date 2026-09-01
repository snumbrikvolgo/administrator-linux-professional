# Шпаргалка: развернуть -> сломать компонент -> восстановить -> проверить

Все команды Ansible -- из WSL, из каталога проекта, с явным конфигом (Ansible игнорирует `ansible.cfg` в world-writable каталоге на `/mnt/c`):

```bash
cd /mnt/c/Users/zazhigina/administrator-linux-professional/project
export ANSIBLE_CONFIG=./ansible.cfg
```

SSH к VM (ключи пишет `scripts/generate_inventory.sh` в `~/.ansible/keys/`):

```bash
W='ssh -i ~/.ansible/keys/web  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.57.10'
A1='ssh -i ~/.ansible/keys/app1 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.57.11'
A2='ssh -i ~/.ansible/keys/app2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.57.12'
E='ssh  -i ~/.ansible/keys/elk  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@192.168.57.13'
```

`scripts/generate_inventory.sh` -- единственный shell. Пишет `inventory/hosts.ini` из ключей Vagrant до того, как у Ansible появляется inventory. Проверка и генерация трафика -- это playbook'и: `playbooks/verify.yml`, `playbooks/generate_logs.yml`.

Читать письма алертов -- на elk: `$E 'sudo mail'` или `$E 'sudo cat /var/spool/mail/root'`.

---

# 0. Baseline: система работает

## Развернуть с нуля

Windows PowerShell:

```powershell
cd C:\Users\zazhigina\administrator-linux-professional\project
vagrant up
```

WSL:

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

`verify.yml` заканчивается `failed=0` на `localhost`, `app1`, `app2`. Проверяет: HTTPS 200 и redirect, health обоих backend, балансировку `/api/whoami`, CRUD статьи, `/api/demo-error` -> 500, Prometheus (>=7 targets up, 4 правила), Grafana, Alertmanager, Elasticsearch (>= yellow), Kibana (available), Logstash 5044, непустые `cms-nginx-*` и `cms-backend-*`, распарсенный документ `status:500`, репликацию (primary `f` + `streaming`, replica `t`).

## Показать руками (для видео)

| Сервис | URL | В норме видно |
| --- | --- | --- |
| CMS | `https://192.168.57.10` | форма Title/Text/Create, список статей, внизу `Backend: app1` или `app2`; F5 -- значение чередуется |
| Prometheus targets | `http://192.168.57.13:9090/targets` | 7 целей, все зеленые: `node` x4, `backend` x2, `cms` x1 |
| Prometheus alerts | `http://192.168.57.13:9090/alerts` | `InstanceDown`, `BackendDown`, `CmsDown`, `HighDiskUsage` -- все серые (`Inactive`) |
| Alertmanager | `http://192.168.57.13:9093` | `No alert groups` |
| Grafana | `http://192.168.57.13:3000` (`admin`/`admin`) | Explore: `probe_success` = 1 для всех, `up` = 1 |
| Kibana | `http://192.168.57.13:5601` -> Discover | data view `cms-*`, фильтр `service: nginx` -- поток строк с полями `method`, `request`, `status`; `status >= 500` находит `/api/demo-error` |
| Почта алертов | `$E 'sudo mail'` | пусто (нет писем) |

---

# Общая схема для каждой машины

```
1. Сломать       vagrant halt <vm>                     (машина целиком)
                 или  ssh <vm> sudo systemctl stop ...  (только компонент)
2. Наблюдать      curl / Prometheus API / браузер / $E 'sudo mail'
3. Восстановить   vagrant snapshot restore <vm> base-vm-up --no-provision
                 ./scripts/generate_inventory.sh
                 ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit <vm>
4. Проверить      ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

Легкий вариант шага 1/3 (без snapshot, данные сохраняются): `systemctl stop` -> `ansible-playbook --limit <vm>`. Роль сама поднимает сервисы, `changed` = число перезапущенных юнитов. Snapshot-вариант -- это "машину потеряли".

`vagrant halt` дополнительно роняет `node_exporter`, поэтому срабатывает еще и `InstanceDown` для этой VM. При `systemctl stop` конкретного сервиса `node_exporter` жив -- `InstanceDown` не сработает, только прикладные алерты.

---

# 1. web -- nginx, frontend, TLS, reverse proxy, балансировка

## Сломать

```bash
$W 'sudo systemctl stop nginx'          # или: vagrant halt web
```

## Наблюдать

```bash
curl -ks -m 5 -o /dev/null -w '%{http_code}\n' https://192.168.57.10/
#   000, Connection refused -- единственная точка входа недоступна

curl -s 'http://192.168.57.13:9090/api/v1/query?query=probe_success%7Bjob%3D%22cms%22%7D' \
  | python3 -c "import sys,json;[print(m['metric']['instance'],m['value'][1]) for m in json.load(sys.stdin)['data']['result']]"
#   https://192.168.57.10/ 0

sleep 60
curl -s http://192.168.57.13:9090/api/v1/alerts \
  | python3 -c "import sys,json;[print(a['labels']['alertname'],a['labels'].get('instance'),a['state']) for a in json.load(sys.stdin)['data']['alerts']]"
#   CmsDown  https://192.168.57.10/  firing   (при vagrant halt -- еще InstanceDown web:9100)

$E 'sudo grep ^Subject: /var/spool/mail/root'
#   Subject: [FIRING:1]  (CmsDown ...)
```

Руками:

- браузер `https://192.168.57.10` -- "не удается установить соединение".
- `http://192.168.57.13:9090/targets` -- строка `cms` красная (`DOWN, connection refused`).
- `http://192.168.57.13:9090/alerts` -- `CmsDown` желтый (`PENDING`), через 30 c красный (`FIRING`).
- `http://192.168.57.13:9093` -- группа с `CmsDown`.
- Grafana Explore `probe_success{job="cms"}` -- график падает в 0.
- Kibana Discover `service: nginx`, сортировка по `@timestamp` вниз -- новые строки перестают появляться.

## Восстановить

```bash
# машина целиком:
#   PowerShell> vagrant snapshot restore web base-vm-up --no-provision
#   WSL>        ./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit web
```

Роль `web` ставит nginx+openssl, кладет self-signed сертификат (SAN `web`, `cms.local`, `192.168.57.10`), фронтенд и конфиг с `proxy_next_upstream`, поднимает nginx. Роль `filebeat` возвращает отгрузку логов.

## Проверить

```bash
curl -ks -o /dev/null -w '%{http_code}\n' https://192.168.57.10/       # 200
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml           # failed=0
```

Через ~1 мин `CmsDown` снова `Inactive`, Alertmanager пуст, приходит письмо `[RESOLVED]`. В Kibana снова идут строки nginx.

---

# 2. app1 -- backend #1 + PostgreSQL primary

`app1` держит второй backend и primary-БД для обоих backend (`DB_HOST=192.168.57.11`). Его падение ломает запись и чтение CMS целиком. Статика и `/api/whoami` частично живут через `app2`.

## Сломать

```bash
$A1 'sudo systemctl stop cms-backend postgresql'      # или: vagrant halt app1
```

## Наблюдать

```bash
curl -ks -o /dev/null -w 'frontend=%{http_code}\n' https://192.168.57.10/       # 200 (статика с web)
for i in $(seq 1 6); do curl -ks https://192.168.57.10/api/whoami; echo; done    # только app2 (whoami не ходит в БД)
curl -ks https://192.168.57.10/api/health                                        # 500 Internal Server Error
curl -ks -o /dev/null -w 'articles=%{http_code}\n' https://192.168.57.10/api/articles   # 500

$W 'sudo tail -3 /var/log/nginx/cms_error.log'
#   connect() failed (111: Connection refused) ... upstream: "http://192.168.57.11:8000/..."

$A2 "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery()'"   # t -- реплика жива, отдает устаревшее чтение

sleep 75
curl -s http://192.168.57.13:9090/api/v1/alerts \
  | python3 -c "import sys,json;[print(a['labels']['alertname'],a['labels'].get('instance'),a['state']) for a in json.load(sys.stdin)['data']['alerts']]"
#   BackendDown  http://app1:8000/api/health  firing
#   BackendDown  http://app2:8000/api/health  firing   <- оба, т.к. /api/health на обоих отдает 500
#   (при vagrant halt app1 -- еще InstanceDown app1:9100)

$E 'sudo grep ^Subject: /var/spool/mail/root'          # [FIRING:2]  (BackendDown ...)
```

Руками:

- браузер `https://192.168.57.10` -- страница грузится, список статей пустой или с ошибкой, внизу всегда `Backend: app2`.
- `.../9090/targets` -- `backend` для `app1` красный, строка `app2` тоже краснеет (проб `/api/health` -> 500).
- `.../9090/alerts` -- два `BackendDown` (app1 и app2), `FIRING`.
- Alertmanager -- две записи; письмо `[FIRING:2] BackendDown`.
- Kibana `service: backend` -- поток от `app1` прекращается; `service: nginx` `status:500` -- всплеск.

## Восстановить

Легкий путь (данные сохраняются), узлы просто перезапускаются:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app1
```

`changed=2` (postgresql + cms-backend). Primary поднимается с той же БД, реплика на `app2` сама доганяет WAL.

Полный путь (машина потеряна). Snapshot `base-vm-up` у `app1` -- это состояние без БД. Восстановление primary из snapshot -- это новый пустой кластер, значит реплику на `app2` тоже надо пересоздавать (timeline больше не совпадет). Стриминг-репликация -- не резервная копия, автоматического failover нет, поэтому статьи, созданные до отката, теряются:

```powershell
vagrant snapshot restore app1 base-vm-up --no-provision
vagrant snapshot restore app2 base-vm-up --no-provision
```

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app1,app2
```

Роль `postgres` видит отсутствие `PG_VERSION` -> `initdb` на primary, создает `cms`/`cms`/`replicator`/таблицу `articles`. На `app2` нет `standby.signal` -> свежий `pg_basebackup` с нового primary.

## Проверить

```bash
for h in 11 12; do curl -s http://192.168.57.$h:8000/api/health; echo; done
#   {"backend":"app1","database":"ok","status":"ok"}
#   {"backend":"app2","database":"ok","status":"ok"}
curl -ks -o /dev/null -w '%{http_code}\n' https://192.168.57.10/api/articles     # 200
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml                     # failed=0
```

Оба `BackendDown` -> `Inactive`, `pg_stat_replication.state = streaming` на primary, письмо `[RESOLVED]`.

---

# 3. app2 -- backend #2 + PostgreSQL replica

`app2` не держит primary-БД, поэтому его падение CMS не ломает -- убирает только второй backend и реплику.

## Сломать

```bash
$A2 'sudo systemctl stop cms-backend postgresql'      # или: vagrant halt app2
```

## Наблюдать

```bash
curl -ks -o /dev/null -w 'frontend=%{http_code}\n' https://192.168.57.10/            # 200
curl -ks -o /dev/null -w 'articles=%{http_code}\n' https://192.168.57.10/api/articles # 200 -- CMS работает
curl -ks https://192.168.57.10/api/health                                            # {"backend":"app1","database":"ok",...}
for i in $(seq 1 6); do curl -ks https://192.168.57.10/api/whoami; echo; done         # только app1

$A1 "sudo -u postgres psql -tAc 'SELECT count(*) FROM pg_stat_replication'"           # 0 -- реплика отвалилась

sleep 75
curl -s http://192.168.57.13:9090/api/v1/alerts \
  | python3 -c "import sys,json;[print(a['labels']['alertname'],a['labels'].get('instance'),a['state']) for a in json.load(sys.stdin)['data']['alerts']]"
#   BackendDown  http://app2:8000/api/health  firing        <- только app2
#   (при vagrant halt app2 -- еще InstanceDown app2:9100)
```

Руками:

- браузер `https://192.168.57.10` работает полностью, внизу всегда `Backend: app1`.
- `.../9090/targets` -- красная только строка `backend` / `node` для `app2`.
- `.../9090/alerts` -- один `BackendDown` (app2), `FIRING`; показать, что `CmsDown` при этом не сработал.
- Alertmanager -- одна запись; письмо `[FIRING:1] BackendDown` c `instance=app2`.
- Kibana `service: backend` -- пропадает поток только от `app2`.

## Восстановить

Легкий путь:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app2
```

`changed=2`. `standby.signal` на месте -> `pg_basebackup` не повторяется, реплика переподключается, `state` снова `streaming`.

Полный путь (без потери данных, primary цел):

```powershell
vagrant snapshot restore app2 base-vm-up --no-provision
#   либо физически:  vagrant destroy -f app2 ; vagrant up app2 ; vagrant snapshot save app2 base-vm-up
```

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app2
```

Нет `PG_VERSION` и `standby.signal` -> свежий `pg_basebackup` с `app1`. Реплика доганяет все данные, включая записанные во время простоя.

## Проверить

```bash
$A1 "sudo -u postgres psql -tAc \"SELECT client_addr,state FROM pg_stat_replication\""   # 192.168.57.12|streaming
$A2 "sudo -u postgres psql -tAc 'SELECT pg_is_in_recovery()'"                             # t
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml                              # failed=0
```

`BackendDown` -> `Inactive`, `/api/whoami` снова чередует app1/app2.

---

# 4. elk -- Prometheus, Alertmanager, Grafana, Elasticsearch, Kibana, Logstash

`elk` не обслуживает запросы -- CMS от его падения не страдает. Особенность: вместе с `elk` падает вся система наблюдения, поэтому увидеть поломку в Prometheus/Alertmanager нельзя, их нет.

## Сломать

```bash
$E 'sudo systemctl stop prometheus alertmanager grafana-server kibana logstash elasticsearch blackbox_exporter'
#   или: vagrant halt elk
```

## Наблюдать

```bash
curl -ks -o /dev/null -w 'frontend=%{http_code} ' https://192.168.57.10/
curl -ks -o /dev/null -w 'articles=%{http_code}\n' https://192.168.57.10/api/articles
#   frontend=200 articles=200 -- CMS полностью работает

for p in 9090 9093 3000 5601 9200; do
  echo -n ":$p "; curl -s -m 4 -o /dev/null -w '%{http_code}\n' http://192.168.57.13:$p/ || echo unreachable
done
#   все 000 / connection refused -- мониторинг и логирование недоступны целиком

$W 'sudo journalctl -u filebeat --no-pager -n 2'
#   Filebeat жив, но не отдает в Logstash (:5044) -- копит события локально
```

Руками:

- браузеры на `:9090`, `:9093`, `:3000`, `:5601` -- "соединение отклонено".
- демонстрируемый эффект: компонент упал, но об этом некому сообщить -- ни алерта, ни письма, ни графика.
- `cms-nginx-*` / `cms-backend-*` в ES недоступны и не растут -- разрыв в логировании.

## Восстановить

```bash
# машина целиком:
#   PowerShell> vagrant snapshot restore elk base-vm-up --no-provision   (полная переустановка ELK, ~15-20 мин, ~1 ГБ загрузки)
#   WSL>        ./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit elk
```

При легком варианте (`systemctl stop`) пакеты на месте, роли только заново включают сервисы. `wait_for` в роли `elk` держит playbook, пока Logstash (5044) и Kibana (5601) не начнут слушать (Kibana и ES прогреваются ~5-7 мин).

## Проверить

```bash
for p in 9090 9093 9200; do curl -s -o /dev/null -w ":$p %{http_code}\n" http://192.168.57.13:$p/; done
#   :9090 302   :9093 200   :9200 200
curl -s 'http://192.168.57.13:9090/api/v1/targets?state=active' \
  | python3 -c "import sys,json;d=json.load(sys.stdin)['data']['activeTargets'];print('targets up:',sum(t['health']=='up' for t in d),'/',len(d))"
#   targets up: 7 / 7
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml          # failed=0
```

Grafana `:3000` отвечает `200` через ~1-2 мин после старта. В Kibana снова открыть data view `cms-*` -- документы `cms-nginx-*` / `cms-backend-*` снова прибавляются.

---

# 4b. Backup -- потеря данных и восстановление из дампа

Роль `backup` на app1: `cms-backup.timer` (ежедневно) -> `pg_dump cms` + gzip -> `/var/backups/cms`, ротация 7 дней.

## Сломать (случайное удаление данных)

```bash
$A1 'sudo systemctl start cms-backup.service'                        # свежий дамп
$A1 "sudo -u postgres psql -d cms -c 'DELETE FROM articles;'"        # все статьи пропали
curl -ks https://192.168.57.10/api/articles                         # []
$A2 "sudo -u postgres psql -tAd cms -c 'SELECT count(*) FROM articles'"   # 0 -- реплика повторила DELETE
```

Репликация не спасает: она честно проиграла `DELETE` и на реплике.

## Восстановить

```bash
last=$($A1 "sudo bash -c 'ls -t /var/backups/cms/cms-*.sql.gz | head -1'")
$A1 "sudo -u postgres bash -c 'zcat $last | psql -q cms'"
```

Дамп снят с `--clean --if-exists`, поэтому накатывается на непустую БД без ошибок.

## Проверить

```bash
curl -ks https://192.168.57.10/api/articles | python3 -c 'import sys,json;print(len(json.load(sys.stdin)),"статей")'
$A2 "sudo -u postgres psql -tAd cms -c 'SELECT count(*) FROM articles'"   # столько же -- реплика догнала
```

---

# 5. PostgreSQL replication -- ручная проверка

```bash
curl -ks -X POST -H 'Content-Type: application/json' \
  -d '{"title":"repl","body":"check"}' https://192.168.57.10/api/articles

$A1 "sudo -u postgres psql -d cms -c 'SELECT id,title FROM articles ORDER BY id DESC LIMIT 5;'"
$A2 "sudo -u postgres psql -d cms -c 'SELECT id,title FROM articles ORDER BY id DESC LIMIT 5;'"   # те же строки

$A1 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"   # f
$A2 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"   # t
$A1 "sudo -u postgres psql -c 'SELECT client_addr,state FROM pg_stat_replication;'"   # 192.168.57.12 | streaming
```

Automatic promotion не выполняется -- намеренно.

---

# 6. Идемпотентность

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/hosts.ini playbooks/site.yml   # второй раз
```

Второй прогон: `changed=0 failed=0` на всех четырех хостах. Нет повторного `initdb` / `pg_basebackup`, дублирования строк в `/etc/hosts` и `dnf.conf`, регенерации TLS, перезапуска ELK, повторного скачивания node_exporter/prometheus/alertmanager/blackbox.

---

# Про snapshot

У всех 4 машин есть snapshot `base-vm-up` -- состояние после `vagrant up` (сеть настроена, Ansible еще не запускался). `vagrant snapshot restore <vm> base-vm-up --no-provision` заменяет `vagrant destroy` + `vagrant up` для любой машины. Нюансы:

- web, elk -- пользовательских данных нет, откат эквивалентен пересозданию; для `elk` дальше идет полная переустановка ELK (долго).
- app2 -- реплику все равно пересобирает `pg_basebackup` с целого primary, данные не теряются.
- app1 -- откат стирает primary-БД. Нужно откатывать `app1` и `app2` вместе и мириться с потерей статей, созданных до отката (репликация != бэкап, failover нет). Для демо без потери данных используйте легкий путь: `systemctl stop` -> `ansible-playbook --limit app1`.

После физического `vagrant destroy` snapshot исчезает. Если нужен снова -- пересоздайте сразу после `vagrant up`, до Ansible: `vagrant snapshot save <vm> base-vm-up`.
