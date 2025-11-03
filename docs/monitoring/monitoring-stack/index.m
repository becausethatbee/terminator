# Установка стека мониторинга с HAProxy

Развертывание Prometheus, Grafana и Loki в Docker контейнерах с проксированием через HAProxy и базовой HTTP аутентификацией.

## Предварительные требования

- Docker и Docker Compose
- HAProxy в Docker контейнере
- Firewalld
- Открытые порты: 8444/tcp
- Доступ к сети `haproxy_proxy_network`

---

## Архитектура решения

```
Internet → Firewall (8444) → HAProxy (HTTP Auth) → {
    /grafana → Grafana:3000
    /prometheus → Prometheus:9090
    /loki → Loki:3100
}
```

**Сетевая топология:**
- Все контейнеры в единой Docker сети `haproxy_proxy_network`
- HAProxy обеспечивает единую точку входа с аутентификацией
- Контейнеры мониторинга не экспонируют порты наружу

---

## Структура проекта

```bash
mkdir -p ~/monitoring-stack/{prometheus,grafana,loki}/{config,data}
cd ~/monitoring-stack
```

Создается следующая структура:

```
monitoring-stack/
├── prometheus/
│   ├── config/
│   │   └── prometheus.yml
│   └── data/
├── grafana/
│   ├── config/
│   └── data/
└── loki/
    ├── config/
    │   └── loki-config.yml
    └── data/
```

---

## Конфигурация Prometheus

### prometheus.yml

```bash
cat > prometheus/config/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
```

**Параметры:**

| Параметр | Значение | Назначение |
|----------|----------|------------|
| scrape_interval | 15s | Интервал сбора метрик |
| evaluation_interval | 15s | Интервал оценки правил |
| targets | localhost:9090 | Самомониторинг Prometheus |

---

## Конфигурация Loki

### loki-config.yml

```bash
cat > loki/config/loki-config.yml <<EOF
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s
  wal:
    dir: /loki/wal

schema_config:
  configs:
    - from: 2020-05-15
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/compactor

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF
```

**Ключевые параметры:**

| Компонент | Параметр | Значение |
|-----------|----------|----------|
| server | http_listen_port | 3100 |
| schema_config | store | tsdb |
| schema_config | schema | v13 |
| storage_config | directory | /loki/chunks |
| ingester | wal.dir | /loki/wal |

---

## Docker Compose конфигурация

### docker-compose.yml

```bash
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    volumes:
      - ./prometheus/config/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    restart: unless-stopped
    networks:
      - haproxy_network

  loki:
    image: grafana/loki:latest
    container_name: loki
    volumes:
      - ./loki/config/loki-config.yml:/etc/loki/loki-config.yml
      - ./loki/data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    restart: unless-stopped
    networks:
      - haproxy_network

  grafana:
    image: grafana/grafana:latest
    container_name: grafana_monitoring
    volumes:
      - ./grafana/data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SERVER_ROOT_URL=http://<SERVER_IP>:8444/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      - GF_SERVER_DOMAIN=<SERVER_IP>
    restart: unless-stopped
    networks:
      - haproxy_network

networks:
  haproxy_network:
    external: true
    name: haproxy_proxy_network
EOF
```

Замените `<SERVER_IP>` на IP адрес сервера.

**Особенности конфигурации:**

- Контейнер Grafana: `grafana_monitoring` - избежание конфликта имен
- Сеть: `haproxy_proxy_network` (external) - интеграция с существующей инфраструктурой
- Порты не экспонируются - доступ только через HAProxy
- `GF_SERVER_ROOT_URL` - явный URL для корректных редиректов

---

## Настройка прав доступа

```bash
sudo chown -R 65534:65534 prometheus/data
sudo chown -R 10001:10001 loki/data
sudo chown -R 472:472 grafana/data
```

**UID/GID контейнеров:**

| Сервис | UID:GID | Пользователь |
|--------|---------|--------------|
| Prometheus | 65534:65534 | nobody |
| Loki | 10001:10001 | loki |
| Grafana | 472:472 | grafana |

---

## Конфигурация HAProxy

### Генерация пароля для базовой аутентификации

```bash
cd ~/haproxy
docker run --rm httpd:2.4-alpine htpasswd -nbB admin <PASSWORD> > auth-users
```

### haproxy.cfg

Добавьте в конфигурацию HAProxy:

```haproxy
# Frontend для мониторинга с базовой аутентификацией
frontend monitoring_front
    bind *:8444
    mode http
    option httplog
    
    # Базовая аутентификация
    acl auth_ok http_auth(monitoring_users)
    http-request auth realm monitoring unless auth_ok
    
    # Роутинг по пути
    acl is_prometheus path_beg /prometheus
    acl is_grafana path_beg /grafana
    acl is_loki path_beg /loki
    
    use_backend prometheus_backend if is_prometheus
    use_backend grafana_backend if is_grafana
    use_backend loki_backend if is_loki
    
    default_backend grafana_backend

# Backend для Prometheus
backend prometheus_backend
    mode http
    http-request replace-path /prometheus(/)?(.*) /\2
    server prometheus prometheus:9090

# Backend для Grafana
backend grafana_backend
    mode http
    server grafana grafana_monitoring:3000

# Backend для Loki
backend loki_backend
    mode http
    http-request replace-path /loki(/)?(.*) /\2
    server loki loki:3100

# Пользователи для базовой аутентификации
userlist monitoring_users
    user admin password <BCRYPT_HASH>
```

**Ключевые моменты:**

- `bind *:8444` - порт для мониторинга
- `http_auth(monitoring_users)` - базовая HTTP аутентификация
- `path_beg` - роутинг по префиксу пути
- `replace-path` - удаление префикса для Prometheus и Loki
- Grafana backend **без** `replace-path` - путь передается как есть

### docker-compose.yml HAProxy

Обновите маппинг портов:

```yaml
services:
  haproxy:
    ports:
      - "443:443"
      - "8444:8444"
```

---

## Настройка Firewall

```bash
sudo firewall-cmd --permanent --add-port=8444/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

---

## Запуск стека

### Запуск контейнеров мониторинга

```bash
cd ~/monitoring-stack
docker compose up -d
docker compose ps
```

### Перезапуск HAProxy

```bash
cd ~/haproxy
docker compose restart haproxy
```

### Валидация доступности

```bash
# Grafana
curl -u admin:<PASSWORD> http://localhost:8444/grafana/api/health

# Prometheus
curl -u admin:<PASSWORD> http://localhost:8444/prometheus/api/v1/status/config

# Loki (требует ~15s на прогрев после старта)
curl -u admin:<PASSWORD> http://localhost:8444/loki/ready
```

---

## Настройка источников данных в Grafana

### Доступ к интерфейсу

URL: `http://<SERVER_IP>:8444/grafana/`

**Двухуровневая аутентификация:**

1. Базовая HTTP аутентификация (всплывающее окно):
   - Username: `admin`
   - Password: `<PASSWORD>` (из auth-users)

2. Логин Grafana:
   - Username: `admin`
   - Password: `admin`

### Подключение Prometheus

1. **Menu (☰)** → **Connections** → **Data Sources**
2. **Add data source** → **Prometheus**
3. **URL:** `http://prometheus:9090`
4. **Save & Test**

Ожидаемый результат:
```
Successfully queried the Prometheus API.
```

### Подключение Loki

1. **Menu (☰)** → **Connections** → **Data Sources**
2. **Add data source** → **Loki**
3. **URL:** `http://loki:3100`
4. **Save & Test**

Ожидаемый результат:
```
Data source successfully connected.
```

---

## Создание дашборда

### Панель с метриками Prometheus

1. **Menu (☰)** → **Dashboards** → **New** → **New Dashboard**
2. **Add visualization** → выбрать **Prometheus**
3. Запрос:
   ```promql
   prometheus_http_requests_total
   ```
4. **Apply** → **Save dashboard**

### Панель с логами Loki

1. **Add** → **Visualization** → выбрать **Loki**
2. Запрос:
   ```logql
   {job=~".+"}
   ```
3. Тип визуализации: **Logs**
4. **Apply** → **Save dashboard**

**Примечание:** Для отображения логов необходим агент сбора (Promtail/Alloy).

---

## Troubleshooting

### HAProxy не видит backend контейнеры

**Ошибка:**
```
<NOSRV> - No server is available
```

**Причина:** Контейнеры не в одной Docker сети.

**Решение:**
```bash
docker network inspect haproxy_proxy_network --format '{{range .Containers}}{{.Name}} {{end}}'
```

Убедитесь что все контейнеры (haproxy, prometheus, grafana_monitoring, loki) в одной сети.

