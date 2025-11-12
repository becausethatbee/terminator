# etcdctl - Управление etcd

Исчерпывающий справочник по etcdctl - CLI для управления etcd key-value хранилищем Kubernetes.

## Предварительные требования

- Установленный etcdctl
- Доступ к etcd endpoints
- Client certificates для аутентификации
- etcd версии 3.x

---

## Версии API

### etcd API v3

```bash
export ETCDCTL_API=3
```

API v3 используется по умолчанию в современных версиях. Устанавливать переменную обязательно для совместимости.

**Проверка версии:**

```bash
etcdctl version
etcdctl endpoint status
```

---

## Глобальные параметры

### Аутентификация

```bash
etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  <COMMAND>
```

| Параметр | Описание |
|----------|----------|
| `--endpoints` | Список etcd endpoints |
| `--cacert` | CA certificate |
| `--cert` | Client certificate |
| `--key` | Client private key |

### Environment variables

```bash
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_API=3
```

Установка переменных окружения для упрощения команд.

**После установки:**

```bash
etcdctl endpoint status
etcdctl member list
```

Команды без длинных параметров.

### Формат вывода

```bash
etcdctl get <KEY> -w=json
etcdctl get <KEY> -w=simple
etcdctl get <KEY> -w=table
etcdctl get <KEY> -w=fields
```

| Формат | Описание |
|--------|----------|
| `simple` | Key-value pairs (default) |
| `json` | JSON format |
| `table` | Табличный вывод |
| `fields` | Field-based output |

---

## Операции с данными

### GET - чтение данных

```bash
etcdctl get <KEY>
etcdctl get <KEY> --print-value-only
etcdctl get <KEY> --hex
```

**Чтение конкретного ключа:**

| Флаг | Описание |
|------|----------|
| `--print-value-only` | Только значение без ключа |
| `--hex` | Вывод в hex формате |
| `--rev=<N>` | Чтение на определенной ревизии |
| `--keys-only` | Только ключи без значений |

### GET с префиксом

```bash
etcdctl get <PREFIX> --prefix
etcdctl get <PREFIX> --prefix --keys-only
etcdctl get <PREFIX> --prefix --limit=10
```

Чтение всех ключей с определенным префиксом.

### GET диапазон

```bash
etcdctl get <START_KEY> <END_KEY>
etcdctl get "" --prefix
```

Чтение диапазона ключей. Пустая строка с `--prefix` читает все ключи.

### PUT - запись данных

```bash
etcdctl put <KEY> <VALUE>
etcdctl put <KEY> <VALUE> --lease=<LEASE_ID>
etcdctl put <KEY> <VALUE> --prev-kv
```

| Флаг | Описание |
|------|----------|
| `--lease` | Привязка к lease |
| `--prev-kv` | Вернуть предыдущее значение |
| `--ignore-value` | Обновить только metadata |
| `--ignore-lease` | Не изменять lease |

### DELETE - удаление данных

```bash
etcdctl del <KEY>
etcdctl del <KEY> --prev-kv
etcdctl del <PREFIX> --prefix
etcdctl del <START_KEY> <END_KEY>
```

| Флаг | Описание |
|------|----------|
| `--prev-kv` | Вернуть удаленное значение |
| `--prefix` | Удалить все с префиксом |
| `--from-key` | Удалить начиная с ключа |

---

## Watch - мониторинг изменений

### Базовый watch

```bash
etcdctl watch <KEY>
etcdctl watch <PREFIX> --prefix
etcdctl watch "" --prefix
```

Отслеживание изменений ключей в реальном времени.

### Watch с ревизией

```bash
etcdctl watch <KEY> --rev=<N>
etcdctl watch <KEY> --rev=0
```

Воспроизведение истории изменений с определенной ревизии.

### Watch диапазона

```bash
etcdctl watch <START_KEY> <END_KEY>
```

Мониторинг диапазона ключей.

### Watch параметры

