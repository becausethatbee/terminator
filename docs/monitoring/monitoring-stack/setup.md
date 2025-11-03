# Развертывание стека мониторинга

Полнофункциональная система сбора метрик, логов, алертов с message broker для обработки событий.

## Предварительные требования

- Docker 20.10+
- Docker Compose 2.0+
- OS: Ubuntu 20.04/22.04, Debian 11/12
- RAM: 4GB минимум, 8GB рекомендуется
- Disk: 20GB свободного места
- Доступ: sudo права

---

## Часть 1: Инфраструктура

### Архитектура

```
External Access (HAProxy)
├── :4443 → Grafana, Prometheus, Alertmanager, Loki

Monitoring Network
├── Prometheus (метрики, retention 30d)
├── Grafana (визуализация)
├── Loki (логи, retention 30d)
├── Alertmanager (управление алертами)
├── Node Exporter (метрики хоста)
├── cAdvisor (метрики контейнеров)
├── HAProxy Exporter (метрики HAProxy)
├── Promtail (агент сбора логов)
└── Blackbox Exporter (проверка доступности)
```

### Компоненты

| Сервис | Версия | Назначение | Порт |
|--------|--------|------------|------|
| Prometheus | 3.7.1 | Сбор и хранение метрик | 9090 |
| Grafana | latest | Визуализация, дашборды | 3200 |
| Loki | latest | Хранение логов | 3100 |
| Promtail | 3.5.7 | Агент сбора логов | - |
| Alertmanager | 0.27.0 | Управление алертами | 9093 |
| Alertmanager Bot | 0.4.3 | Уведомления Telegram | 9094 |
| Node Exporter | 1.8.2 | Метрики хоста | 9100 |
| cAdvisor | 0.49.1 | Метрики контейнеров | 9200 |
| Blackbox Exporter | 0.25.0 | Health checks | 9115 |
| HAProxy Exporter | 0.15.0 | Метрики HAProxy | 9101 |

---

## Часть 2: Развертывание

### Структура проекта

```bash
mkdir -p ~/monitoring-stack/{prometheus,grafana,loki,promtail,alertmanager,blackbox-exporter}

cd ~/monitoring-stack

mkdir -p prometheus/{config,data,rules}
mkdir -p grafana/{data,provisioning/{datasources,dashboards,alerting}}
mkdir -p loki/{config,data,wal}
mkdir -p promtail/config
mkdir -p alertmanager/{config,data,telegram-data}
mkdir -p blackbox-exporter/config
mkdir -p data/{prometheus,grafana,loki}
```

Создается организованная структура для конфигураций и данных всех сервисов.

### Создание External Networks

HAProxy Exporter требует доступа к HAProxy через Docker сеть. Создайте external сеть если она еще не существует:

```bash
docker network create haproxy_proxy_network
```

Эта сеть используется для связи между HAProxy Exporter и HAProxy контейнером.

### Docker Compose

Файл `docker-compose.yml`:

```yaml
networks:
  monitoring:
    driver: bridge
  haproxy_proxy_network:
    external: true

services:
  prometheus:
    image: prom/prometheus:v3.7.1
    container_name: prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    volumes:
      - ./prometheus/config:/etc/prometheus
      - ./prometheus/rules:/etc/prometheus/rules
      - ./data/prometheus:/prometheus
    ports:
      - "9090:9090"
    restart: unless-stopped
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:v1.8.2
    container_name: node-exporter
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    container_name: cadvisor
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "9200:8080"
    restart: unless-stopped
    networks:
      - monitoring

  loki:
    image: grafana/loki:3.5.7
    container_name: loki
    command: -config.file=/etc/loki/loki-config.yml
    volumes:
      - ./loki/config:/etc/loki
      - ./data/loki:/loki
    ports:
      - "3100:3100"
    restart: unless-stopped
    networks:
      - monitoring

  promtail:
    image: grafana/promtail:3.5.7
    container_name: promtail
    command: -config.file=/etc/promtail/promtail-config.yml
    volumes:
      - ./promtail/config:/etc/promtail
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:12.2.0
    container_name: grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SERVER_ROOT_URL=http://localhost:3200
      - GF_SERVER_HTTP_PORT=3200
      - GF_INSTALL_PLUGINS=redis-datasource
      - GF_METRICS_ENABLED=true
      - GF_UNIFIED_ALERTING_ENABLED=true
      - GF_ALERTING_ENABLED=false
    volumes:
      - ./data/grafana:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "3200:3200"
    restart: unless-stopped
    networks:
      - monitoring

  alertmanager:
    image: prom/alertmanager:v0.27.0
    container_name: alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    volumes:
      - ./alertmanager/config:/etc/alertmanager
      - ./alertmanager/data:/alertmanager
    ports:
      - "9093:9093"
    restart: unless-stopped
    networks:
      - monitoring

  alertmanager-telegram:
    image: metalmatze/alertmanager-bot:0.4.3
    container_name: alertmanager-telegram
    environment:
      - TELEGRAM_ADMIN=<TELEGRAM_ADMIN_ID>
      - TELEGRAM_TOKEN=<TELEGRAM_BOT_TOKEN>
      - STORE=bolt
      - BOLT_PATH=/data/bot.db
      - LISTEN_ADDR=0.0.0.0:8080
    volumes:
      - ./alertmanager/telegram-data:/data
    ports:
      - "9094:8080"
    restart: unless-stopped
    networks:
      - monitoring

  blackbox-exporter:
    image: prom/blackbox-exporter:v0.25.0
    container_name: blackbox-exporter
    command:
      - '--config.file=/etc/blackbox/blackbox.yml'
    volumes:
      - ./blackbox-exporter/config:/etc/blackbox
    ports:
      - "9115:9115"
    restart: unless-stopped
    networks:
      - monitoring

  haproxy-exporter:
    image: quay.io/prometheus/haproxy-exporter:v0.15.0
    container_name: haproxy-exporter
    command:
      - --haproxy.scrape-uri=http://haproxy:8404/stats;csv
    ports:
      - "9101:9101"
    restart: unless-stopped
    networks:
      - monitoring
      - haproxy_proxy_network
```

Определяет все сервисы мониторинга с volumes для персистентности данных.

---

## Часть 3: Конфигурация Prometheus

### Основная конфигурация

Файл `prometheus/config/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'learning-stack'
    environment: 'dev'

rule_files:
  - '/etc/prometheus/rules/*.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'prometheus'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'learning-host'
          service: 'node-exporter'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          instance: 'docker-host'
          service: 'cadvisor'

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3200']
        labels:
          service: 'grafana'
    metrics_path: '/metrics'

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']
        labels:
          service: 'loki'

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']
        labels:
          service: 'alertmanager'

  - job_name: 'haproxy'
    static_configs:
      - targets: ['haproxy-exporter:9101']
        labels:
          service: 'haproxy'

  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - http://grafana:3200
          - http://prometheus:9090
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

Настраивает сбор метрик со всех targets с интервалом 15 секунд.

### Правила алертов

Файл `prometheus/rules/alerts.yml`:

```yaml
groups:
  - name: host_alerts
    interval: 30s
    rules:
      - alert: HostDown
        expr: up{job="node-exporter"} == 0
        for: 1m
        labels:
          severity: critical
          category: infrastructure
        annotations:
          summary: "Host {{ $labels.instance }} is down"
          description: "Node exporter on {{ $labels.instance }} has been down for more than 1 minute"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
          category: performance
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% (current value: {{ $value | humanize }}%)"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
          category: performance
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% (current value: {{ $value | humanize }}%)"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 5m
        labels:
          severity: warning
          category: storage
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk space is below 15% (current value: {{ $value | humanize }}%)"

      - alert: DiskSpaceCritical
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 5
        for: 1m
        labels:
          severity: critical
          category: storage
        annotations:
          summary: "Critical disk space on {{ $labels.instance }}"
          description: "Disk space is below 5% (current value: {{ $value | humanize }}%)"

  - name: container_alerts
    interval: 30s
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name=~".+"})
        for: 2m
        labels:
          severity: warning
          category: containers
        annotations:
          summary: "Container {{ $labels.name }} is down"
          description: "Container has been down for more than 2 minutes"

      - alert: HighContainerCPU
        expr: sum(rate(container_cpu_usage_seconds_total{name=~".+"}[5m])) by (name) * 100 > 80
        for: 5m
        labels:
          severity: warning
          category: containers
        annotations:
          summary: "High CPU usage in container {{ $labels.name }}"
          description: "Container CPU usage is above 80% (current value: {{ $value | humanize }}%)"

      - alert: HighContainerMemory
        expr: (container_memory_usage_bytes{name=~".+"} / container_spec_memory_limit_bytes{name=~".+"}) * 100 > 85
        for: 5m
        labels:
          severity: warning
          category: containers
        annotations:
          summary: "High memory usage in container {{ $labels.name }}"
          description: "Container memory usage is above 85% (current value: {{ $value | humanize }}%)"

  - name: service_alerts
    interval: 30s
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
          category: services
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.job }} on {{ $labels.instance }} has been down for more than 2 minutes"

      - alert: PrometheusTargetMissing
        expr: up == 0
        for: 5m
        labels:
          severity: warning
          category: monitoring
        annotations:
          summary: "Prometheus target missing"
          description: "Target {{ $labels.job }} on {{ $labels.instance }} is down"

      - alert: GrafanaDown
        expr: up{job="grafana"} == 0
        for: 2m
        labels:
          severity: warning
          category: monitoring
        annotations:
          summary: "Grafana is down"
          description: "Grafana has been down for more than 2 minutes"
