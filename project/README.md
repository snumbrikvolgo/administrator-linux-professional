# HA CMS lab

Отказоустойчивый CMS-сервис на 4 VM. Vagrant поднимает машины, Ansible настраивает все. Повторный запуск playbook ничего не ломает.

## Что это

Маленькая CMS: создать статью, показать список, удалить. Frontend -- чистый HTML/CSS/JS. Backend -- Flask. Данные -- PostgreSQL с репликой. Пользователь ходит только на `web`, остальное закрыто.

Цель стенда -- показать отказоустойчивость: убить компонент или целую VM, восстановить одним Ansible, получить исходное рабочее состояние.

## Архитектура

| VM | IP | Роль |
| --- | --- | --- |
| `web` | 192.168.57.10 | Nginx: frontend, TLS, reverse proxy, балансировка |
| `app1` | 192.168.57.11 | Flask backend #1, PostgreSQL primary |
| `app2` | 192.168.57.12 | Flask backend #2, PostgreSQL streaming replica |
| `elk` | 192.168.57.13 | Elasticsearch, Logstash, Kibana, Prometheus, Grafana, Alertmanager |

```text
client -> web:443 (nginx) -> app1:8000 / app2:8000 (round-robin, proxy_next_upstream)
                                   |
                          оба backend пишут в
                                   v
                        PostgreSQL primary (app1) --streaming--> replica (app2)

web, app1, app2  --filebeat--> elk:5044 (logstash, grok/json) -> elasticsearch -> kibana
elk: prometheus <- node_exporter (все 4 VM), blackbox (app1/app2 health, https web)
     prometheus -> alertmanager -> локальная почта на elk
app1: cms-backup.timer -> pg_dump + gzip -> /var/backups/cms (ротация 7 дней)
```

HTTP на `web` редиректит на HTTPS. Backend, PostgreSQL и порты мониторинга наружу не смотрят.

## Соответствие требованиям

| Требование | Как закрыто |
| --- | --- |
| HTTPS включен | nginx слушает 80 и 443, 80 редиректит на 443, self-signed сертификат с SAN |
| Инфраструктура в DMZ | `web` -- единственный узел с внешним доступом; backend, БД, мониторинг -- только во внутренней сети `192.168.57.0/24` |
| Файрвол на входе | firewalld на `web` пускает снаружи только `http` и `https`; остальные порты -- по внутренней сети |
| Метрики и алертинг | Prometheus + node_exporter + blackbox, Alertmanager с правилами `InstanceDown`/`BackendDown`/`CmsDown`/`HighDiskUsage`, уведомления письмом |
| Централизованный сбор логов | Filebeat -> Logstash (парсинг) -> Elasticsearch -> Kibana; индексы `cms-nginx-*`, `cms-backend-*` |
| Backup | `cms-backup.timer` на app1: ежедневный `pg_dump` + gzip в `/var/backups/cms`, ротация 7 дней; восстановление `zcat ... | psql` |

## Что реализовано