| Флаг | Описание |
|------|----------|
| `--rev` | Начальная ревизия |
| `--prefix` | Watch с префиксом |
| `--prev-kv` | Включить предыдущие значения |
| `--interactive` | Интерактивный режим |

---

## Транзакции

### TXN - атомарные операции

```bash
etcdctl txn <<EOF
compare:
mod("key1") = "5"

success:
put key1 "new-value"

failure:
get key1
EOF
```

Условное выполнение операций.

**Операции сравнения:**

| Операция | Описание |
|----------|----------|
| `mod(<KEY>)` | Modification revision |
| `create(<KEY>)` | Creation revision |
| `version(<KEY>)` | Version (updates count) |
| `value(<KEY>)` | Value comparison |
| `lease(<KEY>)` | Lease comparison |

**Операторы:**

| Оператор | Описание |
|----------|----------|
| `=` | Равно |
| `!=` | Не равно |
| `>` | Больше |
| `<` | Меньше |

---

## Lease - управление TTL

### Создание lease

```bash
etcdctl lease grant <TTL_SECONDS>
```

Создание lease с TTL в секундах. Возвращает lease ID.

### Привязка к lease

```bash
etcdctl put <KEY> <VALUE> --lease=<LEASE_ID>
```

Ключ будет удален автоматически по истечении TTL.

### Управление lease

```bash
etcdctl lease list
etcdctl lease timetolive <LEASE_ID>
etcdctl lease timetolive <LEASE_ID> --keys
etcdctl lease keep-alive <LEASE_ID>
etcdctl lease revoke <LEASE_ID>
```

| Команда | Описание |
|---------|----------|
| `list` | Список всех активных lease |
| `timetolive` | Оставшееся время lease |
| `keep-alive` | Продление lease |
| `revoke` | Отмена lease и удаление ключей |

---

## Cluster управление

### Member list

```bash
etcdctl member list
etcdctl member list -w=table
```

Список членов etcd кластера.

**Вывод:**

| Поле | Описание |
|------|----------|
| ID | Member ID (hex) |
| Status | started/unstarted |
| Name | Member name |
| Peer URLs | Peer communication URLs |
| Client URLs | Client access URLs |

### Member add

```bash
etcdctl member add <NAME> --peer-urls=<PEER_URL>
```

Добавление нового member в кластер.

**Процесс:**
1. Добавление member через etcdctl
2. Запуск etcd на новой node
3. Автоматическая синхронизация данных

### Member remove

```bash
etcdctl member remove <MEMBER_ID>
```

Удаление member из кластера по ID.

### Member update

```bash
etcdctl member update <MEMBER_ID> --peer-urls=<NEW_PEER_URL>
```

Обновление peer URLs существующего member.

---

## Endpoint проверки

### Status

```bash
etcdctl endpoint status
etcdctl endpoint status --endpoints=<URL1>,<URL2>,<URL3>
etcdctl endpoint status -w=table
```

Статус endpoints кластера.

**Информация:**

| Поле | Описание |
|------|----------|
| Endpoint | URL endpoint |
| ID | Member ID |
| Version | etcd version |
| DB Size | Database size |
| Is Leader | Leader status |
| Raft Term | Current term |
| Raft Index | Commit index |

### Health

```bash
etcdctl endpoint health
etcdctl endpoint health -w=table
```

Проверка здоровья endpoints.

**Статусы:**
- `healthy` - endpoint доступен и работает
- `unhealthy` - endpoint недоступен или имеет проблемы

### Hashkv

```bash
etcdctl endpoint hashkv
```

Hash значения всех ключей на каждом member. Используется для проверки консистентности данных.

---

## Backup и Restore

### Snapshot save

```bash
etcdctl snapshot save <FILENAME>
etcdctl snapshot save /backup/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db
```

Создание snapshot всей базы etcd.

**Рекомендуемая практика:**

```bash
#!/bin/bash
BACKUP_DIR=/backup/etcd
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
etcdctl snapshot save ${BACKUP_DIR}/snapshot-${TIMESTAMP}.db
find ${BACKUP_DIR} -name "snapshot-*.db" -mtime +7 -delete
```

