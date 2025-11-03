# Настройка логирования с Loki и Promtail

Конфигурация централизованного сбора логов для инфраструктуры мониторинга.

## Компоненты

| Компонент | Версия | Порт | Назначение |
|-----------|--------|------|------------|
| Loki | 3.5.7 | 3100 | Хранение и индексация логов |
| Promtail | 3.5.7 | 9080 | Агент сбора логов |
| Grafana | 12.2.0 | 3200 | Визуализация и поиск |

---

## Извлеченные labels при парсинге

### HAProxy

| Label | Описание | Пример |
|-------|----------|--------|
| client_ip | IP клиента | 194.84.231.43 |
| frontend | Frontend name | https_front |
| backend | Backend name | trojan_backend |
| server | Server name | xray |
| tt | Total time (ms) | 50295 |

### Xray

| Label | Описание | Пример |
|-------|----------|--------|
| source_ip | IP источника | 172.22.0.2 |
| action | Действие | accepted/rejected |
| protocol | Протокол | tcp |
| email | Email пользователя | user@api-core.online |

### Nginx

| Label | Описание | Пример |
|-------|----------|--------|
| remote_addr | IP клиента | 172.22.0.3 |
| status | HTTP статус | 400 |

---

## Полная конфигурация Promtail

Файл `~/monitoring-stack/promtail/config/promtail-config.yml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Системные логи
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: learning-host
          __path__: /var/log/*.log

  # Логи Docker контейнеров с парсингом
  - job_name: containers
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container'
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_project']
        target_label: 'compose_project'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: 'compose_service'
    pipeline_stages:
      - docker: {}
      
      # HAProxy парсинг
      - match:
          selector: '{container="haproxy"}'
          stages:
            - regex:
                expression: '^(?P<client_ip>[\d\.]+):(?P<client_port>\d+) \[(?P<timestamp>[^\]]+)\] (?P<frontend>\S+) (?P<backend>\S+)/(?P<server>\S+) (?P<tq>-?\d+)/(?P<tw>-?\d+)/(?P<tt>-?\d+) (?P<bytes>\d+)'
            - labels:
                frontend:
                backend:
                server:
      
      # Xray парсинг
      - match:
          selector: '{container="xray"}'
          stages:
            - regex:
                expression: 'from (?P<source_ip>[\d\.]+):(?P<source_port>\d+) (?P<action>\w+) (?P<protocol>\w+):(?P<destination>[^\s]+).* email: (?P<email>[^\s]+)'
            - labels:
                action:
                protocol:
                email:
      
      # Nginx парсинг
      - match:
          selector: '{container="bot-webapp-nginx"}'
          stages:
            - regex:
                expression: '^(?P<remote_addr>[\d\.]+) - - \[(?P<time_local>[^\]]+)\] "(?P<request>[^"]*)" (?P<status>\d+) (?P<body_bytes_sent>\d+)'
            - labels:
                status:
                remote_addr:
      
      - static_labels:
          job: docker

  # Security логи (journald)
  - job_name: security
    journal:
      json: false
      max_age: 12h
      path: /var/log/journal
      labels:
        job: security
        host: learning-host
    pipeline_stages:
      - match:
          selector: '{job="security"}'
          stages:
            - regex:
                expression: '(?P<message>.*)'
            - labels:
                message:
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal_syslog_identifier']
        target_label: 'syslog_identifier'

  # Системные критичные события
  - job_name: system_critical
    static_configs:
      - targets:
          - localhost
        labels:
          job: system_critical
          host: learning-host
          __path__: /var/log/messages
    pipeline_stages:
      - match:
          selector: '{job="system_critical"} |~ "error|fail|critical|alert"'
          stages:
            - regex:
                expression: '(?P<level>error|fail|critical|alert)'
            - labels:
                level:
```

---

## Использование в Grafana Explore

### Подключение

1. Откройте Grafana: `https://<SERVER_IP>:4443/`
2. Левое меню → **Explore** (иконка компаса)
3. Сверху выберите datasource: **Loki**
4. Используйте **Label browser** или вводите запросы вручную

### Базовые запросы

```logql
# Все логи Docker контейнеров
{job="docker"}

# Логи конкретного контейнера
{container="haproxy"}
{container="xray"}

# Фильтрация по тексту
{job="docker"} |= "error"
{job="docker"} |~ "error|fail"
```

---

## Примеры полезных LogQL запросов

### Мониторинг HAProxy

