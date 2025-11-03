# Настройка метрик и экспортеров

Конфигурация системы сбора метрик для инфраструктуры мониторинга.

## Установленные экспортеры

| Exporter | Версия | Порт | Назначение |
|----------|--------|------|------------|
| Node Exporter | 1.8.2 | 9100 | Метрики хоста (CPU, RAM, Disk, Network) |
| cAdvisor | 0.49.1 | 9200 | Метрики Docker контейнеров |
| HAProxy Exporter | 0.15.0 | 9101 | Детальная статистика HAProxy |
| Blackbox Exporter | 0.25.0 | 9115 | HTTP/TCP/ICMP проверки доступности |

---

## Конфигурация экспортеров

### HAProxy Exporter

Файл `~/monitoring-stack/docker-compose.yml`:

```yaml
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

Подключается к HAProxy через внутреннюю сеть для доступа к stats endpoint (`:8404/stats`). Stats доступны только внутри Docker сети.

**Метрики:**
- `haproxy_server_up` - статус backend серверов
- `haproxy_backend_http_responses_total` - HTTP ответы по кодам
- `haproxy_backend_connections_total` - количество соединений
- `haproxy_backend_bytes_in_total` - входящий трафик
- `haproxy_backend_bytes_out_total` - исходящий трафик

---

## Конфигурация Prometheus

Файл `~/monitoring-stack/prometheus/config/prometheus.yml`:

```yaml
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

  - job_name: 'haproxy'
    static_configs:
      - targets: ['haproxy-exporter:9101']
        labels:
          service: 'haproxy'


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

Все экспортеры используют внутренние Docker DNS имена для связи.

---

## Конфигурация Docker сетей

Файл `~/monitoring-stack/docker-compose.yml` должен содержать секцию networks:

```yaml
networks:
  monitoring:
    driver: bridge
  haproxy_proxy_network:
    external: true
```

**Важно:** Экспортер должен находиться в одной сети с целевым приложением для доступа к его метрикам.

Примеры:
- `haproxy-exporter` подключен к `haproxy_proxy_network` для доступа к HAProxy stats

---

## Добавление нового экспортера

### Шаг 1: Добавление в Docker Compose

Файл `~/monitoring-stack/docker-compose.yml`:

```yaml
services:
  # Существующие сервисы...
  
  # Новый exporter
  <service-name>-exporter:
    image: <exporter-image>:<version>
    container_name: <service-name>-exporter
    command:
      - --flag1=value1
      - --flag2=value2
    ports:
      - "<host-port>:<container-port>"
    restart: unless-stopped
    networks:
      - monitoring                    # Обязательно для Prometheus
      - <target-service-network>      # Сеть целевого приложения
    # При необходимости:
    volumes:
      - ./config:/etc/exporter:ro
    cap_add:
      - NET_ADMIN                     # Если требуется
```

**Критически важно:** Экспортер должен быть в двух сетях:
1. `monitoring` - для связи с Prometheus
2. Сеть целевого приложения - для доступа к его метрикам/API

### Шаг 2: Определение сети целевого приложения

Проверьте в какой сети находится целевое приложение:

```bash
docker inspect <service-container> | grep -A10 "Networks"
```

Или проверьте список сетей:

```bash
docker network ls
```

Добавьте эту сеть как external в секцию networks:

```yaml
networks:
  monitoring:
    driver: bridge
  <target-service-network>:
    external: true
```

### Шаг 3: Добавление в Prometheus

Файл `~/monitoring-stack/prometheus/config/prometheus.yml`:

```yaml
scrape_configs:
  # Существующие jobs...
  
  - job_name: '<service-name>'
    static_configs:
      - targets: ['<service-name>-exporter:<port>']
        labels:
          service: '<service-name>'
          instance: '<instance-name>'
```

### Шаг 4: Применение изменений