### Grafana редиректит на localhost

**Причина:** Некорректная конфигурация `GF_SERVER_ROOT_URL`.

**Решение:**
```yaml
environment:
  - GF_SERVER_ROOT_URL=http://<SERVER_IP>:8444/grafana/
  - GF_SERVER_SERVE_FROM_SUB_PATH=true
  - GF_SERVER_DOMAIN=<SERVER_IP>
```

Если проблема сохраняется после изменения:
```bash
docker compose stop grafana
sudo mv grafana/data grafana/data.backup
sudo mkdir -p grafana/data
sudo chown -R 472:472 grafana/data
docker compose up -d grafana
```

### Loki возвращает "Ingester not ready"

**Причина:** Loki требует ~15 секунд на инициализацию после старта.

**Решение:** Подождите 15-20 секунд и повторите запрос.

### Permission denied при записи в volume

**Ошибка:**
```
mkdir: cannot create directory '/prometheus': Permission denied
```

**Решение:**
```bash
sudo chown -R 65534:65534 prometheus/data
sudo chown -R 10001:10001 loki/data
sudo chown -R 472:472 grafana/data
```

### Конфликт портов при запуске контейнера

**Ошибка:**
```
Bind for :::3000 failed: port is already allocated
```

**Причина:** Порт уже используется другим контейнером.

**Решение:** Убедитесь что контейнеры не экспонируют порты:
```yaml
# Неправильно
ports:
  - "3000:3000"

# Правильно (доступ только через Docker сеть)
expose:
  - "3000"
```

Или переименуйте контейнер:
```yaml
container_name: grafana_monitoring
```

---

## Best Practices

**Безопасность:**
- Используйте сложные пароли для базовой HTTP аутентификации
- Регулярно обновляйте образы контейнеров
- Ограничьте доступ к порту 8444 через firewall правила
- Рассмотрите использование TLS для шифрования трафика

**Производительность:**
- Настройте retention политику для Prometheus: `--storage.tsdb.retention.time=15d`
- Для Loki установите лимиты: `ingestion_rate_mb`, `ingestion_burst_size_mb`
- Мониторьте использование дискового пространства для `data` директорий

**Отказоустойчивость:**
- Используйте `restart: unless-stopped` для автоматического восстановления
- Регулярно создавайте бэкапы `data` директорий
- Настройте мониторинг самих сервисов мониторинга через внешний источник

**Масштабирование:**
- Для production используйте внешние хранилища (S3, Minio) вместо filesystem
- Рассмотрите использование remote_write для федерации Prometheus
- Настройте High Availability для критичных компонентов

**Сетевая архитектура:**
- Используйте единую Docker сеть для связанных сервисов
- Избегайте экспонирования портов контейнеров наружу
- Централизуйте доступ через reverse proxy с аутентификацией

---

## Полезные команды

```bash
# Проверка статуса контейнеров
docker compose ps

# Просмотр логов
docker compose logs -f grafana
docker compose logs -f prometheus
docker compose logs loki --tail 50

# Перезапуск отдельного сервиса
docker compose restart grafana

# Полная пересборка
docker compose down
docker compose up -d --force-recreate

# Проверка сети
docker network inspect haproxy_proxy_network

# Очистка данных (осторожно!)
sudo rm -rf prometheus/data/* loki/data/* grafana/data/*

# Проверка прав доступа
ls -ln */data

# Тест доступности из контейнера HAProxy
docker exec haproxy wget -q -O- http://grafana_monitoring:3000/api/health
docker exec haproxy wget -q -O- http://prometheus:9090/-/ready
docker exec haproxy wget -q -O- http://loki:3100/ready

# Получение метрик напрямую
curl http://localhost:9090/metrics  # если порт открыт
curl http://localhost:3100/metrics  # если порт открыт
```

**Диагностика HAProxy:**
```bash
# Просмотр текущих соединений
docker exec haproxy sh -c "echo 'show sess' | socat stdio unix-connect:/var/run/haproxy.sock"

# Статистика backend'ов
docker exec haproxy sh -c "echo 'show stat' | socat stdio unix-connect:/var/run/haproxy.sock"

# Проверка конфигурации
docker exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg
```

**Мониторинг ресурсов:**
```bash
# Использование ресурсов контейнерами
docker stats prometheus grafana_monitoring loki

# Размер volume данных
du -sh prometheus/data grafana/data loki/data
```
