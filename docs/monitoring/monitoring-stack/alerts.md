# Настройка алертов с Prometheus, Loki и Alertmanager

Конфигурация системы оповещений для мониторинга инфраструктуры.

## Архитектура алертов

```
Prometheus Rules (метрики) ─┐
                            ├──> Alertmanager ──> Telegram Bot ──> Telegram
Loki Ruler (логи) ──────────┘
```

---

## Компоненты

| Компонент | Назначение | Правил |
|-----------|-----------|--------|
| Prometheus | Алерты на метриках | 22 |
| Loki Ruler | Алерты на логах | 9 |
| Alertmanager | Маршрутизация и группировка | - |
| Telegram Bot | Отправка уведомлений | - |

---

## Prometheus Rules

Расположение: `~/monitoring-stack/prometheus/rules/`

### Resources (7 правил)

**Файл:** `resources.yml`

```yaml
groups:
  - name: system_resources
    interval: 30s
    rules:
      - alert: HostDown
        expr: up{job="node-exporter"} == 0
        for: 1m
        
      - alert: HighCPU
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85
        for: 5m
        
      - alert: CriticalCPU
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 95
        for: 2m
        
      - alert: HighMemory / CriticalMemory
      - alert: DiskSpaceWarning / DiskSpaceCritical

  - name: critical_services
    rules:
      - alert: HAProxyDown / HAProxyBackendDown
      - alert: PrometheusDown / GrafanaDown
```

### Traffic (15 правил)

**Файл:** `traffic.yml`

**Network Traffic (3):**
- HighNetworkTrafficIn / Out (>100 MB/s)
- NetworkTrafficSpike (5x baseline)

**HAProxy Traffic (5):**
- HAProxyHighRequestRate (>500 req/s)
- HAProxyCriticalRequestRate (>1000 req/s)
- HAProxyRequestSpike (10x baseline)
- HAProxyHighErrorRate (>5% 5xx)
- HAProxySlowResponses (>5s avg)

**WireGuard Traffic (3):**
- WireGuardHighTraffic (>50 MB/s)
- WireGuardPeerInactive (>5 min)
- WireGuardAllPeersDown

---

## Loki Rules

**Loki Ruler** - встроенный компонент Loki для оценки правил алертов на логах. Требует отдельной конфигурации в `loki-config.yml`:

```yaml
ruler:
  alertmanager_url: http://alertmanager:9093
  rule_path: /etc/loki/rules
  enable_api: true
  storage:
    type: local
    local:
      directory: /etc/loki/rules
  ring:
    kvstore:
      store: inmemory
```

Расположение: `~/monitoring-stack/loki/rules/fake/`

### Security (9 правил)

**Файл:** `security.yml`

```yaml
groups:
  - name: security_alerts
    interval: 30s
    rules:
      - alert: SSHBruteForce
        expr: sum(count_over_time({job="security"} |~ `(?i)failed password` [5m])) > 20
        for: 1m
        
      - alert: XrayBruteForce
        expr: sum(rate({container="xray", action="rejected"}[1m])) > 10
        for: 2m
        
      - alert: XrayCriticalRejections
        expr: sum(rate({container="xray", action="rejected"}[1m])) > 50
        for: 1m
        
      - alert: WebScanning / WebAttack
      - alert: Fail2BanActive
      - alert: KernelPanic / OOMKiller
      - alert: HAProxyErrors
```

---

## Alertmanager конфигурация

**Файл:** `~/monitoring-stack/alertmanager/config/alertmanager.yml`

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: telegram
  group_by: ['alertname', 'severity', 'category']
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 4h
  
  routes:
    - receiver: telegram
      match:
        severity: critical
      group_wait: 10s
      repeat_interval: 1h
      
    - receiver: telegram
      match:
        severity: warning
      group_wait: 30s
      repeat_interval: 4h

inhibit_rules:
  # Critical подавляет warning для того же хоста
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: ['instance']
    
  # HostDown подавляет ServiceDown
  - source_match:
      alertname: HostDown
    target_match:
      alertname: ServiceDown
    equal: ['instance']

receivers:
  - name: telegram
    webhook_configs:
      - url: 'http://alertmanager-telegram:8080'
        send_resolved: true
```

---

## Telegram Bot конфигурация

**Docker Compose секция:**

```yaml
  alertmanager-telegram:
    image: metalmatze/alertmanager-bot:0.4.3
    container_name: alertmanager-telegram
    environment:
      - TELEGRAM_ADMIN=<TELEGRAM_ADMIN_ID>
      - TELEGRAM_TOKEN=<TELEGRAM_BOT_TOKEN>
      - ALERTMANAGER_URL=http://alertmanager:9093
      - STORE=bolt
      - BOLT_PATH=/data/bot.db
      - LISTEN_ADDR=0.0.0.0:8080
    volumes:
      - ./alertmanager/telegram-data:/data
    ports:
      - "9094:8080"
    restart: unless-stopped
