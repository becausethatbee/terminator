# Сводка проекта мониторинга

Полнофункциональный стек мониторинга инфраструктуры с компонентами для сбора метрик, логирования и управления алертами.

---

## Реализованные компоненты

### Этап 1: Метрики и экспортеры

- Node Exporter (системные метрики)
- cAdvisor (Docker контейнеры)
- HAProxy Exporter
- WireGuard Exporter
- Blackbox Exporter (HTTP probes)

**Итого:** 9 targets, ~1000 метрик

### Этап 2: Логирование

- Loki (хранилище логов)
- Promtail (агент сбора)
- Парсинг HAProxy (9 полей)
- Парсинг Xray (6 полей)
- Парсинг Nginx (5 полей)

**Итого:** 11 контейнеров мониторинга, 20+ labels, retention 30 дней

### Этап 3: Визуализация

- Node Exporter Full
- Docker Container & Host Metrics
- HAProxy Servers
- Loki Dashboard
- Prometheus Stats
- Blackbox Exporter
- Infrastructure Overview (custom)

**Итого:** 7 дашбордов

### Этап 4: Алертирование

- Prometheus правила (22 шт, 6 групп)
- Loki правила (9 шт, 1 группа)
- Alertmanager с группировкой
- Telegram интеграция

**Итого:** 31 алерт, 2 уровня severity

---

## Топология стека

```
Prometheus (metrics & logs)
├── Prometheus Rules (alert rules)
├── Loki Rules (log alerts)
│
├── Alertmanager (alert routing)
│   │
│   └── Telegram (notifications)
│
├── Grafana (visualization)
│   │
│   └── Dashboards & custom JSON
│
Data Export
├── Exporters (5 types)
├── Promtail (log collection)
└── Storage (persistent volumes)
```

Поток данных:

| Источник | Обработка | Назначение |
|----------|-----------|-----------|
| Prometheus rules | Alertmanager | Telegram bot |
| Loki rules | Alertmanager | Telegram bot |
| Scrapers | Prometheus TSDB | Storage |
| Logs | Loki ingestion | Storage |

---

## Компоненты

| Компонент | Версия | Порт | Назначение |
|-----------|--------|------|------------|
| Prometheus | 3.7.1 | 9090 | Метрики, алерты |
| Grafana | latest | 3200 (external: 4443) | Визуализация |
| Loki | latest | 3100 | Логи, алерты |
| Promtail | 3.5.7 | - | Сбор логов |
| Alertmanager | 0.27.0 | 9093 | Маршрутизация |
| Telegram Bot | 0.4.3 | 9094 | Уведомления |
| Node Exporter | 1.8.2 | 9100 | ОС метрики |
| cAdvisor | 0.49.1 | 9200 | Docker метрики |
| HAProxy Exporter | 0.15.0 | 9101 | HAProxy метрики |
| Blackbox Exporter | 0.25.0 | 9115 | HTTP probes |

---

## Доступ к сервисам

### Внешний доступ (через HAProxy)

| Сервис | URL | Аутентификация |
|--------|-----|----------------|
| Grafana | http://<EXTERNAL_IP>:4443 | admin/admin |

### Локальный доступ

| Сервис | Endpoint |
|--------|----------|
| Prometheus | http://localhost:9090 |
| Alertmanager | http://localhost:9093 |
| Loki | http://localhost:3100 |
| Node Exporter | http://localhost:9100 |
| cAdvisor | http://localhost:9200 |

---

## Метрики и статистика

### Prometheus

| Параметр | Значение |
|----------|----------|
| Active targets | 9 |
| Metrics | ~1000 |
| Retention | 30 дней |
| Storage | ~900 MB |
| Scrape interval | 15s |

### Loki

| Параметр | Значение |
|----------|----------|
| Jobs | 4 (docker, system_critical, security, varlogs) |
| Containers | 11 (monitoring stack) |
| Labels | 20+ |
| Retention | 30 дней |
| Storage | ~100 MB |

### Alerting

| Параметр | Значение |
|---------|----------|
| Prometheus rules | 22 (6 групп) |
| Loki rules | 9 (1 группа) |
| Severity levels | 2 (critical, warning) |
| Routes | 2 (по severity) |

---

## Покрытие мониторингом

### Инфраструктура

- Хост система (CPU, RAM, Disk, Network)
- Docker контейнеры (11 мониторинга + другие)
- Системные логи
- Security события

### Приложения

