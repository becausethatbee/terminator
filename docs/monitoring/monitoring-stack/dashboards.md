# Работа с Grafana и дашбордами

Руководство по использованию Grafana для визуализации метрик и логов в мониторинг стеке.

## Доступ к Grafana

**URL:** `http://<EXTERNAL_IP>:4443/`  
**Логин:** `admin`  
**Пароль:** `admin`

Порт 4443 проксируется через HAProxy с базовой HTTP аутентификацией.

---

## Импортированные дашборды

### System Monitoring

**Node Exporter Full (ID: 1860)**

Детальный мониторинг хоста с метриками CPU, памяти, диска и сети.

| Метрика | Описание |
|---------|----------|
| CPU usage | Процент использования ядер |
| Load average | Средняя нагрузка за 1, 5, 15 минут |
| Context switches | Переключения контекста |
| Memory usage | Использование оперативной памяти |
| Swap usage | Использование swap памяти |
| Disk I/O | Операции чтения/записи |
| Disk space | Свободное место |
| Network traffic | Входящий/исходящий трафик |
| System uptime | Время работы системы |

**Переменные:** `$instance` для выбора конкретного хоста.

**Docker Container & Host Metrics (ID: 10619)**

Мониторинг Docker контейнеров с метриками использования ресурсов.

| Метрика | Описание |
|---------|----------|
| Container CPU | Использование CPU контейнером |
| Container memory | Использование памяти контейнером |
| Network I/O per container | Сетевой трафик по контейнерам |
| Disk I/O per container | Дисковый I/O по контейнерам |
| Container restarts | Количество перезапусков |

**Переменные:** `$container` для фильтрации по контейнеру.

### Infrastructure

**HAProxy Servers (ID: 367)**

Статус backend и frontend серверов, throughput, response time.

| Метрика | Описание |
|---------|----------|
| Backend status | Статус backend серверов |
| Frontend status | Статус frontend слушателей |
| Request rate | Количество запросов в секунду |
| Response time | Время ответа |
| Session counts | Активные соединения |
| Bytes in/out | Пропускная способность |

**Prometheus Stats (ID: 3662)**

Self-monitoring Prometheus с метриками сбора и хранения.

Параметры: scrape duration, samples ingested, memory usage, storage size, health targets.

**Blackbox Exporter (ID: 13659)**

Проверка доступности HTTP/HTTPS endpoints, SSL сертификаты, DNS resolution.

| Параметр | Описание |
|----------|----------|
| Probe success rate | Процент успешных проверок |
| Response time | Время ответа от endpoint |
| SSL certificate expiry | Дней до истечения сертификата |
| DNS resolution time | Время разрешения DNS |

### Logs

**Loki Dashboard (ID: 13639)**

Мониторинг самого Loki с метриками ingestion, query performance, storage.

Параметры: logs ingestion rate, query latency, storage usage, error counts.

### Custom

**Infrastructure Overview**

Единая точка контроля состояния всей инфраструктуры с auto-refresh каждые 30 секунд.

| Секция | Содержимое |
|--------|-----------|
| System Health | CPU, RAM, Disk, Uptime |
| Services Status | Targets, Containers, Backends, Peers |
| Traffic & Performance | Network, HAProxy metrics |
| Recent Issues | Errors, Rejections, Warnings |

---

## Организация дашбордов

### Структура папок

```
Folder: Overview
  └── Infrastructure Overview

Folder: System Monitoring
  ├── Node Exporter Full
  └── Docker Container & Host Metrics

Folder: Infrastructure
  ├── HAProxy Servers
  ├── Prometheus Stats
  └── Blackbox Exporter

Folder: Logs
  └── Loki Dashboard
```

### Создание папки

1. **Dashboards** → **New folder**
2. Введите имя папки
3. **Create**

### Перемещение дашборда в папку

1. Откройте дашборд
2. **Settings** → **General**
3. **Folder** → выберите целевую папку
4. **Save dashboard**

---

## Explore: Ad-hoc запросы

### Для Prometheus (PromQL)

1. **Explore** → **Prometheus**
2. Используйте **Metrics browser** или вводите запросы вручную

**Примеры запросов:**

```promql
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

CPU utilization в процентах.

```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