Автоматический backup с ротацией.

### Snapshot status

```bash
etcdctl snapshot status <FILENAME>
etcdctl snapshot status <FILENAME> -w=table
```

Информация о snapshot файле.

**Вывод:**

| Поле | Описание |
|------|----------|
| Hash | Checksum snapshot |
| Revision | Database revision |
| Total Keys | Количество ключей |
| Total Size | Размер в байтах |

### Snapshot restore

```bash
etcdctl snapshot restore <FILENAME> \
  --name=<MEMBER_NAME> \
  --initial-cluster=<CLUSTER_CONFIG> \
  --initial-advertise-peer-urls=<PEER_URL> \
  --data-dir=<DATA_DIR>
```

Восстановление etcd из snapshot.

**Параметры restore:**

| Параметр | Описание |
|----------|----------|
| `--name` | Member name |
| `--data-dir` | Новая data директория |
| `--initial-cluster` | Initial cluster configuration |
| `--initial-cluster-token` | Cluster token |
| `--initial-advertise-peer-urls` | Peer URLs |
| `--skip-hash-check` | Пропустить проверку hash |

**Процесс восстановления:**

1. Остановка etcd на всех members
2. Удаление старых data directories
3. Restore snapshot на каждом member
4. Запуск etcd с новой конфигурацией

---

## Compaction

### Manual compaction

```bash
etcdctl compact <REVISION>
etcdctl compact $(etcdctl endpoint status --write-out="json" | jq -r '.[0].Status.header.revision')
```

Удаление исторических ревизий до указанной.

### Auto-compaction

```bash
etcd --auto-compaction-retention=1
etcd --auto-compaction-mode=periodic
```

Автоматическая compaction в etcd server.

| Mode | Описание |
|------|----------|
| `periodic` | По времени (часы) |
| `revision` | По количеству ревизий |

---

## Defragmentation

### Defrag

```bash
etcdctl defrag
etcdctl defrag --endpoints=<URL1>,<URL2>,<URL3>
```

Дефрагментация базы данных для освобождения места.

**Когда использовать:**
- После массового удаления ключей
- После compaction
- При большом размере DB Size vs Used Size

**Рекомендации:**
- Выполнять на одном member за раз
- Проверять disk space перед defrag
- Выполнять в maintenance window

---

## Alarm управление

### Список alarms

```bash
etcdctl alarm list
```

Просмотр активных alarms в кластере.

**Типы alarms:**

| Alarm | Описание |
|-------|----------|
| `NOSPACE` | Закончилось место на диске |
| `CORRUPT` | Обнаружена corruption данных |

### Disarm alarms

```bash
etcdctl alarm disarm
etcdctl alarm disarm --alarm-type=<TYPE>
```

Снятие alarms после устранения проблемы.

**Процесс для NOSPACE:**

1. Освобождение места на диске
2. Defragmentation базы
3. Disarm alarm

```bash
etcdctl defrag
etcdctl alarm disarm
```

---

## Role-Based Access Control

### User управление

```bash
etcdctl user add <USERNAME>
etcdctl user add <USERNAME> --no-password
etcdctl user delete <USERNAME>
etcdctl user list
etcdctl user get <USERNAME>
```

Создание и управление пользователями.

### Password управление

```bash
etcdctl user passwd <USERNAME>
etcdctl user passwd <USERNAME> --interactive=false --new-password=<PASSWORD>
```

Изменение паролей пользователей.

### Role управление

```bash
etcdctl role add <ROLENAME>
etcdctl role delete <ROLENAME>
etcdctl role list
etcdctl role get <ROLENAME>
```

Создание и управление ролями.

### Grant permissions

```bash
etcdctl role grant-permission <ROLENAME> read <KEY>
etcdctl role grant-permission <ROLENAME> write <KEY>
etcdctl role grant-permission <ROLENAME> readwrite <KEY>
etcdctl role grant-permission <ROLENAME> readwrite <PREFIX> --prefix
```