- 4 VM из одного `Vagrantfile` (конфиг в одном Ruby-хэше, цикл).
- Inventory генерируется из ключей Vagrant скриптом `scripts/generate_inventory.sh`.
- Вся настройка -- Ansible, только `ansible.builtin` (внешних коллекций нет).
- Nginx: self-signed TLS с SAN (`web`, `cms.local`, `192.168.57.10`), round-robin, отказ backend через `proxy_next_upstream`.
- Flask CRUD: `GET/POST/DELETE /api/articles`, `GET /api/health` (проверяет БД), `GET /api/whoami` (какой backend), `GET /api/demo-error` (всегда 500, для демо ELK).
- Backend под systemd (`cms-backend.service`), логи в JSON.
- PostgreSQL: primary на app1, streaming replica на app2 через `pg_basebackup`. Отдельный пользователь репликации. Идемпотентно: если `PG_VERSION` + `standby.signal` на месте -- реплика не пересоздается.
- ELK 8.19.20 (версия зафиксирована), single-node, security выключен. Heap ограничен: ES 1536m, Logstash 512m. `vm.max_map_count=262144`.
- Logstash парсит nginx access log в поля `client_ip`, `method`, `request`, `status`, `bytes`, `user_agent`; backend-логи разбирает как JSON. Индексы `cms-nginx-*`, `cms-backend-*`.
- Filebeat на web/app1/app2 шлет логи в Logstash.
- Prometheus: node_exporter на всех VM, blackbox для `app1/app2 /api/health` и `https://web`. Правила `InstanceDown`, `BackendDown` (отдельно app1 и app2), `CmsDown`, `HighDiskUsage`.
- Alertmanager шлет письма на локальный ящик `root@localhost` на elk (loopback-only Postfix, без внешнего SMTP и секретов).
- Grafana: datasource Prometheus через provisioning.
- Backup: `cms-backup.timer` на app1 -- ежедневный `pg_dump` + gzip в `/var/backups/cms`, ротация 7 дней, один дамп сразу при деплое.
- firewalld: наружу только `web:80` и `web:443`; backend, PostgreSQL, репликация, node_exporter, beats -- по внутренней сети.
- Тесты в Ansible: `playbooks/verify.yml` (проверка), `playbooks/generate_logs.yml` (трафик для ELK).
- У каждой VM snapshot `base-vm-up` -- состояние до Ansible.

## Как устроено (роли)

| Роль | Хост | Что делает |
| --- | --- | --- |
| `base` | все | swap-файл (иначе dnf ловит OOM на 768 MB), tuning sshd под Ansible, `/etc/hosts`, chrony, firewalld |
| `monitoring_agent` | все | node_exporter под systemd |
| `postgres` | app1, app2 | primary: initdb + конфиг + пользователи + таблица; replica: `pg_basebackup` при первом запуске |
| `backup` | app1 | `pg_dump` + gzip по systemd-таймеру, ротация 7 дней, первый дамп сразу |
| `backend` | app1, app2 | Flask + venv-пакеты, `cms-backend.service`, logrotate |
| `web` | web | Nginx, self-signed TLS, frontend, конфиг балансировки |
| `filebeat` | web, app1, app2 | Filebeat -> `elk:5044` |
| `elk` | elk | Elastic repo, ES + Logstash + Kibana, heap, sysctl, `wait_for` до готовности портов |
| `monitoring` | elk | Prometheus, blackbox, Alertmanager, Grafana, Postfix, правила и datasource |

## Требования

- Windows, VirtualBox, Vagrant.
- WSL с Ansible (только `ansible.builtin`).
- Локальный box AlmaLinux 9: `file:///C:/Users/zazhigina/Downloads/alma-9`.

## Развертывание

Windows PowerShell:

```powershell
cd C:\Users\dandy\administrator-linux-professional\project
vagrant up
```

WSL:

```bash
cd /mnt/c/Users/dandy/administrator-linux-professional/project
export PATH="$HOME/.local/bin:$PATH"
export ANSIBLE_CONFIG=./ansible.cfg
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

Inventory и `ANSIBLE_CONFIG` задаются явно: Ansible игнорирует `ansible.cfg` в world-writable каталоге на `/mnt/c`. Критичные SSH-опции продублированы в `inventory/hosts.ini`, так что playbook работает и без `ansible.cfg`.

Развертывание по одному хосту выполняется в порядке зависимостей `app1` -> `app2` -> `web` -> `elk`:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app1
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app2
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit web
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit elk
```

`app1` должен быть развернут раньше `app2`, потому что replica получает первоначальную копию PostgreSQL с primary. После раздельных запусков выполняются общая проверка и генерация тестовых логов:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

## Доступ к сервисам

Из браузера Windows используются только проброшенные localhost-адреса:

- **CMS HTTP** -- `http://localhost:5666` (перенаправляет на HTTPS).
- **CMS HTTPS** -- `https://localhost:5777`. Сертификат self-signed, поэтому браузер покажет предупреждение.
- **Prometheus** -- `http://localhost:9090`; цели: `http://localhost:9090/targets`, алерты: `http://localhost:9090/alerts`.
- **Alertmanager** -- `http://localhost:9093`.
- **Grafana** -- `http://localhost:3000`, логин `admin` / `admin`.
- **Kibana** -- `http://localhost:5601`.
- **Elasticsearch** -- `http://localhost:9200`.

Адреса `192.168.57.10–13` являются внутренними адресами VM. Они используются сервисами между собой, но для просмотра из Windows не нужны.

## Проверка

```bash
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

Падает на первом нарушенном свойстве. Проверяет: HTTPS 200 и redirect, health обоих backend, балансировку `/api/whoami`, CRUD статьи, `/api/demo-error` -> 500, Prometheus (>=7 targets up, 4 правила загружены), Grafana, Alertmanager, Elasticsearch (>= yellow), Kibana (available), Logstash (порт 5044), непустые `cms-nginx-*` и `cms-backend-*`, распарсенный документ `status:500`, репликацию (primary `f` + `streaming`, replica `t`, строка из теста доехала).

Норма -- `failed=0` на `localhost`, `app1`, `app2`.

## Отказоустойчивость

Сломать компонент, посмотреть на ошибки, восстановить Ansible.

```bash
A1='ssh -i ~/.ansible/keys/app1 vagrant@192.168.57.11'
```

| Сломать | Что происходит | Восстановить |
| --- | --- | --- |
| `$A1 'sudo systemctl stop cms-backend'` | `/api/whoami` -> только app2, CMS жива. `BackendDown` firing для app1 (не для app2). Письмо на elk. | `ansible-playbook ... --limit app1` |
| `vagrant halt app1` | + `InstanceDown app1`. Оба backend теряют primary-БД -> `/api/health` -> 500 -> `BackendDown` для app1 и app2. | `vagrant up app1` + `--limit app1` |
| `vagrant halt app2` | CMS полностью работает через app1. `BackendDown app2` + `InstanceDown app2`. Репликация оборвана. | `vagrant up app2` + `--limit app2` |
| `vagrant halt web` | CMS недоступна целиком. `CmsDown` + `InstanceDown web`. | `vagrant up web` + `--limit web` |
| `vagrant halt elk` | CMS не задета. Prometheus/Grafana/Kibana/ES недоступны -- поломку некому показать. Filebeat копит логи локально. | `vagrant up elk` + `--limit elk` |

Смотреть ошибки: `curl.exe -k https://localhost:5777`, `http://localhost:9090/alerts`, `http://localhost:9090/targets`, письма `sudo mail` на elk, nginx `cms_error.log` на web, Kibana Discover на `http://localhost:5601`.

После восстановления: `verify.yml` -> `failed=0`, алерты снова `Inactive`, приходит письмо `[RESOLVED]`.

Главный сценарий воспроизводимости -- полное пересоздание:

```bash
# PowerShell: vagrant destroy -f app2 ; vagrant up app2 ; vagrant snapshot save app2 base-vm-up
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app2
```

app2 возвращается как backend + replica (`pg_basebackup` заново) + node_exporter + filebeat, без ручной настройки внутри VM.

## PostgreSQL replication

Ручная проверка: создать статью, сравнить данные на обеих нодах, посмотреть роли.

```bash
A1='ssh -i ~/.ansible/keys/app1 vagrant@192.168.57.11'
A2='ssh -i ~/.ansible/keys/app2 vagrant@192.168.57.12'

curl -ks -X POST -H 'Content-Type: application/json' \
  -d '{"title":"repl","body":"check"}' https://192.168.57.10/api/articles

$A1 "sudo -u postgres psql -d cms -c 'SELECT id,title FROM articles ORDER BY id DESC LIMIT 5;'"
$A2 "sudo -u postgres psql -d cms -c 'SELECT id,title FROM articles ORDER BY id DESC LIMIT 5;'"   # те же строки
$A1 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"   # f  (primary)
$A2 "sudo -u postgres psql -c 'SELECT pg_is_in_recovery();'"   # t  (replica, read-only)
$A1 "sudo -u postgres psql -c 'SELECT client_addr,state FROM pg_stat_replication;'"   # 192.168.57.12 | streaming
```

