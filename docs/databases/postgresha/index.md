# Patroni + etcd + PostgreSQL HA

Автоматизированное управление PostgreSQL high availability кластером через Patroni с использованием etcd в качестве распределенного хранилища конфигурации.

---

## Архитектура кластера

### Компоненты системы

| Компонент | Функция | Порты |
|-----------|---------|-------|
| etcd | Distributed configuration store, консенсус Raft | 2379 (client), 2380 (peer) |
| Patroni | Оркестратор жизненного цикла PostgreSQL | 8008 (REST API) |
| PostgreSQL | СУБД под управлением Patroni | 5432 |

### Топология взаимодействия

```
┌─────────────────────────────────────────┐
│            etcd cluster                 │
│  (distributed consensus storage)        │
│         Leader election                 │
└─────────────────────────────────────────┘
          ↕           ↕           ↕
    ┌─────────┐  ┌─────────┐  ┌─────────┐
    │Patroni 1│  │Patroni 2│  │Patroni 3│
    │  (API)  │  │  (API)  │  │  (API)  │
    └─────────┘  └─────────┘  └─────────┘
          ↕           ↕           ↕
    ┌─────────┐  ┌─────────┐  ┌─────────┐
    │   PG    │  │   PG    │  │   PG    │
    │ Primary │→→│ Replica │  │ Replica │
    └─────────┘  └─────────┘  └─────────┘
         WAL streaming replication
```

---

## Механизм работы etcd

### Консенсус Raft

etcd использует алгоритм Raft для распределенного консенсуса:

- Узлы в состояниях: Leader, Follower, Candidate
- Quorum требует большинство: (N/2 + 1) узлов
- Для 3-х узлов: минимум 2 активных для работы
- Leader управляет записью и репликацией

### Структура данных

```
/service/<cluster_name>/
├── config                    # Глобальная конфигурация кластера
├── leader                    # Текущий primary с TTL lease
├── initialize                # Bootstrap информация
├── members/
│   ├── <node1>              # Состояние узла
│   ├── <node2>
│   └── <node3>
├── failover                  # Триггер управляемого failover
├── sync                      # Synchronous standby state
└── history/                  # Timeline transitions
```

### Lease механизм

```
Leader получает ключ с TTL → Patroni продлевает lease каждые loop_wait
                            ↓
                     Lease expires (TTL)
                            ↓
              Автоматический failover процесс
```

Параметры lease:

| Параметр | Типовое значение | Назначение |
|----------|------------------|------------|
| TTL | 30s | Время жизни leader lease |
| loop_wait | 10s | Интервал проверки и обновления |
| retry_timeout | 10s | Таймаут переподключения к etcd |

---

## Механизм работы Patroni

### Главный цикл управления

```python
while True:
    # 1. Проверка состояния PostgreSQL
    check_postgresql_state()
    
    # 2. Обновление информации в etcd
    update_member_data()
    
    # 3. Попытка получить/продлить leader lease
    try_acquire_leader_lock()
    
    # 4. Выполнение действий в зависимости от роли
    if is_leader():
        manage_as_primary()
    else:
        manage_as_replica()
    
    # 5. Ожидание loop_wait
    sleep(loop_wait)
```

Интервал: `loop_wait` секунд (по умолчанию 10s).

### Состояния узлов

| Состояние | Описание | PostgreSQL роль |
|-----------|----------|-----------------|
| `running` | Оперативный узел | primary или replica |
| `creating replica` | pg_basebackup в процессе | - |
| `stopped` | PostgreSQL остановлен | - |
| `stopping` | Процесс остановки | - |
| `starting` | Процесс запуска | - |
| `restarting` | Перезапуск с новыми параметрами | - |
| `uninitialized` | Новый узел перед инициализацией | - |

### Leader Election

**Процесс получения роли primary:**

```
1. Patroni пытается создать /leader ключ в etcd с TTL
2. Если ключ отсутствует → узел становится leader
3. Patroni выполняет promote PostgreSQL до primary
4. Каждые loop_wait продлевает lease
5. При потере связи с etcd → lease истекает
6. Другие узлы детектируют отсутствие leader
```