```

**Создание Telegram бота и получение ID:**

1. **Создание бота:**
   - Напишите @BotFather в Telegram
   - Отправьте команду `/newbot`
   - Выберите имя бота (например, "MyAlertBot")
   - Выберите юзернейм бота (должен заканчиваться на "bot", например "MyAlertBot_12345")
   - BotFather выдаст **TOKEN** (сохраните его в `TELEGRAM_TOKEN`)

2. **Получение своего Telegram ID:**
   - Напишите только что созданному боту любое сообщение
   - Отправьте `/start`
   - Получите ответ с вашим ID
   - Или напишите @userinfobot и он покажет ваш ID
   - Укажите ID в переменной `TELEGRAM_ADMIN`

---

## Регистрация бота

1. Найдите бота в Telegram (по токену)
2. Отправьте `/start`
3. Бот должен ответить и зарегистрировать вас

**Команды бота:**
- `/status` - статус Alertmanager
- `/alerts` - список активных алертов
- `/silences` - список заглушенных алертов
- `/chats` - список подписанных чатов

**Ограничение:** Бот работает только в режиме **отправки уведомлений об алертах**. Интерактивные команды недоступны. 

**Причина:** Бот использует Alertmanager API v1, но установленный Alertmanager 0.27.0 поддерживает только API v2. API v1 возвращает статус 410 Gone при попытке выполнить команду.

**Доступно:**
- Webhook уведомления об алертах (`send_resolved: true`)

**Недоступно:**
- `/status` - команда для проверки статуса
- `/alerts` - список активных алертов
- `/silences` - список заглушенных алертов
- `/chats` - список подписанных чатов

---

## Проверка работы

### Prometheus правила

```bash
# Список групп
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[] | {name: .name, rules: .rules | length}'

# Активные алерты
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state != "inactive")'

# Web UI
http://<SERVER_IP>:9090/alerts
```

### Loki правила

```bash
# Список групп
curl -s http://localhost:3100/prometheus/api/v1/rules | jq '.data.groups[] | {name: .name, rules: .rules | length}'

# Активные алерты
curl -s http://localhost:3100/prometheus/api/v1/alerts | jq '.data.alerts[] | select(.state != "inactive")'
```

### Alertmanager

```bash
# Статус
curl -s http://localhost:9093/api/v2/status | jq '.cluster.status'

# Активные алерты
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | {alert: .labels.alertname, status: .status.state}'

# Web UI
http://<SERVER_IP>:9093/#/alerts
```

---

## Тестирование алертов

### CPU нагрузка

```bash
# Создаем нагрузку на 6 минут
stress-ng --cpu 10 --timeout 360s &

# Мониторим
watch -n 5 'curl -s http://localhost:9090/api/v1/alerts | jq ".data.alerts[] | select(.labels.alertname == \"HighCPU\")"'
```

### SSH Brute Force

```bash
# Генерируем 30 failed попыток
for i in {1..30}; do 
  ssh -o ConnectTimeout=1 fakeuser@localhost 2>&1
  sleep 0.2
done

# Проверяем алерт через 2 минуты
curl -s http://localhost:3100/prometheus/api/v1/alerts | jq '.data.alerts[] | select(.labels.alertname == "SSHBruteForce")'
```

### Ручной тест

```bash
# Отправляем тестовый алерт
curl -X POST http://localhost:9093/api/v2/alerts -d '[
  {
    "labels": {"alertname": "TestAlert", "severity": "critical"},
    "annotations": {"summary": "Test Alert"}
  }
]'
```

Должен прийти в Telegram через 10-30 секунд.

---

## Troubleshooting

### Алерты не приходят в Telegram

**1. Проверьте регистрацию бота:**
```bash
docker logs alertmanager-telegram | grep "registered new chat"
```

Если нет - отправьте `/start` боту.

**2. Проверьте TELEGRAM_ADMIN:**
```bash
docker exec alertmanager-telegram env | grep TELEGRAM_ADMIN

# Ваш ID должен совпадать
# Получить ID: напишите @userinfobot
```

**3. Проверьте связь Alertmanager → Bot:**
```bash
docker exec alertmanager curl -s http://alertmanager-telegram:8080
# Должно вернуть: OK
```

**4. Логи бота:**
```bash
docker logs alertmanager-telegram -f
# Должны быть сообщения о получении алертов
```

### Prometheus не загружает правила

```bash
# Проверка синтаксиса
docker exec prometheus promtool check rules /etc/prometheus/rules/resources.yml

# Логи Prometheus
docker logs prometheus 2>&1 | grep -i error | tail -20

# Убедитесь что в prometheus.yml есть:
rule_files:
  - '/etc/prometheus/rules/*.yml'
```

### Loki Ruler не работает

```bash
# Проверьте структуру директорий
ls -la ~/monitoring-stack/loki/rules/fake/

# Должен быть файл security.yml в поддиректории fake/

# Проверьте конфиг Loki
docker exec loki cat /etc/loki/loki-config.yml | grep -A10 "ruler:"

# Логи Loki
docker logs loki | grep -i ruler
```

---

## Настройка severity levels

**Critical (немедленно, повтор каждый час):**
- HostDown
- HAProxyDown / BackendDown
- CriticalCPU / CriticalMemory
- DiskSpaceCritical
- SSHBruteForce
- XrayCriticalRejections
- KernelPanic / OOMKiller

**Warning (30 сек группировка, повтор каждые 4 часа):**
- HighCPU / HighMemory
- DiskSpaceWarning
- HAProxy/Network issues
- WebScanning
- Fail2BanActive

---

## Best Practices

### Threshold настройка

**Начальные значения консервативны:**
- CPU: 85% warning, 95% critical
- Memory: 85% warning, 95% critical
- Disk: 20% warning, 10% critical

Подстраивайте под свою инфраструктуру.

### Group настройки

**group_wait:**
- Critical: 10s (быстро)
- Warning: 30s (группируем)

**repeat_interval:**
- Critical: 1h (часто напоминаем)
- Warning: 4h (реже)

### Inhibit rules

Используйте для уменьшения шума:
- Critical подавляет warning
- HostDown подавляет ServiceDown

---

## Структура проекта

```
~/monitoring-stack/
├── prometheus/
│   └── rules/
│       ├── resources.yml     # 7 правил
│       └── traffic.yml       # 15 правил
├── loki/
│   └── rules/
│       └── fake/
│           └── security.yml  # 9 правил
├── alertmanager/
│   ├── config/
│   │   └── alertmanager.yml
│   └── telegram-data/
│       └── bot.db
└── docker-compose.yml
```

---