```

Определяет алерты для CPU, RAM, Disk, доступности сервисов с категоризацией по severity.

---

## Часть 4: Конфигурация Alertmanager

Файл `alertmanager/config/alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'telegram'
  group_by: ['alertname', 'severity', 'category']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    - receiver: 'telegram'
      match:
        severity: critical
      group_wait: 10s
      repeat_interval: 1h
      
    - receiver: 'telegram'
      match:
        severity: warning
      group_wait: 30s
      repeat_interval: 4h

receivers:
  - name: 'telegram'
    webhook_configs:
      - url: 'http://alertmanager-telegram:8080'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['instance']
  
  - source_match:
      alertname: 'HostDown'
    target_match:
      alertname: 'ServiceDown'
    equal: ['instance']
```

Маршрутизация алертов в Telegram с группировкой и подавлением дубликатов.

---

## Часть 5: Конфигурация Loki

Файл `loki/config/loki-config.yml`:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /loki/tsdb-index
    cache_location: /loki/tsdb-cache
  filesystem:
    directory: /loki/chunks

limits_config:
  retention_period: 30d
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_cache_freshness_per_query: 10m
  split_queries_by_interval: 15m

compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem

table_manager:
  retention_deletes_enabled: true
  retention_period: 30d

query_range:
  align_queries_with_step: true
  max_retries: 5
  cache_results: true
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100
```

Настройка хранения логов с retention 30 дней и компактором для автоматического удаления.

**Важное исправление:**
Параметр `delete_request_store: filesystem` критически необходим при включенном retention. Без него Loki не может запуститься с ошибкой валидации compactor config.

---

## Часть 6: Конфигурация Promtail