- HAProxy (метрики и логи)
- WireGuard (метрики)
- Nginx (логи)
- Prometheus (self-monitoring)
- Grafana
- Telegram бот

---

## Правила алертов

### System Resources (7 алертов)

| Алерт | Порог |
|-------|-------|
| Host Down | Target unreachable |
| High CPU | >85% |
| Critical CPU | >95% |
| High Memory | >85% |
| Critical Memory | >95% |
| Disk Space Warning | <20% |
| Disk Space Critical | <10% |

### Services (4 алерта)

HAProxy Down/Backend Down, Prometheus Down, Grafana Down.

### Network Traffic (3 алерта)

High Traffic In/Out (>100 MB/s), Traffic Spike (5x baseline).

### HAProxy Traffic (5 алертов)

High Request Rate (>500 req/s), Critical Rate (>1000 req/s), Request Spike (10x baseline), High Error Rate (>5% 5xx), Slow Responses (>5s).

### WireGuard (3 алерта)

High Traffic (>50 MB/s), Peer Inactive (>5 min), All Peers Down.

### Security (9 алертов)

SSH Brute Force (>20 failed/5m), Xray Brute Force (>10 rejected/s), Xray Critical Rejections (>50/s), Web Scanning (>5 4xx/s from IP), Web Attack (>50 4xx/s total), Fail2Ban Active (>3 bans/5m), Kernel Panic, OOM Killer, HAProxy Errors.

---

## Файловая структура

```
~/monitoring-stack/
├── docker-compose.yml
├── prometheus/
│   ├── config/
│   │   └── prometheus.yml
│   └── rules/
│       ├── resources.yml
│       └── traffic.yml
├── loki/
│   ├── config/
│   │   └── loki-config.yml
│   └── rules/
│       └── fake/
│           └── security.yml
├── promtail/
│   └── config/
│       └── promtail-config.yml
├── alertmanager/
│   ├── config/
│   │   └── alertmanager.yml
│   └── telegram-data/
│       └── bot.db
├── blackbox-exporter/
│   └── config/
│       └── blackbox.yml
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   └── dashboards/
│   └── dashboards/
│       └── custom/
│           └── infrastructure-overview.json
└── data/
    ├── prometheus/
    ├── grafana/
    └── loki/

~/docker-haproxy/
├── docker-compose.yml
├── haproxy.cfg
└── data/
    └── certificates/
```

---

## Управление стеком

### Запуск и остановка

```bash
cd ~/monitoring-stack
docker compose up -d
```

Запуск всех сервисов.

```bash
docker compose stop
```

Остановка контейнеров.

```bash
docker compose restart prometheus
```

Перезапуск конкретного сервиса.

```bash
docker compose logs -f grafana
```

Просмотр логов в реальном времени.

### Проверка здоровья

```bash
curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job) - \(.health)"'
```

Список targets в Prometheus.

```bash
curl -s http://localhost:3100/ready
```

Проверка готовности Loki.

```bash
curl -s http://localhost:9093/api/v2/status | jq '.cluster.status'
```

Статус Alertmanager.

```bash
docker ps --format "table {{.Names}}\t{{.Status}}"
```

Список всех контейнеров и их статус.

### Backup

```bash
docker compose stop
```

Остановка перед резервной копией.

```bash
tar -czf monitoring-backup-$(date +%Y%m%d).tar.gz \
  ~/monitoring-stack/data \
  ~/monitoring-stack/prometheus/rules \
  ~/monitoring-stack/loki/rules \
  ~/monitoring-stack/alertmanager
```

Создание архива данных.

```bash
docker compose start
```

Запуск после завершения backup.

---

## Использование ресурсов

| Сервис | CPU | RAM | Disk |
|--------|-----|-----|------|
| Prometheus | ~2% | 400 MB | 900 MB |
| Grafana | ~1% | 150 MB | 136 MB |
| Loki | ~1% | 200 MB | 104 MB |
| Promtail | ~1% | 50 MB | - |
| Exporters | <1% | 50 MB | - |
| **Итого** | ~5-10% | ~1 GB | ~1.2 GB |

Сетевой трафик:
- Метрики: ~1-2 MB/min
- Логи: ~5-10 MB/min
- Итого: ~10-15 MB/min (~20 GB/month)

---

## Принципы реализации

### Безопасность

- Базовая аутентификация HAProxy
- Внутренняя сеть Docker
- Минимальные exposed порты
- Alertmanager за Telegram ботом

### Надежность