**Критерии выбора нового leader при failover:**

- Наименьший replication lag
- Последний LSN (Log Sequence Number)
- Приоритет узла (priority в конфигурации)

---

## Конфигурация etcd

### Базовые параметры

Файл: `/etc/etcd/etcd.conf`

```yaml
name: etcd-node1
data-dir: /var/lib/etcd
listen-client-urls: http://<NODE_IP>:2379,http://127.0.0.1:2379
advertise-client-urls: http://<NODE_IP>:2379
listen-peer-urls: http://<NODE_IP>:2380
initial-advertise-peer-urls: http://<NODE_IP>:2380

initial-cluster: etcd-node1=http://<NODE1_IP>:2380,etcd-node2=http://<NODE2_IP>:2380,etcd-node3=http://<NODE3_IP>:2380
initial-cluster-state: new
initial-cluster-token: etcd-postgres-cluster

heartbeat-interval: 100
election-timeout: 1000
```

### Параметры производительности

| Параметр | Значение | Назначение |
|----------|----------|------------|
| heartbeat-interval | 100ms | Интервал heartbeat между узлами |
| election-timeout | 1000ms | Таймаут для старта новых выборов |
| snapshot-count | 10000 | Количество транзакций для snapshot |
| max-snapshots | 5 | Хранимые snapshots |
| max-wals | 5 | Хранимые WAL файлы |

---

## Конфигурация Patroni

### Основная структура

Файл: `/etc/patroni/patroni.yml`

```yaml
scope: postgres-cluster
namespace: /service/
name: <NODE_NAME>

restapi:
  listen: 0.0.0.0:8008
  connect_address: <NODE_IP>:8008

etcd:
  host: <ETCD_IP>:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        max_connections: 100
        max_locks_per_transaction: 64
        max_prepared_transactions: 0
        max_replication_slots: 10
        max_wal_senders: 10
        max_worker_processes: 8
        wal_level: replica
        wal_log_hints: on
        hot_standby: on
        wal_keep_size: 1GB

  initdb:
    - encoding: UTF8
    - data-checksums

  pg_hba:
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

  users:
    admin:
      password: <ADMIN_PASSWORD>
      options:
        - createrole
        - createdb

postgresql:
  listen: 0.0.0.0:5432
  connect_address: <NODE_IP>:5432
  data_dir: /var/lib/postgresql/14/main
  bin_dir: /usr/lib/postgresql/14/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: <REPLICATION_PASSWORD>
    superuser:
      username: postgres
      password: <POSTGRES_PASSWORD>
  parameters:
    unix_socket_directories: '/var/run/postgresql'

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
```

### Секция DCS (Distributed Configuration Store)

```yaml
dcs:
  ttl: 30
  loop_wait: 10
  retry_timeout: 10
  maximum_lag_on_failover: 1048576
  master_start_timeout: 300
  synchronous_mode: false
  synchronous_mode_strict: false
```

Параметры управления:

| Параметр | Значение | Функция |
|----------|----------|---------|
| ttl | 30 | Leader lease timeout |
| loop_wait | 10 | Цикл проверки состояния |
| retry_timeout | 10 | Переподключение к DCS |
| maximum_lag_on_failover | 1MB | Максимальный lag для автофейловера |
| master_start_timeout | 300 | Таймаут запуска primary |

### Секция bootstrap.postgresql

Параметры применяются только при инициализации кластера:

```yaml
postgresql:
  use_pg_rewind: true
  use_slots: true
  parameters:
    wal_level: replica
    hot_standby: on
    max_wal_senders: 10
    max_replication_slots: 10
    wal_keep_size: 1GB
    wal_log_hints: on
```

**use_pg_rewind:**

Позволяет Patroni использовать pg_rewind для восстановления старого primary как replica после failover без полного pg_basebackup.

Требования:
- `wal_log_hints = on` или data checksums включены
- Superuser доступ к новому primary

**use_slots:**

Replication slots предотвращают удаление WAL до получения репликами.

### Authentication

