# HA CMS lab

Учебная CMS. 4 VM AlmaLinux 9. Vagrant + Ansible.

**Тема для сертификата:** «Создание отказоустойчивой инфраструктуры веб-приложения на Linux с балансировкой нагрузки, репликацией PostgreSQL и мониторингом».

[Слайды и текст рассказчика](docs/presentation.md) · [Демонстрация](docs/demo.md) · [План записи](docs/shot-plot.md)

## Суть

- Статьи: создать, прочитать, удалить. Без редактирования и авторизации.
- Nginx → два Flask backend → общая PostgreSQL primary.
- Реплика БД, ежедневные дампы, метрики, логи, алерты.
- Отказ одного backend переживаем. Отказ primary — нет. Автоматического failover БД нет.

## Архитектура

| VM | IP | Сервисы |
| --- | --- | --- |
| web | 192.168.57.10 | Nginx, frontend, TLS, балансировка |
| app1 | 192.168.57.11 | Flask, PostgreSQL primary, backup |
| app2 | 192.168.57.12 | Flask, PostgreSQL standby |
| elk | 192.168.57.13 | ELK, Prometheus, blackbox, Grafana, Alertmanager, Postfix |

```text
Браузер -> web:443 -> app1:8000 / app2:8000 -> app1:5432 primary
                                                        | WAL, async
                                                        v
                                                  app2:5432 standby

web/app1/app2 -> Filebeat -> Logstash -> Elasticsearch -> Kibana
все VM -> node_exporter -> Prometheus -> Grafana / Alertmanager -> почта
web HTTPS + backend health -> blackbox -> Prometheus
app1 -> pg_dump + gzip -> /var/backups/cms
```

Оба backend читают и пишут в app1. Реплика app2 приложением не используется.

## Код

| Путь | Назначение |
| --- | --- |
| `Vagrantfile` | VM, сеть, ресурсы, localhost-пробросы |
| `group_vars/all.yml` | Адреса, версии, пароли, backup, почта |
| `playbooks/site.yml`, `roles/` | Настройка сервисов; только `ansible.builtin` |
| `app/frontend/` | web: `/usr/share/nginx/html/` |
| `app/backend/` | app1/app2: `/opt/cms-backend/`, `cms-backend.service` |
| `roles/web/templates/cms.conf.j2` | Балансировка и HTTPS |
| `roles/postgres/`, `roles/backup/` | Репликация и дампы |
| `roles/monitoring/`, `roles/elk/`, `roles/filebeat/` | Метрики, алерты, логи |
| `docs/*.json` | Автоматическая настройка Grafana dashboard и Kibana Data View |

## Запуск

Нужны Windows, VirtualBox, Vagrant, Windows OpenSSH, WSL с Ansible, доступ к репозиториям. Box: `almalinux/9`.

PowerShell:

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

Inventory использует Windows SSH через localhost. Прямой доступ WSL к сети VM не требуется. Раздельный деплой: `app1` → `app2` → `web` → `elk`.

## Доступ из Windows

| Сервис | URL |
| --- | --- |
| CMS | https://localhost:5777 |
| HTTP → HTTPS | http://localhost:5666 |
| Grafana | http://localhost:3000/d/cms-overview/cms-infrastructure-overview |
| Prometheus | http://localhost:9090 |
| Alertmanager | http://localhost:9093 |
| Kibana | http://localhost:5601 |
| Elasticsearch | http://localhost:9200 |

Grafana: анонимный Viewer; администратор `admin` / `admin`. TLS самоподписанный, без localhost в SAN; для curl — `-k`.

Общая private network, без отдельной DMZ. Пробросы — только `127.0.0.1`. firewalld открывает порты без source/interface ACL. Elastic security выключена; пароли учебные; backend — Flask development server. Стенд для локальной лаборатории.

## API

| Метод и путь | Результат |
| --- | --- |
| `GET /api/articles` | Список статей |
| `POST /api/articles` | Создание: JSON `title`, `body` |
| `DELETE /api/articles/<id>` | Удаление |
| `GET /api/health` | Проверка БД через `SELECT 1` |
| `GET /api/whoami` | Имя backend, без обращения к БД |
| `GET /api/demo-error` | HTTP 500 для логов |