- Health checks для всех сервисов
- Restart policies
- Persistent volumes
- Retention policies

### Масштабируемость

- Модульная структура конфигов
- Отдельные files для правил
- Provisioning Grafana
- Docker Compose оркестрация

### Мониторинг

- Self-monitoring Prometheus
- Алерты на критичные сервисы
- Логирование всех компонентов
- Централизованные логи

---

## Ограничения текущей реализации

### Telegram бот - режим уведомлений

Бот работает только в режиме отправки уведомлений об алертах. Интерактивные команды недоступны.

Бот использует Alertmanager API v1, но установленный Alertmanager 0.27.0 поддерживает только API v2. API v1 возвращает статус 410 Gone при попытке выполнить команду. Для полной функциональности требуется пересмотреть компоненты.

### Xray требуется кастомный экспортер

Необходимо разработать экспортер для сбора метрик через Stats API Xray. Требуется продумать логирование подключений, bandwidth utilization, user activity tracking и интеграцию с Prometheus.

### Single instance

Нет high availability, single point of failure. Для production требуется кластерная конфигурация.

---

## Будущие улучшения

### Настройка мониторинга security логов

Интеграция логов SSH, sudo, системной аутентификации с парсингом в Loki. Создание правил для обнаружения подозрительной активности и аномалий в доступе.

### WireGuard Exporter переработка

Текущая реализация требует оптимизации для корректного сбора метрик подключенных peers. Необходимо добавить дополнительные параметры трафика, времени последнего handshake и статуса подключения.

### Xray Exporter разработка

Разработка кастомного экспортера для сбора метрик через Stats API Xray. Включает логирование подключений, tracking bandwidth utilization и user activity. Интеграция с Prometheus для фулл-стэка мониторинга.

### Дополнительные дашборды в Grafana

Создание специализированных дашбордов для WireGuard, Xray с детализированной статистикой. Разработка dashboard для анализа security логов с timeline и top событий.

### Улучшенное отображение логов в Grafana

Настройка подсветки синтаксиса для логов с выделением критических уровней (ERROR, CRITICAL) красным, предупреждений (WARNING) желтым, информационных сообщений зеленым. Интеграция с LogQL парсингом для автоматического выделения по уровням severity.

### Fine-tuning алертов

Калибровка пороговых значений алертов под конкретные характеристики инфраструктуры. Анализ baseline метрик и установка оптимальных threshold значений для снижения false positives.

### Перевод Grafana на HTTPS

Настройка SSL/TLS сертификатов для Grafana через HAProxy. Требуется получение сертификатов (Let's Encrypt) и конфигурация HTTPS listener для безопасного доступа к интерфейсу мониторинга.

### Infrastructure as Code

Миграция конфигурации на Terraform/Ansible для управления инфраструктурой как кодом. Включает provisioning мониторинг стека, HAProxy, datasources и dashboards Grafana.

### Distributed tracing

Интеграция Jaeger или Tempo для распределенного трейсинга запросов в инфраструктуре.

---

## Документация проекта

Реализованные документы:

**monitoring-stack-setup.md**
- Развертывание мониторинг стека
- Docker Compose конфигурация
- Prometheus, Loki, Grafana setup
- HAProxy интеграция
- Troubleshooting

**GRAFANA_DASHBOARDS.md**
- Работа с Grafana
- Импортированные дашборды
- Создание панелей и переменных
- Примеры запросов (PromQL, LogQL)
- Provisioning и best practices

**METRICS_EXPORTERS.md**
- Настройка Prometheus
- Конфигурация экспортеров (5 типов)
- PromQL примеры
- Troubleshooting

**LOGS_LOKI_PROMTAIL.md**
- Настройка Loki и Promtail
- Парсинг логов (HAProxy, Xray, Nginx)
- 30+ примеры LogQL
- Извлеченные labels

**ALERTS.md**
- Prometheus правила (22 шт)
- Loki правила (9 шт)
- Alertmanager конфигурация
- Telegram бот setup
- Тестирование алертов

---

## Справочные ссылки

### Документация проектов

- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/
- Loki: https://grafana.com/docs/loki/
- Alertmanager: https://prometheus.io/docs/alerting/

### Готовые дашборды

- Grafana.com: https://grafana.com/grafana/dashboards/
- Node Exporter Full: 1860
- Docker Monitoring: 10619
- HAProxy: 367

### Сообщества

- Prometheus Users: https://groups.google.com/forum/#!forum/prometheus-users
- Grafana Community: https://community.grafana.com/