```yaml
authentication:
  replication:
    username: replicator
    password: <REPLICATION_PASSWORD>
  superuser:
    username: postgres
    password: <POSTGRES_PASSWORD>
```

Patroni использует эти credentials для:
- Управления PostgreSQL
- Настройки репликации
- Выполнения административных операций

---

## Процессы отказоустойчивости

### Автоматический Failover

**Последовательность действий:**

```
1. Primary теряет связь с etcd или падает PostgreSQL
   ↓
2. Leader lease истекает после TTL (30s)
   ↓
3. Patroni на replicas детектируют отсутствие leader
   ↓
4. Replica с минимальным lag выигрывает выборы
   ↓
5. Patroni выполняет promote:
   - pg_ctl promote для PostgreSQL
   - Получает leader lease в etcd
   ↓
6. Остальные replicas переключаются на новый primary
   - Обновляют recovery.conf / standby.signal
   - Перезапускают PostgreSQL
   ↓
7. Старый primary при восстановлении:
   - Детектирует новый timeline
   - Выполняет pg_rewind (если настроен)
   - Становится replica
```

Время failover: обычно 30-40 секунд (TTL + promotion + reconnection).

### Управляемый Switchover

Плановое переключение primary без downtime.

```bash
patronictl switchover postgres-cluster
```

**Процесс:**

```
1. Patroni на primary закрывает новые соединения
   ↓
2. Ожидает завершения активных транзакций
   ↓
3. Выполняет checkpoint
   ↓
4. Replica догоняет primary (синхронизация LSN)
   ↓
5. Primary переводится в standby
   ↓
6. Replica промоутится до primary
   ↓
7. Старый primary переключается на новый
```

Downtime: 0-2 секунды (только переключение клиентов).

### Split-brain Prevention

Patroni предотвращает split-brain через:

**Leader lease в etcd:**
- Только один узел может владеть /leader ключом
- TTL гарантирует автоматическое освобождение
- Узел без lease не принимает write операции

**Timeline tracking:**
- Каждый failover увеличивает timeline
- Старый primary детектирует новый timeline
- Автоматически становится replica

---

## REST API Patroni

### Endpoints для мониторинга

| Endpoint | Код | Описание |
|----------|-----|----------|
| `/` | 200 | Узел оперативен |
| `/primary` | 200 | Узел является primary |
| `/replica` | 200 | Узел является replica |
| `/health` | 200 | Узел здоров (primary или replica) |
| `/readiness` | 200 | Узел готов принимать запросы |
| `/liveness` | 200 | Patroni процесс жив |

### Проверка состояния

```bash
curl http://<NODE_IP>:8008/
```

Ответ при primary роли:

```json
{
  "state": "running",
  "postmaster_start_time": "2025-10-10 10:15:30.123 UTC",
  "role": "master",
  "server_version": 140010,
  "cluster_unlocked": false,
  "xlog": {
    "location": 67108864
  },
  "timeline": 3,
  "database_system_identifier": "7123456789012345678",
  "patroni": {
    "version": "3.1.0",
    "scope": "postgres-cluster"
  }
}
```

### Health checks для балансировщиков

```bash
# Проверка primary
curl -f http://<NODE_IP>:8008/primary || echo "Not primary"

# Проверка replica
curl -f http://<NODE_IP>:8008/replica || echo "Not replica"
```

Коды ответа:
- `200` - условие выполнено
- `503` - условие не выполнено

---

## Управление через patronictl

### Базовые команды

Просмотр состояния кластера:

```bash
patronictl -c /etc/patroni/patroni.yml list postgres-cluster
```

Вывод:

```
+ Cluster: postgres-cluster -------+----+-----------+
| Member | Host          | Role    | State   | TL | Lag in MB |
+--------+---------------+---------+---------+----+-----------+
| node1  | <NODE1_IP>    | Leader  | running |  3 |           |
| node2  | <NODE2_IP>    | Replica | running |  3 |         0 |
| node3  | <NODE3_IP>    | Replica | running |  3 |         0 |
+--------+---------------+---------+---------+----+-----------+
```

### Операции управления

**Switchover:**