```bash
cd ~/monitoring-stack

# Запуск нового exporter
docker compose up -d <service-name>-exporter

# Проверка логов
docker logs <service-name>-exporter

# Перезагрузка Prometheus конфигурации
docker exec prometheus kill -HUP 1

# Проверка метрик exporter
curl -s http://localhost:<host-port>/metrics | head -20

# Проверка target в Prometheus
curl -s http://localhost:9090/api/v1/targets | grep <service-name>
```

### Пример: Добавление Redis Exporter

**1. Docker Compose:**

```yaml
  redis-exporter:
    image: oliver006/redis_exporter:v1.55.0
    container_name: redis-exporter
    environment:
      - REDIS_ADDR=redis:6379
    ports:
      - "9121:9121"
    restart: unless-stopped
    networks:
      - monitoring
      - redis_network
```

**2. Networks:**

```yaml
networks:
  monitoring:
    driver: bridge
  redis_network:
    external: true
```

**3. Prometheus:**

```yaml
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
        labels:
          service: 'redis'
```

**4. Запуск:**

```bash
docker compose up -d redis-exporter
docker exec prometheus kill -HUP 1
curl http://localhost:9121/metrics | grep redis_up
```

---

## Добавление exporter в HAProxy сеть

Если exporter нужно добавить в сеть HAProxy (например, для мониторинга сервисов за HAProxy):

**1. Проверьте сеть HAProxy:**

```bash
docker network ls | grep haproxy
docker network inspect haproxy_proxy_network | grep "Name"
```

**2. Добавьте сеть в docker-compose exporter:**

```yaml
  <service>-exporter:
    networks:
      - monitoring
      - haproxy_proxy_network
```

**3. Убедитесь что сеть external в networks:**

```yaml
networks:
  monitoring:
    driver: bridge
  haproxy_proxy_network:
    external: true
```

**4. Перезапустите exporter:**

```bash
docker compose up -d --force-recreate <service>-exporter
```

**5. Проверьте сетевую связность:**

```bash
docker exec <service>-exporter ping -c 3 haproxy
docker exec haproxy ping -c 3 <service>-exporter
```

---

## История добавления экспортеров в проект

### HAProxy Exporter

**Проблема:** Нужны детальные метрики HAProxy (backend status, response times, traffic).

**Решение:**
1. Добавлен в `docker-compose.yml` с подключением к `haproxy_proxy_network`
2. Настроен на scrape HAProxy stats endpoint: `http://haproxy:8404/stats;csv`
3. Добавлен job в Prometheus: `haproxy-exporter:9101`

**Ключевой момент:** Exporter должен быть в сети `haproxy_proxy_network` для доступа к HAProxy stats.


---

## Все экспортеры в docker-compose.yml

Полная секция services для экспортеров в `~/monitoring-stack/docker-compose.yml`:

```yaml
services:
  # ... другие сервисы (prometheus, grafana, loki и т.д.)
  
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


networks:
  monitoring:
    driver: bridge
  haproxy_proxy_network:
    external: true
```

---

## Проверка статуса

### Проверка работы экспортеров

```bash
# Node Exporter
curl -s http://localhost:9100/metrics | grep node_cpu_seconds_total

# cAdvisor
curl -s http://localhost:9200/metrics | grep container_cpu_usage_seconds_total

# HAProxy Exporter
curl -s http://localhost:9101/metrics | grep haproxy_server_up


# Blackbox Exporter
curl -s http://localhost:9115/metrics | grep probe_success
```

### Проверка targets в Prometheus

```bash
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l
```


### Веб-интерфейс Prometheus

```
https://<SERVER_IP>:4443/prometheus/targets
```

Логин/пароль: учетные данные HAProxy.

---

## Ключевые метрики

### Метрики хоста (Node Exporter)

```promql
# CPU usage
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100

# Network traffic
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

### Метрики контейнеров (cAdvisor)

```promql
# Container CPU
sum(rate(container_cpu_usage_seconds_total{name=~".+"}[5m])) by (name) * 100