## Отказы

| Что отказало | Последствие | Алерт при живом elk |
| --- | --- | --- |
| Flask app1 | CMS работает через app2 | `BackendDown` app1 |
| VM app2 | CMS работает через app1, реплики нет | `BackendDown`, `InstanceDown` app2 |
| Primary / VM app1 | Статьи недоступны; статика может работать | `BackendDown` обоих; при отказе VM — `InstanceDown` app1 |
| Оба backend | Статика работает, API нет | `BackendDown` обоих |
| Nginx / VM web | CMS недоступна | `CmsDown`; при отказе VM — `InstanceDown` web |
| VM elk | CMS работает, наблюдаемости нет | Отправить алерт некому |

Nginx: round-robin, `max_fails=2`, `fail_timeout=5s`, до двух попыток, connect timeout 2s. Retry: ошибки соединения, таймауты, 502/503/504; не 500. Успех каждого запроса при отказе не гарантируется.

systemd перезапускает аварийно завершившийся backend через 3s. После явного `stop` нужен запуск.

Демо, PowerShell:

```powershell
vagrant ssh app1 -c "sudo systemctl stop cms-backend"
1..8 | ForEach-Object { curl.exe -ksS https://localhost:5777/api/whoami }
curl.exe -ksS https://localhost:5777/api/articles
```

Восстановление, WSL:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --limit app1
ansible-playbook -i inventory/hosts.ini playbooks/verify.yml
```

VM выключена — сначала `vagrant up <vm>` в PowerShell. VM пересоздана — обновить inventory.

## Мониторинг и логи

- Prometheus: сбор каждые 15s; 4 node target, 2 backend health, 1 HTTPS frontend.
- `BackendDown`: health не проходит 30s. `CmsDown`: главная страница не проходит 30s.
- `InstanceDown`: node_exporter недоступен 1m. `HighDiskUsage`: диск занят >85% в течение 5m.
- `CmsDown` не проверяет статьи. Blackbox `up` не заменяет `probe_success`.
- Письма: Alertmanager → локальный Postfix → root на elk; есть resolved. Доставка позже выдержки правила.
- Логи: Nginx access → grok, backend → JSON; индексы `cms-nginx-*`, `cms-backend-*`.
- Kibana: Data View `cms-logs`; фильтр `status >= 500`.
- При простое elk метрики теряются; досылка логов зависит от сохранности файлов.

```powershell
vagrant ssh elk -c "sudo cat /var/spool/mail/root"
```

## БД и backup

- Replica: `pg_basebackup -R -X stream`, затем асинхронный WAL. Promotion не автоматизирован.
- Долгий простой replica: возможна ручная пересборка из-за утраты нужных WAL.
- Backup на app1: ежедневный `pg_dump --clean --if-exists` + gzip, `cms-backup.timer`.
- Каталог: `/var/backups/cms`; очистка `find -mtime +7`. Первый дамп — при отсутствии копий.
- Дампы на диске primary. Утрата диска угрожает и БД, и backup. Реплика не заменяет backup.

```powershell
vagrant ssh app1 -c "sudo systemctl start cms-backup.service"
vagrant ssh app1 -c "sudo ls -lh /var/backups/cms/"
```

Restore внутри app1: остановить запись приложения, подставить имя дампа. Таблицы заменяются.

```bash
sudo -u postgres bash -o pipefail -c 'zcat /var/backups/cms/cms-YYYYmmdd-HHMMSS.sql.gz | psql -v ON_ERROR_STOP=1 -q cms'
```

## Проверки и границы

`verify.yml`: HTTPS, health, балансировка, создание/чтение статьи, 500, метрики/правила, панели, логи, репликация, backup timer и непустой дамп. Итог: `failed=0`, `unreachable=0` на web/app1/app2.

DELETE, restore и отказы автоматически не проверяются. Тестовая статья остаётся в БД.

Повторный Ansible восстанавливает сервисы; `changed=0` не гарантируется. Данные автоматически не возвращает.

Snapshots создаются отдельно; список — `vagrant snapshot list`. Откат чистого app1 удаляет текущую БД и локальные дампы, требует согласованной пересборки replica. Единственные web, primary, elk и физический хост остаются точками отказа.