```bash
patronictl -c /etc/patroni/patroni.yml switchover postgres-cluster
```

Интерактивный режим выбора узла или:

```bash
patronictl -c /etc/patroni/patroni.yml switchover postgres-cluster --master node1 --candidate node2
```

**Restart узла:**

```bash
patronictl -c /etc/patroni/patroni.yml restart postgres-cluster node1
```

Перезапуск с применением pending параметров:

```bash
patronictl -c /etc/patroni/patroni.yml restart postgres-cluster node1 --pending
```

**Reinitialize replica:**

```bash
patronictl -c /etc/patroni/patroni.yml reinit postgres-cluster node2
```

Выполняет pg_basebackup с текущего primary.

**Reload конфигурации:**

```bash
patronictl -c /etc/patroni/patroni.yml reload postgres-cluster node1
```

**Pause/Resume автоматического управления:**

```bash
# Приостановить автоматику
patronictl -c /etc/patroni/patroni.yml pause postgres-cluster

# Возобновить
patronictl -c /etc/patroni/patroni.yml resume postgres-cluster
```

---

## Синхронная репликация

### Конфигурация synchronous mode

```yaml
bootstrap:
  dcs:
    synchronous_mode: true
    synchronous_mode_strict: false
    synchronous_node_count: 1
```

Параметры:

| Параметр | Значение | Поведение |
|----------|----------|-----------|
| synchronous_mode | true | Включает синхронную репликацию |
| synchronous_mode_strict | false | Primary остается доступным при потере всех sync replicas |
| synchronous_mode_strict | true | Primary переходит в read-only при потере sync replicas |
| synchronous_node_count | N | Количество синхронных replicas |

### Механизм работы

```
Primary commit →→ Ждет подтверждения от N replicas
                          ↓
                   Replica flush WAL
                          ↓
                   Send confirmation
                          ↓
                 Primary commit success
```

**Гарантии:**

- Zero data loss при failover на синхронную реплику
- Increased latency на write операциях
- Primary блокируется если все sync replicas недоступны (strict mode)

### PostgreSQL параметры

```yaml
postgresql:
  parameters:
    synchronous_commit: on
    synchronous_standby_names: '*'
```

Patroni автоматически управляет `synchronous_standby_names` на основе `synchronous_node_count`.

---

## Replication Slots

### Функция slots

Replication slot предотвращает удаление WAL до получения replica, даже если replica длительно недоступна.

**Включение:**

```yaml
bootstrap:
  dcs:
    postgresql:
      use_slots: true
      parameters:
        max_replication_slots: 10
```

### Управление slots

Patroni автоматически создает и удаляет slots при добавлении/удалении replica из кластера.

Проверка slots:

```sql
SELECT slot_name, slot_type, active, restart_lsn 
FROM pg_replication_slots;
```

**Риск:**

Неактивные slots накапливают WAL. Мониторинг `pg_wal` размера критичен.

---

## Мониторинг кластера

### Ключевые метрики

**etcd:**

```bash
# Состояние кластера
etcdctl endpoint health --cluster

# Leader
etcdctl endpoint status --cluster -w table

# Членство
etcdctl member list
```

**Patroni:**

```bash
# Состояние через API
curl http://<NODE_IP>:8008/ | jq

# Лог Patroni
journalctl -u patroni -f

# Проверка всех узлов
for node in <NODE1_IP> <NODE2_IP> <NODE3_IP>; do
  curl -s http://$node:8008/ | jq -r '.role'
done
```

**PostgreSQL:**

```sql
-- Replication status
SELECT * FROM pg_stat_replication;

-- Replication lag
SELECT 
  client_addr,
  state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- Replication slots
SELECT * FROM pg_replication_slots;
```

### Метрики для алертинга

| Метрика | Threshold | Действие |
|---------|-----------|----------|
| Replication lag | > 100MB | Проверить replica нагрузку |
| etcd unavailable | > 30s | Проверить etcd кластер |
| Patroni leader missing | > 60s | Manual intervention |
| PostgreSQL down | immediate | Failover trigger |
| WAL disk usage | > 80% | Проверить slots, очистка |