Memory utilization в процентах.

```promql
rate(haproxy_backend_http_requests_total[5m])
```

HAProxy requests per second по backends.

```promql
sum by (name) (rate(container_cpu_usage_seconds_total[5m])) * 100
```

CPU per container в процентах.

### Для Loki (LogQL)

1. **Explore** → **Loki**
2. Используйте **Label browser** или вводите запросы вручную

**Примеры запросов:**

```logql
{container="haproxy"}
```

Все логи HAProxy контейнера.

```logql
{job="docker"} |~ "(?i)error|fail"
```

Логи с ошибками из всех Docker контейнеров.

```logql
{container="haproxy", backend="trojan_backend"}
```

Логи конкретного HAProxy backend.

```logql
{container="xray", action="rejected"}
```

Rejected connections в Xray.

```logql
topk(10, sum by (client_ip) (rate({container="haproxy"}[1h])))
```

Top 10 IP адресов по количеству запросов.

**Функции Explore:**
- **Live** (правый верхний угол) - real-time поток логов
- **Show context** - логи вокруг найденной строки
- **Wrap lines** - перенос длинных строк

---

## Создание дашбордов

### Через UI

1. **Dashboards** → **New** → **New dashboard**
2. **Add visualization**
3. Выберите **Data source** (Prometheus или Loki)
4. Введите запрос
5. Настройте визуализацию
6. **Apply**
7. **Save dashboard**

### Импорт JSON

1. **Dashboards** → **New** → **Import**
2. **Upload JSON file** или вставьте JSON напрямую
3. Выберите **Folder** для сохранения
4. **Import**

### Импорт по ID с Grafana.com

1. **Dashboards** → **New** → **Import**
2. Введите ID дашборда
3. **Load**
4. Выберите **Data source** и **Folder**
5. **Import**

---

## Создание панели

### Типы визуализации

| Тип | Применение |
|-----|-----------|
| Time series | Метрики во времени, тренды |
| Stat | Текущее значение с опциональным графиком |
| Gauge | Процентное значение с порогами |
| Bar gauge | Несколько значений рядом с порогами |
| Table | Табличные данные, списки |
| Logs | Отображение логов |
| Pie chart | Распределение долей |
| Bar chart | Сравнение значений |

### Настройка запроса

**Prometheus:**
- **Metrics browser** - визуальный выбор метрик
- **Code** - ручной ввод PromQL
- **Label filters** - фильтры по labels
- **Functions** - rate, sum, avg, irate и т.д.

**Loki:**
- **Label browser** - выбор labels
- **Code** - ручной ввод LogQL
- **Operations** - парсинг, фильтры, агрегация

### Настройка отображения

**Panel options:**
- **Title** - название панели
- **Description** - описание (поддерживает markdown)
- **Transparent** - прозрачный фон

**Standard options:**
- **Unit** - единицы измерения (bytes, percent, reqps, Bps)
- **Min/Max** - диапазон значений
- **Decimals** - количество знаков после запятой

**Thresholds:**
- **Mode** - Absolute или Percentage
- **Levels** - пороги с цветами (зеленый → желтый → красный)

**Value mappings:**
- Замена числовых значений на текст (пример: `0` → `DOWN`, `1` → `UP`)

---

## Переменные (Variables)

Переменные делают дашборды динамическими с возможностью фильтрации по выбранным значениям.

### Создание переменной

1. **Dashboard settings** → **Variables**
2. **Add variable**
3. **Type:**
   - **Query** - значения из метрик
   - **Custom** - заранее определенный список
   - **Interval** - временной интервал
   - **Constant** - неизменяемое значение

### Примеры переменных

**Выбор контейнера:**

```
Type: Query
Query: label_values(container_last_seen, name)
Multi-value: enabled
Include All: enabled
```

Использование в запросе:

```promql
container_cpu_usage_seconds_total{name="$container"}
```

**Выбор HAProxy backend:**

```
Type: Query
Query: label_values(haproxy_server_up, backend)
```

Использование в запросе:

```promql
haproxy_server_up{backend="$backend"}
```

---

## Аннотации (Annotations)

Аннотации отображают события на графиках (деплои, перезапуски, ошибки).

### Встроенные аннотации