Файл `promtail/config/promtail-config.yml`:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: learning-host
          __path__: /var/log/*.log

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
      - static_labels:
          job: docker

  - job_name: monitoring
    static_configs:
      - targets:
          - localhost
        labels:
          job: monitoring
          host: learning-host
          __path__: /var/log/monitoring/*.log

  - job_name: nginx
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx
          host: learning-host
          __path__: /var/log/nginx/*.log
    pipeline_stages:
      - regex:
          expression: '^(?P<remote_addr>[\w\.]+) - (?P<remote_user>[^ ]*) \[(?P<time_local>.*)\] "(?P<method>[^ ]*) (?P<request>[^ ]*) (?P<protocol>[^ ]*)" (?P<status>[\d]+) (?P<body_bytes_sent>[\d]+) "(?P<http_referer>[^"]*)" "(?P<http_user_agent>[^"]*)"'
      - labels:
          method:
          status:
          remote_addr:
```

Автоматический сбор логов системы и Docker контейнеров с парсингом nginx логов.

---

## Часть 7: Конфигурация Blackbox Exporter

Файл `blackbox-exporter/config/blackbox.yml`:

```yaml
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200]
      method: GET
      follow_redirects: true
      preferred_ip_protocol: "ip4"

  http_post_2xx:
    prober: http
    timeout: 5s
    http:
      method: POST
      valid_status_codes: [200, 201]

  tcp_connect:
    prober: tcp
    timeout: 5s

  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"

  dns_query:
    prober: dns
    timeout: 5s
    dns:
      query_name: "google.com"
      query_type: "A"

  ssh_banner:
    prober: tcp
    timeout: 5s
    tcp:
      query_response:
        - expect: "^SSH-2.0-"
```

Модули для HTTP, TCP, ICMP, DNS проверок доступности сервисов.


## Часть 8: Конфигурация Grafana

### Datasources

Файл `grafana/provisioning/datasources/datasources.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: 15s
      queryTimeout: 60s
      httpMethod: POST
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      maxLines: 1000
      timeout: 60
    editable: true

  - name: Alertmanager
    type: alertmanager
    access: proxy
    url: http://alertmanager:9093
    jsonData:
      implementation: prometheus
    editable: true
```

Автоматическое подключение Prometheus, Loki, Alertmanager при старте Grafana.

### Dashboards provisioning

Файл `grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true
```

Настройка автоматической загрузки дашбордов из файловой системы.

---

## Часть 9: Запуск и валидация

### Установка прав доступа

```bash
cd ~/monitoring-stack

sudo chown -R 65534:65534 data/prometheus
sudo chown -R 472:472 data/grafana
sudo chown -R 10001:10001 data/loki

chmod -R 755 prometheus/config loki/config promtail/config alertmanager/config blackbox-exporter/config grafana/provisioning
```

Назначение правильных UID/GID для контейнеров.

### Запуск стека

```bash
docker compose up -d
```

### Проверка статуса

```bash
docker compose ps
```

Ожидаемый вывод: все контейнеры в статусе UP.

### Валидация сервисов

```bash
curl -s http://localhost:9090/-/healthy
curl -s http://localhost:3200/api/health
curl -s http://localhost:3100/ready
```

### Проверка targets Prometheus

```bash
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l
```


---

## Часть 10: Настройка HAProxy

### Генерация пароля для базовой аутентификации

Установка утилиты для генерации хешей паролей:

```bash
sudo apt install apache2-utils
```

Генерация хеша пароля:

```bash
htpasswd -nbB admin <YOUR_PASSWORD>
```

Вывод будет в формате `admin:$2y$05$...`. Хеш используется в конфигурации HAProxy.

### Структура директории HAProxy

```bash
mkdir -p ~/haproxy
cd ~/haproxy
```

### Docker Compose для HAProxy

Файл `~/haproxy/docker-compose.yml`:

```yaml
networks:
  proxy_network:
    driver: bridge
  monitoring_network:
    external: true

services:
  haproxy:
    image: haproxy:2.8-alpine
    container_name: haproxy
    ports:
      - "443:443"
      - "4443:4443"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    networks:
      - proxy_network
      - monitoring_network
    restart: unless-stopped
```

HAProxy подключается к сети `monitoring_network` для доступа к контейнерам мониторинга.

### Конфигурация HAProxy

Файл `~/haproxy/haproxy.cfg`:

```haproxy
global
    maxconn 4096
    log stdout format raw local0

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# Пользователи для базовой аутентификации
userlist monitoring_users
    user admin password $2y$05$GENERATED_HASH_HERE

# Frontend для мониторинга (Grafana, Prometheus, Alertmanager, Loki)
frontend monitoring_front
    bind *:4443
    mode http
    
    # Базовая аутентификация
    acl auth_ok http_auth(monitoring_users)
    http-request auth realm MonitoringAccess if !auth_ok
    
    # ACL для определения сервиса
    acl is_prometheus path_beg /prometheus
    acl is_alertmanager path_beg /alertmanager
    acl is_loki path_beg /loki
    
    # Маршрутизация
    use_backend prometheus_backend if is_prometheus
    use_backend alertmanager_backend if is_alertmanager
    use_backend loki_backend if is_loki
    default_backend grafana_backend

# Backend для Prometheus
backend prometheus_backend
    mode http
    http-request replace-path /prometheus(/)?(.*) /\2
    server prometheus prometheus:9090 check inter 2s

# Backend для Grafana
backend grafana_backend
    mode http
    server grafana grafana:3200 check inter 2s

# Backend для Loki
backend loki_backend
    mode http
    http-request replace-path /loki(/)?(.*) /\2
    server loki loki:3100 check inter 2s

# Backend для Alertmanager
backend alertmanager_backend
    mode http
    http-request replace-path /alertmanager(/)?(.*) /\2
    server alertmanager alertmanager:9093 check inter 2s
```

Конфигурация проксирует все сервисы мониторинга с базовой аутентификацией.

### Настройка Stats Endpoint

Для работы HAProxy Exporter необходимо добавить stats endpoint в конфигурацию HAProxy:

```haproxy
# Stats endpoint для HAProxy Exporter
frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
```

Добавьте эту секцию в `haproxy.cfg`. Stats endpoint будет доступен на порту 8404 только внутри Docker сети.

### Настройка хеша пароля

Замените `$2y$05$GENERATED_HASH_HERE` на реальный хеш из команды htpasswd.

Пример:

```bash
htpasswd -nbB admin MySecurePassword123
```

Вывод:

```
admin:$2y$05$wQjT4mF.1hZKxDvGjP8zXeB7LdHb4lX5nJvWzYpQrM3tCvB9xYzKu
```

Использовать в конфигурации:

```haproxy
userlist monitoring_users
    user admin password $2y$05$wQjT4mF.1hZKxDvGjP8zXeB7LdHb4lX5nJvWzYpQrM3tCvB9xYzKu
```

### Запуск HAProxy

```bash
cd ~/haproxy
docker compose up -d
```

### Проверка конфигурации

```bash
docker compose ps
docker compose logs haproxy
```

Проверка доступа к сервисам:

```bash
curl -u admin:MySecurePassword123 http://localhost:4443/
curl -u admin:MySecurePassword123 http://localhost:4443/prometheus/
```

---

## Часть 11: Внешний доступ

### Карта портов

| Порт | Сервис | Доступ |
|------|--------|--------|
| 4443 | Grafana, Prometheus, Alertmanager, Loki | HAProxy + Basic Auth |
| 9090 | Prometheus | Локальный |
| 3200 | Grafana | Локальный |
| 3100 | Loki | Локальный |
| 9093 | Alertmanager | Локальный |

### URL endpoints через HAProxy

```
https://<EXTERNAL_IP>:4443/                 # Grafana (default)
https://<EXTERNAL_IP>:4443/prometheus/      # Prometheus
https://<EXTERNAL_IP>:4443/alertmanager/    # Alertmanager
https://<EXTERNAL_IP>:4443/loki/            # Loki API
```

Аутентификация HAProxy: учетные данные из userlist в конфигурации.

### Проверка внешнего доступа

```bash
EXTERNAL_IP=$(curl -s ifconfig.me)

curl -u admin:<YOUR_PASSWORD> https://${EXTERNAL_IP}:4443/
curl -u admin:<YOUR_PASSWORD> https://${EXTERNAL_IP}:4443/prometheus/api/v1/targets
```

---

## Troubleshooting

### Loki не запускается

**Ошибка:**
```
CONFIG ERROR: invalid compactor config: compactor.delete-request-store should be configured when retention is enabled
```

**Решение:**
Добавить `delete_request_store: filesystem` в секцию compactor конфигурации Loki.

### Prometheus не собирает метрики

```bash
curl http://localhost:9090/api/v1/targets

docker exec prometheus kill -HUP 1
```

Проверить правильность конфигурации и доступность targets.

### Grafana не показывает данные

```bash
curl http://localhost:3200/api/datasources

docker compose logs grafana
```

Убедиться что datasources подключены и доступны.

### Ошибки прав доступа

```bash
sudo chown -R 65534:65534 data/alertmanager
sudo chown -R 65534:65534 data/prometheus
sudo chown -R 472:472 data/grafana
sudo chown -R 10001:10001 data/loki

docker compose restart
```

---

## Best Practices

### Retention политики

```yaml
Prometheus: 30 дней (--storage.tsdb.retention.time=30d)
Loki: 30 дней (retention_period: 30d)
```

### Мониторинг мониторинга

Prometheus мониторит сам себя через job `prometheus`. Алерты настроены для:
- Падение любого target
- Недоступность Prometheus
- Недоступность Grafana
- Недоступность Loki

### Безопасность

**Production рекомендации:**

1. Смена паролей:
```bash
# Grafana admin
# HAProxy auth credentials
```

2. HTTPS:
- Настроить Let's Encrypt для HAProxy

3. Firewall:
```bash
ufw allow 4443/tcp
ufw deny 9090/tcp
ufw deny 3200/tcp
ufw deny 3100/tcp
```

4. Network segmentation:
- Мониторинг в отдельной сети
- Ограничение доступа между сервисами

---

## Полезные команды

### Управление стеком

```bash
docker compose up -d              # Запуск
docker compose down               # Остановка
docker compose restart <service>  # Перезапуск сервиса
docker compose logs -f <service>  # Логи сервиса
docker compose ps                 # Статус контейнеров
```

### Перезагрузка конфигураций

```bash
# Prometheus
docker exec prometheus kill -HUP 1

# Grafana
docker compose restart grafana

# Loki
docker compose restart loki
```

### Проверка метрик

```bash
# Все targets
curl http://localhost:9090/api/v1/targets

# Query метрик
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Проверка логов

```bash
# Query логов через Loki
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="docker"}'

# Логи конкретного контейнера
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={container="prometheus"}'
```