# Container Memory
container_memory_usage_bytes{name=~".+"}

# Container Network
rate(container_network_receive_bytes_total{name=~".+"}[5m])
rate(container_network_transmit_bytes_total{name=~".+"}[5m])
```

### Метрики HAProxy

```promql
# Backend status
haproxy_server_up

# HTTP requests
rate(haproxy_backend_http_requests_total[5m])

# Response time
haproxy_backend_response_time_average_seconds

# Traffic
rate(haproxy_backend_bytes_in_total[5m])
rate(haproxy_backend_bytes_out_total[5m])
```


---

## Структура проектов

### Monitoring Stack

```
~/monitoring-stack/
├── docker-compose.yml
├── prometheus/
│   ├── config/
│   │   └── prometheus.yml
│   └── rules/
│       └── alerts.yml
└── data/
    ├── prometheus/
    ├── grafana/
    └── loki/
```


### HAProxy

```
~/docker-haproxy/
├── docker-compose.yml
└── haproxy.cfg
```

---

## Сетевая топология

```
monitoring_network (bridge)
├── prometheus
├── grafana
├── loki
├── alertmanager
├── node-exporter
├── cadvisor
├── blackbox-exporter
```

Экспортеры подключены к нескольким сетям для доступа к целевым сервисам.

---

## Troubleshooting

### Exporter не отдает метрики

```bash
# Проверка статуса
docker compose ps | grep exporter

# Логи
docker logs <exporter-name>

# Проверка сетевой связности
docker exec prometheus ping -c 3 <exporter-name>
```

### Target DOWN в Prometheus

```bash
# Проверка targets
curl -s http://localhost:9090/api/v1/targets | grep -B5 '"health":"down"'

# Перезагрузка конфигурации
docker exec prometheus kill -HUP 1

# Проверка конфигурации
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### HAProxy Exporter: Connection refused

HAProxy stats endpoint доступен только внутри Docker сети:

```bash
docker exec haproxy-exporter curl http://haproxy:8404/stats
```

Убедитесь что exporter в сети `haproxy_proxy_network`.

---

## Полезные команды

### Управление экспортерами

```bash
cd ~/monitoring-stack

# Перезапуск конкретного exporter
docker compose restart <exporter-name>

# Просмотр логов
docker compose logs -f <exporter-name>

# Обновление образа
docker compose pull <exporter-name>
docker compose up -d <exporter-name>
```

### Проверка метрик

```bash
# Список всех метрик
curl -s http://localhost:9090/api/v1/label/__name__/values | python3 -m json.tool

# Query метрик
curl -s 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool

# Range query
curl -s 'http://localhost:9090/api/v1/query_range?query=up&start=1609459200&end=1609545600&step=15' | python3 -m json.tool
```


---

## Best Practices

### Retention метрик

Prometheus настроен на хранение метрик 30 дней (`--storage.tsdb.retention.time=30d`).

Для долгосрочного хранения используйте:
- Remote write в Thanos/Cortex
- Federated Prometheus
- Export в внешнее хранилище

### Label management

Используйте консистентные labels:
- `instance` - идентификатор инстанса
- `job` - тип сервиса
- `service` - имя сервиса
- `environment` - окружение (dev/prod)

### Scrape intervals

```yaml
global:
  scrape_interval: 15s      # Стандартный интервал
  evaluation_interval: 15s  # Частота проверки rules
```

Для высоконагруженных систем можно снизить до 10s.

### Security

```bash
# Firewall rules
ufw deny 9090/tcp   # Prometheus
ufw deny 9100/tcp   # Node Exporter
ufw deny 9200/tcp   # cAdvisor
ufw deny 9101/tcp   # HAProxy Exporter

# Доступ только через HAProxy на :4443
ufw allow 4443/tcp
```

Все экспортеры доступны только внутри Docker сетей или через HAProxy с аутентификацией.