- **Annotations & Alerts** - отображает срабатывания алертов Grafana

### Создание аннотации

1. **Dashboard settings** → **Annotations**
2. **Add annotation query**
3. **Data source:** Prometheus или Loki
4. **Query:** запрос для выявления событий

**Пример - события деплоя из логов:**

```logql
{job="docker"} |= "deployment"
```

---

## Настройки типов панелей

### Time Series

**Graph styles:**
- **Lines** - линейный график
- **Bars** - столбцы
- **Points** - точки данных

**Stack series:**
- **None** - отдельные линии
- **Normal** - стек с суммой
- **100%** - процентный стек

**Параметры:**
- **Fill opacity** - прозрачность под графиком (0-100)
- **Point size** - размер точек
- **Line width** - толщина линии

### Stat Panel

**Graph mode:**
- **None** - только числовое значение
- **Area** - значение с маленьким графиком

**Text mode:**
- **Auto** - автоматический выбор
- **Value** - только значение
- **Value and name** - значение и название
- **Name** - только название

**Color mode:**
- **Value** - цвет значения
- **Background** - цвет фона ячейки

### Gauge Panel

**Параметры:**
- **Show threshold labels** - показать метки порогов
- **Show threshold markers** - показать маркеры порогов
- **Orientation** - направление (Auto, Horizontal, Vertical)

---

## Примеры панелей

### CPU Usage (Gauge)

**Query:**

```promql
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Settings:**
- Type: Gauge
- Unit: Percent (0-100)
- Min: 0, Max: 100
- Thresholds: 0 green, 70 yellow, 90 red

### Memory Usage (Gauge)

**Query:**

```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**Settings:**
- Type: Gauge
- Unit: Percent (0-100)
- Thresholds: 0 green, 80 yellow, 95 red

### Network Traffic (Time Series)

**Query A (Incoming):**

```promql
rate(node_network_receive_bytes_total{device!="lo"}[5m])
```

**Query B (Outgoing):**

```promql
-rate(node_network_transmit_bytes_total{device!="lo"}[5m])
```

**Settings:**
- Type: Time series
- Unit: Bytes/sec (Bps)
- Legend: `{{device}} - In/Out`

### HAProxy Requests Rate (Time Series)

**Query:**

```promql
sum by (backend) (rate(haproxy_backend_http_requests_total[5m]))
```

**Settings:**
- Type: Time series
- Unit: reqps
- Legend: `{{backend}}`
- Stack: None

### Container List (Table)

**Query:**

```promql
count by (name) (container_last_seen{name!=""})
```

**Settings:**
- Type: Table
- Sort: by name

### Recent Errors (Logs)

**Query:**

```logql
{job="docker"} |~ "(?i)error|fail|exception"
```

**Settings:**
- Type: Logs
- Show time: Yes
- Wrap lines: Yes

---

## Grafana Alerts

Grafana поддерживает создание собственных алертов в дополнение к Prometheus алертам.

### Создание алерта в панели

1. Создайте панель с запросом
2. **Alert** tab
3. **Create alert rule from this panel**
4. Настройте условия:
   - **Threshold** - пороговое значение
   - **Evaluation** - интервал проверки
   - **For** - минимальная длительность состояния перед срабатыванием

**Примечание:** В стеке используется Alertmanager для основных алертов. Grafana алерты используются для специфичных кейсов.

---

## Sharing и Export

### Snapshot

1. **Share** (иконка с цепью)
2. **Snapshot**
3. **Publish to snapshots.raintank.io**

Создается публичная ссылка на текущее состояние дашборда с данными.

### Export JSON

1. **Dashboard settings** → **JSON Model**
2. Скопируйте JSON содержимое
3. Сохраните в файл для версионирования

### Save as Copy

1. **Dashboard settings**
2. **Make editable** (если дашборд read-only)
3. **Save as...**

---

## Provisioning: Автоматическая настройка

### Datasources

Файл: `~/monitoring-stack/grafana/provisioning/datasources/datasources.yml`

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    access: proxy
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    url: http://loki:3100
    access: proxy
    editable: true

  - name: AlertManager
    type: alertmanager
    url: http://alertmanager:9093
    access: proxy
    editable: true