```logql
# Rate запросов по backend
sum by (backend) (rate({container="haproxy"}[5m]))

# Все запросы к trojan backend
{container="haproxy", backend="trojan_backend"}

# Медленные запросы (>10 секунд = 10000ms)
{container="haproxy"} | logfmt | tt > 10000

# Top 10 клиентов по запросам
topk(10, sum by (client_ip) (rate({container="haproxy"}[1h])))

# Средний размер ответа
avg_over_time({container="haproxy"} | logfmt | unwrap bytes [5m])

# 95 перцентиль времени ответа
quantile_over_time(0.95, {container="haproxy"} | logfmt | unwrap tt [5m])
```

### Мониторинг Xray

```logql
# Rate ошибок (rejected)
rate({container="xray", action="rejected"}[5m])

# Rate успешных подключений
rate({container="xray", action="accepted"}[5m])

# Процент ошибок
sum(rate({container="xray", action="rejected"}[5m])) / 
sum(rate({container="xray"}[5m])) * 100

# Top 10 пользователей
topk(10, sum by (email) (rate({container="xray", action="accepted"}[1h])))

# Активность конкретного пользователя
{container="xray", email="user@api-core.online"}

# Все rejected подключения
{container="xray", action="rejected"}
```

### Мониторинг Nginx

```logql
# Распределение HTTP статусов
sum by (status) (rate({container="bot-webapp-nginx"}[5m]))

# Только ошибки 4xx и 5xx
{container="bot-webapp-nginx", status=~"4..|5.."}

# Top 10 IP адресов
topk(10, sum by (remote_addr) (rate({container="bot-webapp-nginx"}[1h])))

# Запросы от конкретного IP
{container="bot-webapp-nginx", remote_addr="172.22.0.3"}

# Rate всех запросов
rate({container="bot-webapp-nginx"}[5m])
```

### Поиск проблем

```logql
# Все ошибки в Docker контейнерах
{job="docker"} |~ "(?i)error|fail|exception|fatal"

# Критичные системные события
{job="system_critical"}

# Security события (SSH, sudo)
{job="security"} |~ "authentication|sudo|ssh"

# Prometheus ошибки
{container="prometheus"} |= "error"

# Grafana проблемы
{container="grafana"} |~ "error|fail"


# Loki ошибки
{container="loki"} |= "error"
```

### Комбинированные запросы

```logql
# HAProxy медленные запросы к Grafana
{container="haproxy", backend="grafana_backend"} | logfmt | tt > 5000

# Xray rejected от конкретного IP
{container="xray", action="rejected"} | source_ip="172.22.0.2"

# Nginx 4xx ошибки с временем
{container="bot-webapp-nginx", status=~"4.."} | time_local != ""

# Количество уникальных клиентов HAProxy
count(count by (client_ip) (rate({container="haproxy"}[1h])))
```

### Метрики и агрегация

```logql
# Общее количество логов за час
count_over_time({job="docker"}[1h])

# Среднее время обработки по backend
avg by (backend) (avg_over_time({container="haproxy"} | logfmt | unwrap tt [5m]))

# Количество запросов за минуту
sum(rate({container="haproxy"}[1m]))

# Bytes per second по backend
sum by (backend) (rate({container="haproxy"} | logfmt | unwrap bytes [5m]))
```

---

## Проверка работы

```bash
# Статус Loki
curl -s http://localhost:3100/ready

# Все labels
curl -s "http://localhost:3100/loki/api/v1/labels"

# Все jobs
curl -s "http://localhost:3100/loki/api/v1/label/job/values"

# Все контейнеры
curl -s "http://localhost:3100/loki/api/v1/label/container/values"

# Логи Promtail
docker logs promtail --tail=20
```

---

## Troubleshooting

### Ошибка "timestamp too old"

**Причина:** Promtail пытается отправить старые логи

**Решение:** Это нормально при первом запуске. Новые логи будут приниматься. Loki retention policy отклоняет логи старше 7 дней.

### Labels не появляются

**Решение:** 
- Labels извлекаются только из новых логов
- Сгенерируйте новый трафик (curl, VPN подключение)
- Проверьте regex в конфиге Promtail

### Нет логов в Grafana

```bash
# Проверка Loki
curl http://localhost:3100/ready

# Проверка Promtail
docker logs promtail --tail=50

# Перезапуск
docker compose restart promtail loki
```

---

## Best Practices

### Label cardinality

- Используйте labels для категоризации (container, backend, status)
- Избегайте высоко-кардинальных значений (full URLs, timestamps, IDs)
- Держите уникальных комбинаций <100k

### Query optimization

Быстро: `{container="haproxy", backend="trojan_backend"}`  
Медленно: `{job="docker"} |~ ".*random.*"`

### Retention

- Текущая конфигурация: 30 дней
- Для production: critical 90+ дней, application 30 дней, debug 7 дней

---