---

## Troubleshooting

### Primary не выбирается после failover

**Симптомы:**

```bash
patronictl list
# Все узлы в состоянии replica
```

**Причины:**
- etcd недоступен для majority узлов
- Все replicas имеют большой lag > maximum_lag_on_failover
- Pause режим включен

**Диагностика:**

```bash
# Проверка etcd
etcdctl endpoint health --cluster

# Проверка Patroni логов
journalctl -u patroni -n 100

# Проверка pause
patronictl -c /etc/patroni/patroni.yml show-config postgres-cluster
```

**Решение:**

```bash
# Восстановить etcd quorum
systemctl restart etcd

# Manual promote если критично
patronictl -c /etc/patroni/patroni.yml failover postgres-cluster --candidate node2
```

### Replication lag растет

**Проверка lag:**

```sql
SELECT 
  client_addr,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) / 1024 / 1024 AS lag_mb
FROM pg_stat_replication;
```

**Причины:**
- Высокая нагрузка на replica (long queries)
- Медленная сеть между primary и replica
- Недостаточные ресурсы на replica

**Решение:**

Увеличить `max_wal_senders`:

```yaml
postgresql:
  parameters:
    max_wal_senders: 20
```

Оптимизация replica:

```yaml
postgresql:
  parameters:
    max_standby_streaming_delay: 30s
    hot_standby_feedback: on
```

### Старый primary не становится replica

**Симптомы:**

После failover старый primary не подключается как replica.

**Причины:**
- pg_rewind failed
- Timeline несовместимость
- Недостаточные права для pg_rewind

**Диагностика:**

```bash
# Patroni логи
journalctl -u patroni -n 200 | grep rewind

# PostgreSQL логи
tail -n 100 /var/log/postgresql/postgresql-14-main.log
```

**Решение:**

Manual reinitialize:

```bash
patronictl -c /etc/patroni/patroni.yml reinit postgres-cluster node1
```

Или настройка pg_rewind:

```yaml
bootstrap:
  dcs:
    postgresql:
      use_pg_rewind: true
      parameters:
        wal_log_hints: on
```

### etcd потерял quorum

**Симптомы:**

```bash
etcdctl endpoint health
# Errors: context deadline exceeded
```

**Причины:**
- Недоступны >=2 узла из 3
- Network partition
- Disk I/O проблемы

**Диагностика:**

```bash
# Статус кластера
etcdctl endpoint status --cluster

# Логи etcd
journalctl -u etcd -n 100
```

**Решение для disaster recovery:**

Восстановление с одного узла:

```bash
# Остановить etcd на всех узлах
systemctl stop etcd

# На оставшемся узле
etcdctl snapshot save /tmp/backup.db
etcd --force-new-cluster --data-dir=/var/lib/etcd

# Пересоздать кластер
```

### Split-brain детектирован

**Симптомы:**

Два узла считают себя primary.

**Проверка:**

```bash
for node in <NODE1_IP> <NODE2_IP> <NODE3_IP>; do
  echo -n "$node: "
  curl -s http://$node:8008/ | jq -r '.role'
done
```

**Причины:**
- Patroni не может писать в etcd (но может читать)
- Некорректная конфигурация TTL

**Немедленные действия:**

```bash
# Остановить один из primary вручную
systemctl stop patroni postgresql@14-main

# Проверить состояние после
patronictl list
```

**Предотвращение:**

```yaml
dcs:
  ttl: 30
  loop_wait: 10
```

Убедиться: `ttl > 2 * loop_wait`.

---

## Best Practices

**Топология для production:**

- Минимум 3 узла для etcd quorum
- Минимум 3 узла PostgreSQL (1 primary + 2 replicas)
- Dedicated etcd кластер для >5 PostgreSQL узлов
- Separate network для репликации

**Параметры отказоустойчивости:**

```yaml
dcs:
  ttl: 30
  loop_wait: 10
  retry_timeout: 10
  maximum_lag_on_failover: 1048576
```

Соотношение: `ttl >= 3 * loop_wait`.

**Использование pg_rewind:**