```

Datasources загружаются автоматически при старте Grafana.

### Dashboards

**Структура директорий:**

```
grafana/
├── provisioning/
│   ├── dashboards/
│   │   └── dashboards.yml     # Конфиг провайдера
│   └── datasources/
│       └── datasources.yml
└── dashboards/
    └── custom/
        └── *.json             # JSON дашбордов
```

**Файл dashboards.yml:**

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: 'Custom'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards/custom
```

JSON дашборды из указанной папки загружаются автоматически при старте контейнера.

---

## Keyboard Shortcuts

| Комбинация | Действие |
|------------|----------|
| `g` + `h` | Home |
| `g` + `d` | Dashboards |
| `g` + `e` | Explore |
| `g` + `a` | Alerting |
| `s` | Open search |
| `t` + `z` | Zoom out time range |
| `t` + `←` | Shift time range back |
| `t` + `→` | Shift time range forward |
| `Esc` | Exit fullscreen/edit |
| `Ctrl` + `S` | Save dashboard |

---

## Troubleshooting

### Панель показывает "No data"

**Проверка:**

1. Datasource подключен: **Administration** → **Data sources** → **Test**
2. Запрос правильный: использование **Explore** с тем же запросом
3. Time range содержит данные
4. Метрики существуют в Prometheus

**Проверка метрик:**

```bash
curl -s http://localhost:9090/api/v1/query?query=up | jq
```

### Дашборд не сохраняется

**Причины:**
- Provisioned дашборд (автоматически загруженный, read-only)
- Недостаточные права доступа

**Решение:**
```bash
# Создание копии с правами редактирования
# Dashboard settings → Save as...

# Или экспортируйте и переимпортируйте JSON
```

### Slow queries

**Оптимизация:**
- Увеличьте шаг времени (step parameter)
- Используйте recording rules для сложных запросов
- Упростите PromQL выражения
- Используйте `rate()` вместо прямых счетчиков

### Grafana не показывает Loki логи

```bash
# Проверка Loki доступности
curl -s http://localhost:3100/ready

# Проверка наличия логов
curl -s 'http://localhost:3100/loki/api/v1/query?query={job="docker"}' | jq '.data.result | length'

# Перезапуск Grafana
docker compose restart grafana
```

---

## Best Practices

### Дашборды

Группируйте по функциональным областям с использованием папок. Overview дашборды отделены от детальных дашбордов.

Используйте переменные для создания одного динамического дашборда вместо множества копий.

Добавляйте описания к панелям через markdown для документирования метрик.

Ограничьте количество панелей на дашборде (рекомендуется 6-12) для быстрой загрузки.

Используйте Row элементы для логической группировки связанных панелей.

### Запросы

Оптимизируйте PromQL:
- `rate()` для counter метрик
- `irate()` для мгновенных значений
- Recording rules для повторно используемых сложных выражений

Фильтруйте по нужным labels, избегайте регулярных выражений где возможно.

Настраивайте refresh интервалы:
- Overview: 30s-1m
- Детальные: 15s-30s
- Исторические: 5m-15m

### Alerts

Избегайте дублирования алертов между Prometheus и Grafana. Используйте Prometheus/Alertmanager для основных алертов.

Grafana алерты применяйте для специфичных случаев требующих комплексной логики.

Группируйте алерты по severity и категориям для упрощения управления.

---

## Установка плагинов

**По умолчанию установлены:**
- Prometheus datasource
- Loki datasource
- Alertmanager datasource
- Dashboard List panel
- Table panel
- Text panel

**Популярные дополнительные:**
- Pie Chart - визуализация долей и процентов
- Worldmap Panel - географические карты
- Clock - часовой виджет

**Установка плагина через docker-compose:**

```yaml
environment:
  - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-piechart-panel
```

Перезапустите контейнер после добавления плагинов:

```bash
docker compose restart grafana
```

---

## Полезные ссылки

Внутренние endpoints:
- Prometheus: `http://prometheus:9090/graph`
- Loki: `http://loki:3100/ready`
- Grafana API: `http://grafana:3200/api/datasources`

External endpoints (через HAProxy):
- Grafana: `http://<EXTERNAL_IP>:4443/`
- Prometheus: `http://<EXTERNAL_IP>:4443/prometheus/`
