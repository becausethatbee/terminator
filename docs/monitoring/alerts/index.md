# Prometheus Stack с Docker - Полная конфигурация

Настройка мониторинга инфраструктуры через Docker Compose: Prometheus, Node-exporter, cAdvisor, Grafana, Alertmanager с проксированием через HAProxy.

## Предварительные требования

- Docker и Docker Compose
- HAProxy в Docker (сеть: `haproxy_proxy_network`)
- Firewall с открытым портом 8444/tcp
- Grafana доступна через HAProxy `/grafana` на порту 3200

---

## Структура каталогов

```bash
mkdir -p ~/monitoring-stack/{prometheus/{config,rules,data},grafana/data,alertmanager/{config,data}}
cd ~/monitoring-stack
```

Иерархия проекта:

```
monitoring-stack/
├── prometheus/
│   ├── config/
│   │   └── prometheus.yml          # Основная конфигурация
│   ├── rules/
│   │   └── alerts.yml              # Правила алертинга
│   └── data/                        # Time-series database
├── grafana/
│   └── data/                        # Dashboards, datasources, users
├── alertmanager/
│   ├── config/
│   │   └── alertmanager.yml        # Маршрутизация алертов
│   └── data/                        # Состояние алертов
└── docker-compose.yml
```

Типы томов:

| Компонент | Path | Тип | Описание |
|-----------|------|-----|---------|
| Prometheus | /prometheus | RW | TSDB, WAL, checkpoints |
| Prometheus | /etc/prometheus | RO | Конфиги prometheus.yml, rules/*.yml |
| Grafana | /var/lib/grafana | RW | БД sqlite, dashboards, datasources |
| Alertmanager | /alertmanager | RW | State алертов |
| Alertmanager | /etc/alertmanager | RO | alertmanager.yml |

---

## Docker Compose конфигурация

### docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:v3.7.1
    container_name: prometheus
    volumes:
      - ./prometheus/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/rules/alerts.yml:/etc/prometheus/rules/alerts.yml:ro
      - ./prometheus/data:/prometheus:rw
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
    restart: unless-stopped
    networks:
      - haproxy_proxy_network

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
    restart: unless-stopped
    networks:
      - haproxy_proxy_network

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
    restart: unless-stopped
    networks:
      - haproxy_proxy_network

  grafana:
    image: grafana/grafana:12.2.0
    container_name: grafana_monitoring
    volumes:
      - ./grafana/data:/var/lib/grafana:rw
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SERVER_HTTP_PORT=3200
      - GF_SERVER_ROOT_URL=http://<SERVER_IP>:8444/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      - GF_SERVER_DOMAIN=<SERVER_IP>
      - GF_METRICS_ENABLED=true
      - GF_METRICS_BASIC_AUTH_USERNAME=admin
      - GF_METRICS_BASIC_AUTH_PASSWORD=admin
    restart: unless-stopped
    networks:
      - haproxy_proxy_network

  alertmanager:
    image: prom/alertmanager:v0.27.0
    container_name: alertmanager
    volumes:
      - ./alertmanager/config/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ./alertmanager/data:/alertmanager:rw
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=http://<SERVER_IP>:8444/alertmanager/'
      - '--web.route-prefix=/'
    restart: unless-stopped
    networks:
      - haproxy_proxy_network

networks:
  haproxy_proxy_network:
    external: true
    name: haproxy_proxy_network
EOF
```

Замените `<SERVER_IP>` на IP адрес сервера.

Ключевые моменты:
- Все volumes с `:ro` для конфигов (read-only), `:rw` для данных
- `node-exporter` монтирует хост-системные директории для доступа к метрикам CPU, памяти, диска
- `cadvisor` требует privileged mode для доступа к метрикам Docker контейнеров
- `Grafana` слушает на порту 3200 (внутри контейнера), доступна через HAProxy на `/grafana`
- Все сервисы в `haproxy_proxy_network` (external сеть)

---

## Конфигурация Prometheus

### prometheus.yml

```bash
cat > prometheus/config/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production'
    monitor: 'prometheus-stack'

rule_files:
  - '/etc/prometheus/rules/alerts.yml'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/metrics'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'monitoring-host'
    metrics_path: '/metrics'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'docker-containers'
    metrics_path: '/metrics'

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']
    metrics_path: '/metrics'

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana_monitoring:3200']
    metrics_path: '/metrics'
    scheme: 'http'
    basic_auth:
      username: 'admin'
      password: 'admin'
EOF
```

Параметры конфигурации:

| Параметр | Значение | Назначение |
|----------|----------|-----------|
| scrape_interval | 15s | Интервал сбора метрик |
| evaluation_interval | 15s | Интервал оценки alert rules |
| retention.time | 15d | Период хранения TSDB |

---

## Конфигурация правил алертинга

### prometheus/rules/alerts.yml

```bash
mkdir -p prometheus/rules
cat > prometheus/rules/alerts.yml << 'EOF'
groups:
  - name: system_alerts
    interval: 15s
    rules:
      - alert: HighCPUUsage
        expr: (100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 2m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is {{ $value }}% on {{ $labels.instance }}"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 2m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is {{ $value }}% on {{ $labels.instance }}"

      - alert: DiskSpaceRunningOut
        expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lowerdir|squashfs"} / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "Low disk space on {{ $labels.device }}"
          description: "Disk {{ $labels.device }} has only {{ $value }}% free space"

      - alert: NodeExporterDown
        expr: up{job="node-exporter"} == 0
        for: 1m
        labels:
          severity: critical
          service: monitoring
        annotations:
          summary: "Node exporter is down"
          description: "Node exporter on {{ $labels.instance }} is unreachable"

      - alert: PrometheusDown
        expr: up{job="prometheus"} == 0
        for: 1m
        labels:
          severity: critical
          service: monitoring
        annotations:
          summary: "Prometheus is down"
          description: "Prometheus on {{ $labels.instance }} is unreachable"

  - name: container_alerts
    interval: 15s
    rules:
      - alert: ContainerCrashed
        expr: container_last_seen{name!~"POD|^$"} - time() > 30
        for: 1m
        labels:
          severity: warning
          service: docker
        annotations:
          summary: "Container crashed"
          description: "Container {{ $labels.name }} crashed or restarted"

      - alert: HighContainerCPU
        expr: (rate(container_cpu_usage_seconds_total{container_name!=""}[5m]) * 100) > 90
        for: 2m
        labels:
          severity: warning
          service: docker
        annotations:
          summary: "High container CPU usage"
          description: "Container {{ $labels.name }} CPU is {{ $value }}%"
EOF
```

Условия правил:
- `HighCPUUsage`: CPU >80% более 2 минут
- `HighMemoryUsage`: Память >85% более 2 минут
- `DiskSpaceRunningOut`: Менее 10% свободного места более 5 минут
- `NodeExporterDown`: Node-exporter недоступен более 1 минуты
- `PrometheusDown`: Prometheus недоступен более 1 минуты
- `ContainerCrashed`: Контейнер неактивен более 30 секунд
- `HighContainerCPU`: Контейнер использует >90% CPU более 2 минут

---

## Конфигурация Alertmanager

### alertmanager/config/alertmanager.yml

```bash
mkdir -p alertmanager/config
cat > alertmanager/config/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  receiver: 'default'
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  routes:
    - match:
        severity: critical
      receiver: 'critical'
      group_wait: 10s
      repeat_interval: 1h
    - match:
        severity: warning
      receiver: 'warnings'
      group_wait: 1m

receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/'
        send_resolved: true

  - name: 'critical'
    webhook_configs:
      - url: 'http://localhost:5002/'

  - name: 'warnings'
    webhook_configs:
      - url: 'http://localhost:5003/'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['instance']
  - source_match:
      alertname: 'PrometheusDown'
    target_match_re:
      alertname: '.*'
    equal: ['cluster']
EOF
```

Параметры конфигурации:
- `group_by`: Группировка алертов по labels
- `group_wait`: Ожидание перед отправкой (накопление алертов)
- `group_interval`: Интервал между отправками повторов
- `repeat_interval`: Как часто переотправлять resolved алерты
- `inhibit_rules`: Условия подавления алертов

---

## Конфигурация HAProxy

Добавить в HAProxy `haproxy.cfg` конфигурацию для Alertmanager:

```
acl is_alertmanager path_beg /alertmanager

use_backend alertmanager_backend if is_alertmanager

backend alertmanager_backend
    mode http
    http-request replace-path /alertmanager(/)?(.*) /\2
    server alertmanager alertmanager:9093
```

---

## Запуск и проверка

### Инициализация

```bash
mkdir -p prometheus/data grafana/data alertmanager/data
cd ~/monitoring-stack
```

### Запуск контейнеров

```bash
docker compose up -d
```

### Проверка статуса

```bash
docker compose ps
```

Должны быть видны все контейнеры со статусом Up.

### Проверка targets в Prometheus

```bash
docker exec prometheus wget -q -O - 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool
```

Результат показывает статус всех targets:
- job="prometheus" - сам Prometheus
- job="node-exporter" - метрики хоста
- job="cadvisor" - метрики контейнеров
- job="alertmanager" - Alertmanager
- job="grafana" - Grafana

### Проверка правил

```bash
docker exec prometheus wget -q -O - 'http://localhost:9090/api/v1/rules' | python3 -m json.tool | head -100
```

Должны быть видны группы alert rules с состояниями (inactive/pending/firing).

### Проверка Alertmanager

```bash
docker exec prometheus wget -q -O - 'http://alertmanager:9093/api/v1/status' | python3 -m json.tool
```

---

## PromQL примеры для анализа

**Память хоста (MB):**
```
node_memory_MemAvailable_bytes / 1024 / 1024
```

**CPU загрузка (%):**
```
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Использование диска (%):**
```
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

**Network I/O (bytes/sec):**
```
rate(node_network_receive_bytes_total[5m]) + rate(node_network_transmit_bytes_total[5m])
```

**Активные контейнеры:**
```
count(container_last_seen)
```

**CPU контейнера (%):**
```
(rate(container_cpu_usage_seconds_total[5m]) * 100)
```

**Memory контейнера (bytes):**
```
container_memory_usage_bytes
```

**Дисковый I/O по устройствам:**
```
rate(node_disk_io_time_seconds_total[10m])
```

**HTTP запросы к Prometheus:**
```
rate(prometheus_http_requests_total[5m])
```

---

## Troubleshooting

### Node-exporter не собирает метрики

**Ошибка:**
```
no such file or directory: /host/proc
```

**Решение:**

Убедиться что volumes правильно примонтированы в docker-compose.yml:
```yaml
volumes:
  - /proc:/host/proc:ro
  - /sys:/host/sys:ro
  - /:/rootfs:ro
```

### cAdvisor возвращает пустые метрики контейнеров

**Причина:** Требует privileged mode и доступа к Docker хранилищу.

**Решение:**
```yaml
privileged: true
volumes:
  - /var/lib/docker/:/var/lib/docker:ro
  - /dev/disk/:/dev/disk:ro
```

### Grafana на порту 3200 недоступна

**Проверка логов:**

```bash
docker logs grafana_monitoring | tail -20
```

**Проверка доступности:**

```bash
docker exec alertmanager wget -q -O - 'http://grafana_monitoring:3200/api/health'
```

**Решение:**

Убедиться что GF_SERVER_HTTP_PORT=3200 в environment и контейнер в правильной сети.

### Alertmanager не отправляет алерты

**Проверка статуса:**

```bash
docker logs alertmanager
docker exec alertmanager wget -q -O - 'http://localhost:9093/api/v1/status'
```

**Проверка синтаксиса конфига:**

```bash
docker exec alertmanager amtool config routes
```

**Решение:**

Проверить alertmanager.yml на синтаксис и webhook URL'ы доступны.

### Prometheus не видит targets

**Проверка конфига:**

```bash
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

**Проверка логов:**

```bash
docker logs prometheus | grep -i error
```

**Решение:**

Убедиться что имена контейнеров совпадают с названиями в prometheus.yml (node-exporter, cadvisor, grafana_monitoring, alertmanager).

### High memory usage контейнеров

**Проверка ресурсов:**

```bash
docker stats prometheus grafana_monitoring alertmanager
```

**Решение:**

Увеличить retention период для prometheus или запустить на машине с большим объёмом памяти.

---

## Best Practices

**Node-exporter:**
- Монтировать хост-системные директории только в read-only режиме
- Отключать неиспользуемые collectors для оптимизации памяти
- Регулярно обновлять образ для получения новых метрик

**Prometheus:**
- Устанавливать retention период в зависимости от дискового пространства
- Использовать external labels для идентификации кластеров
- Проверять синтаксис конфига перед перезагрузкой

**cAdvisor:**
- Требует privileged mode и доступа к /var/lib/docker
- Собирает метрики только запущенных контейнеров
- Периодически очищать старые метрики контейнеров

**Grafana:**
- Использовать сложные пароли для доступа
- Периодически резервировать /var/lib/grafana
- Экспортировать важные dashboards как JSON

**Alertmanager:**
- Группировать related алерты через group_by для избежания spam'а
- Настроить inhibit_rules для подавления duplicate алертов
- Регулярно проверять webhook'и доступны

**Безопасность:**
- Использовать базовую HTTP аутентификацию через HAProxy
- Ограничить доступ к портам через firewall
- Регулярно обновлять образы контейнеров

---

## Настройка прав доступа

```bash
sudo chown -R 65534:65534 prometheus/data
sudo chown -R 472:472 grafana/data
sudo chown -R 65534:65534 alertmanager/data
```

UID:GID контейнеров:

| Компонент | UID:GID | Пользователь |
|-----------|---------|--------------|
| Prometheus | 65534:65534 | nobody |
| Grafana | 472:472 | grafana |
| Alertmanager | 65534:65534 | nobody |

---

## Полезные команды

**Перезагрузка Prometheus с переvalidацией конфига:**

```bash
docker compose restart prometheus
docker logs prometheus | grep -i error
```

**Проверка синтаксиса prometheus.yml:**

```bash
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

**Проверка синтаксиса rules:**

```bash
docker exec prometheus promtool check rules /etc/prometheus/rules/alerts.yml
```

**Список всех targets:**

```bash
docker exec prometheus wget -q -O - 'http://localhost:9090/api/v1/targets' | python3 -m json.tool
```

**Количество series в TSDB:**

```bash
docker exec prometheus wget -q -O - 'http://localhost:9090/api/v1/query?query=count(up)' | python3 -m json.tool
```

**Размер TSDB:**

```bash
du -sh prometheus/data/
```

**Получение метрик Node-exporter:**

```bash
docker exec node-exporter wget -q -O - 'http://localhost:9100/metrics' | head -50
```

**Получение метрик cAdvisor:**

```bash
docker exec cadvisor wget -q -O - 'http://localhost:8080/metrics' | grep container_cpu | head -20
```

**Проверка Alertmanager конфига:**

```bash
docker exec alertmanager amtool config routes
```

**Список текущих алертов:**

```bash
docker exec alertmanager wget -q -O - 'http://localhost:9093/api/v1/alerts' | python3 -m json.tool
```

**Отправить test алерт:**

```bash
curl -X POST -H "Content-Type: application/json" -d '[{"labels":{"alertname":"TestAlert","severity":"critical"}}]' http://alertmanager:9093/api/v1/alerts
```

**Просмотр логов контейнеров:**

```bash
docker compose logs -f prometheus
docker compose logs -f grafana_monitoring
docker compose logs alertmanager --tail 50
```

**Перезапуск отдельного сервиса:**

```bash
docker compose restart prometheus
docker compose restart grafana_monitoring
```

**Полная пересборка стека:**

```bash
docker compose down
docker compose up -d --force-recreate
```

**Проверка прав доступа томов:**

```bash
ls -ln prometheus/data grafana/data alertmanager/data
```

**Статистика использования ресурсов:**

```bash
docker stats prometheus grafana_monitoring alertmanager node-exporter cadvisor
```