Automatic failover намеренно не сделан.

## Backup

Роль `backup` на app1 ставит `cms-backup.timer` (ежедневно) и скрипт `/usr/local/bin/cms-backup.sh`: `pg_dump cms` -> gzip -> `/var/backups/cms/cms-YYYYmmdd-HHMMSS.sql.gz`, дампы старше 7 дней удаляются. При деплое сразу делается первый дамп.

Снять дамп вручную и восстановить БД:

```bash
A1='ssh -i ~/.ansible/keys/app1 vagrant@192.168.57.11'
$A1 'sudo systemctl start cms-backup.service'                              # разовый дамп
$A1 'sudo ls -la /var/backups/cms/'                                       # список
last=$($A1 "sudo bash -c 'ls -t /var/backups/cms/cms-*.sql.gz | head -1'")
$A1 "sudo -u postgres bash -c 'zcat $last | psql -q cms'"                  # восстановление
```

Дамп снят с `pg_dump --clean --if-exists`, накатывается на непустую БД без ошибок. Восстанавливается на primary; репликация сама доносит данные до app2.

## ELK и парсинг логов

```bash
ansible-playbook -i inventory/hosts.ini playbooks/generate_logs.yml
```

Kibana `http://192.168.57.13:5601` -> Stack Management -> Data Views -> Create: pattern `cms-*`, time field `@timestamp`.

Discover:

- `service: nginx` -- логи nginx (индекс `cms-nginx-*`).
- Колонки `method`, `request`, `status`, `client_ip`, `bytes` -- строка лога разобрана на поля, не лежит в `message`.
- Запрос `status >= 500` -- находит `/api/demo-error`. `status: 404` -- находит `/nonexistent`.
- `service: backend` -- логи backend (`cms-backend-*`), JSON-поля `level`, `backend`, `message`.

## Уведомления (локальная почта)

Alertmanager шлет письма через loopback-only Postfix на elk. Внешнего SMTP и секретов нет. Включено по умолчанию (`alert_email_enabled: true`).

Читать на elk:

```bash
ssh -i ~/.ansible/keys/elk vagrant@192.168.57.13
sudo mail            # список писем
sudo cat /var/spool/mail/root
```

Проверка: остановить `cms-backend` на app1 -> через ~1 мин письмо `[FIRING:1] BackendDown` -> вернуть сервис -> письмо `[RESOLVED]`.

Адрес меняется в `group_vars/all.yml` (`alert_email_to`).

## HTTPS

По умолчанию self-signed сертификат с SAN `web`, `cms.local`, `192.168.57.10`. Повторный playbook его не перегенерирует (`creates:`).

Для публичного домена: `letsencrypt_enabled: true` + `cms_domain` + `letsencrypt_email` -- тогда Certbot.

## Восстановление машины из snapshot

У всех 4 VM есть snapshot `base-vm-up` -- после `vagrant up` (сеть настроена), до Ansible.

```powershell
vagrant snapshot restore <vm> base-vm-up --no-provision
```

```bash
./scripts/generate_inventory.sh
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit <vm>
```

Нюанс: откат `app1` стирает primary-БД, тогда надо откатывать `app1` и `app2` вместе (реплику пересобирать), данные до отката теряются -- репликация это не бэкап. Для демо без потери данных на app1 используйте `systemctl stop` + `--limit app1`.

## Идемпотентность

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml   # второй раз
```

`changed=0 failed=0` на всех хостах. Нет повторного initdb / `pg_basebackup`, дублирования строк в конфигах, регенерации TLS, перезапуска ELK, повторного скачивания exporter-ов.