| Permission | Описание |
|------------|----------|
| `read` | Чтение ключа |
| `write` | Запись ключа |
| `readwrite` | Чтение и запись |

### Revoke permissions

```bash
etcdctl role revoke-permission <ROLENAME> <KEY>
etcdctl role revoke-permission <ROLENAME> <PREFIX> --prefix
```

Отзыв прав доступа.

### User-Role mapping

```bash
etcdctl user grant-role <USERNAME> <ROLENAME>
etcdctl user revoke-role <USERNAME> <ROLENAME>
```

Назначение и удаление ролей пользователям.

### Enable/Disable auth

```bash
etcdctl auth enable
etcdctl auth disable
etcdctl auth status
```

Включение и отключение аутентификации кластера.

---

## Kubernetes специфичные операции

### Просмотр Kubernetes данных

```bash
etcdctl get /registry/ --prefix --keys-only
etcdctl get /registry/pods --prefix --keys-only
etcdctl get /registry/deployments --prefix --keys-only
etcdctl get /registry/services --prefix --keys-only
```

Структура данных Kubernetes в etcd.

**Основные префиксы:**

| Префикс | Ресурсы |
|---------|---------|
| `/registry/pods` | Pods |
| `/registry/deployments` | Deployments |
| `/registry/services` | Services |
| `/registry/configmaps` | ConfigMaps |
| `/registry/secrets` | Secrets |
| `/registry/namespaces` | Namespaces |
| `/registry/nodes` | Nodes |
| `/registry/events` | Events |

### Чтение конкретного ресурса

```bash
etcdctl get /registry/pods/<NAMESPACE>/<POD_NAME> -w=json
etcdctl get /registry/secrets/<NAMESPACE>/<SECRET_NAME>
```

Прямое чтение Kubernetes объектов из etcd.

### Подсчет ресурсов

```bash
etcdctl get /registry/pods --prefix --keys-only | wc -l
etcdctl get /registry/secrets --prefix --keys-only | wc -l
```

Количество объектов каждого типа.

---

## Мониторинг и метрики

### Database size

```bash
etcdctl endpoint status -w=table
```

Отображение размера базы данных на каждом member.

### Key space usage

```bash
etcdctl get "" --prefix --keys-only | wc -l
```

Общее количество ключей в etcd.

### Watch metrics

```bash
etcdctl watch "" --prefix --rev=0 &
```

Подсчет количества изменений.

---

## Troubleshooting

### Проверка connectivity

```bash
etcdctl endpoint health
etcdctl member list
```

Базовая проверка доступности кластера.

### Ошибка: mvcc: database space exceeded

```bash
etcdctl endpoint status -w=table
etcdctl alarm list
etcdctl defrag
etcdctl alarm disarm
```

Решение проблемы нехватки места.

### Inconsistent data

```bash
etcdctl endpoint hashkv -w=table
```

Проверка консистентности данных между members.

### Slow queries

```bash
etcdctl get <KEY> --debug
```

Отладочная информация для медленных запросов.

### Проверка leader

```bash
etcdctl endpoint status -w=table | grep true
```

Определение текущего leader в кластере.

---

## Best Practices

**Regular backups:**

```bash
0 */6 * * * etcdctl snapshot save /backup/etcd-$(date +\%Y\%m\%d-\%H\%M\%S).db
```

Автоматические snapshot каждые 6 часов.

**Monitoring:**

```bash
watch -n 5 'etcdctl endpoint status -w=table'
```

Регулярная проверка состояния кластера.

**Компакция и дефрагментация:**

```bash
# Weekly maintenance
etcdctl compact $(etcdctl endpoint status --write-out="json" | jq -r '.[0].Status.header.revision')
etcdctl defrag
```

Еженедельное обслуживание для оптимизации производительности.

**Security:**

Всегда использовать TLS и authentication в production.

**Testing restores:**

Регулярно тестировать процесс восстановления из backup в тестовом окружении.