```yaml
bootstrap:
  dcs:
    postgresql:
      use_pg_rewind: true
      parameters:
        wal_log_hints: on
```

Минимизирует время восстановления старого primary.

**Мониторинг критичных метрик:**

- Replication lag
- Leader lease status
- etcd cluster health
- Disk space для WAL
- Connection count

**Backup стратегия:**

- Continuous archiving (WAL-G, pgBackRest)
- Regular basebackups
- etcd snapshots
- Patroni конфигурация в VCS

**Security:**

- TLS для etcd client/peer коммуникации
- TLS для PostgreSQL connections
- Firewall rules между узлами
- Encrypted replication (SSL)

**Тестирование failover:**

Регулярные тесты:

```bash
# Плановый switchover
patronictl switchover postgres-cluster

# Симуляция отказа
systemctl stop patroni
```

Измерение RTO (Recovery Time Objective).

**Capacity planning:**

- etcd: минимум 8GB RAM, SSD для data-dir
- Patroni: минимальные требования (~100MB RAM)
- PostgreSQL: по требованиям нагрузки
- Network: минимум 1Gbps для репликации

---

## Полезные команды

### etcd операции

```bash
# Состояние кластера
etcdctl endpoint health --cluster
etcdctl endpoint status --cluster -w table

# Просмотр ключей Patroni
etcdctl get --prefix /service/postgres-cluster/

# Backup
etcdctl snapshot save /tmp/etcd-backup.db
etcdctl snapshot status /tmp/etcd-backup.db

# Список членов
etcdctl member list
```

### Patroni управление

```bash
# Статус кластера
patronictl -c /etc/patroni/patroni.yml list postgres-cluster

# Конфигурация
patronictl -c /etc/patroni/patroni.yml show-config postgres-cluster

# Edit конфигурация
patronictl -c /etc/patroni/patroni.yml edit-config postgres-cluster

# Switchover
patronictl -c /etc/patroni/patroni.yml switchover postgres-cluster

# Failover на конкретный узел
patronictl -c /etc/patroni/patroni.yml failover postgres-cluster --candidate node2

# Перезапуск узла
patronictl -c /etc/patroni/patroni.yml restart postgres-cluster node1

# Reload конфигурации
patronictl -c /etc/patroni/patroni.yml reload postgres-cluster node1

# Reinit replica
patronictl -c /etc/patroni/patroni.yml reinit postgres-cluster node2

# Pause/Resume
patronictl -c /etc/patroni/patroni.yml pause postgres-cluster
patronictl -c /etc/patroni/patroni.yml resume postgres-cluster
```

### PostgreSQL диагностика

```sql
-- Replication status
SELECT * FROM pg_stat_replication;

-- Replication lag
SELECT 
  application_name,
  client_addr,
  state,
  sync_state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) AS send_lag,
  pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn) AS write_lag,
  pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) AS flush_lag,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS replay_lag
FROM pg_stat_replication;

-- Replication slots
SELECT 
  slot_name,
  slot_type,
  active,
  restart_lsn,
  pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS retained_bytes
FROM pg_replication_slots;

-- WAL size
SELECT 
  pg_size_pretty(
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
  ) AS retained_wal
FROM pg_replication_slots;
```

### REST API проверки

```bash
# Роль узла
curl -s http://<NODE_IP>:8008/ | jq -r '.role'

# Полное состояние
curl -s http://<NODE_IP>:8008/ | jq

# Health check для всех узлов
for node in <NODE1_IP> <NODE2_IP> <NODE3_IP>; do
  echo "=== $node ==="
  curl -s http://$node:8008/ | jq '{role, state, timeline, xlog}'
done

# Проверка primary endpoint
curl -f http://<NODE_IP>:8008/primary && echo "Is primary" || echo "Not primary"
```

### Логи и мониторинг

```bash
# Patroni логи
journalctl -u patroni -f
journalctl -u patroni --since "1 hour ago"

# etcd логи
journalctl -u etcd -f

# PostgreSQL логи
tail -f /var/log/postgresql/postgresql-14-main.log

# Системные ресурсы
htop
iostat -x 1
```
