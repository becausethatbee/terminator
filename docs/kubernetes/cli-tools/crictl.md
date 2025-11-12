# crictl - Container Runtime Interface CLI

Исчерпывающий справочник по crictl - CLI для взаимодействия с CRI-совместимыми container runtime (containerd, CRI-O).

## Предварительные требования

- Установленный crictl
- CRI-совместимый runtime (containerd, CRI-O)
- Root или sudo доступ
- Runtime socket endpoint

---

## Конфигурация

### Runtime endpoint

```bash
crictl --runtime-endpoint unix:///run/containerd/containerd.sock <COMMAND>
crictl --runtime-endpoint unix:///var/run/crio/crio.sock <COMMAND>
```

Указание runtime socket.

### Конфигурационный файл

```bash
cat /etc/crictl.yaml
```

```yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
pull-image-on-create: false
```

| Параметр | Описание | Default |
|----------|----------|---------|
| `runtime-endpoint` | Runtime socket path | - |
| `image-endpoint` | Image service endpoint | Same as runtime |
| `timeout` | Request timeout (секунды) | `2` |
| `debug` | Debug logging | `false` |
| `pull-image-on-create` | Auto pull при создании | `false` |

### Environment variables

```bash
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock
export IMAGE_SERVICE_ENDPOINT=unix:///run/containerd/containerd.sock
```

Альтернатива конфигурационному файлу.

---

## Pod операции

### Список pods

```bash
crictl pods
crictl pods --name <POD_NAME>
crictl pods --namespace <NAMESPACE>
crictl pods --label <KEY>=<VALUE>
crictl pods --state <STATE>
```

| Флаг | Описание |
|------|----------|
| `--name` | Фильтр по имени pod |
| `--namespace` | Фильтр по namespace |
| `--id` | Фильтр по pod ID |
| `--label` | Фильтр по labels |
| `--state` | Фильтр по состоянию (ready/notready) |
| `--latest` | Показать последний созданный pod |
| `--no-trunc` | Не обрезать вывод |
| `-o, --output` | Формат вывода (json, yaml, table) |

**Вывод:**

| Столбец | Описание |
|---------|----------|
| POD ID | Unique pod identifier |
| CREATED | Время создания |
| STATE | Ready/NotReady |
| NAME | Pod name |
| NAMESPACE | Kubernetes namespace |
| ATTEMPT | Restart count |

### Inspect pod

```bash
crictl inspectp <POD_ID>
crictl inspectp <POD_ID> -o json | jq
crictl inspectp <POD_ID> -o yaml
```

Детальная информация о pod в JSON или YAML формате.

**Основные секции:**
- Pod metadata и labels
- Network namespace и IP
- Container IDs
- Volume mounts
- Annotations

### Pod статистика

```bash
crictl statsp <POD_ID>
crictl statsp
```

CPU и memory usage pod sandbox.

### Удаление pod

```bash
crictl rmp <POD_ID>
crictl rmp --all
crictl rmp --force <POD_ID>
```

| Флаг | Описание |
|------|----------|
| `--all` | Удалить все stopped pods |
| `--force` | Принудительное удаление |

---

## Container операции

### Список containers

```bash
crictl ps
crictl ps -a
crictl ps --name <CONTAINER_NAME>
crictl ps --pod <POD_ID>
crictl ps --state <STATE>
crictl ps --label <KEY>=<VALUE>
```

| Флаг | Описание |
|------|----------|
| `-a, --all` | Все контейнеры (включая остановленные) |
| `--name` | Фильтр по имени |
| `--pod` | Фильтр по pod ID |
| `--id` | Фильтр по container ID |
| `--state` | Фильтр по состоянию (running/exited/created) |
| `--label` | Фильтр по labels |
| `--latest` | Последний созданный контейнер |
| `-q, --quiet` | Только container IDs |
| `--no-trunc` | Полный вывод без обрезки |

**Вывод:**

| Столбец | Описание |
|---------|----------|
| CONTAINER ID | Unique container identifier |
| IMAGE | Container image |
| CREATED | Время создания |
| STATE | Running/Exited/Created/Unknown |
| NAME | Container name |
| ATTEMPT | Restart count |
| POD ID | Parent pod ID |

### Inspect container

```bash
crictl inspect <CONTAINER_ID>
crictl inspect <CONTAINER_ID> -o json | jq '.info.runtimeSpec'
crictl inspect <CONTAINER_ID> -o yaml
```

Полная информация о контейнере.

**Основные секции:**
- Container metadata
- Image информация
- Runtime spec (mounts, env, command)
- Network settings
- Resource limits
- Security context

### Container статистика

```bash
crictl stats <CONTAINER_ID>
crictl stats
crictl stats --all
```

CPU, memory, disk I/O statistics.

| Метрика | Описание |
|---------|----------|
| CPU % | CPU usage percent |
| MEM | Memory usage |
| DISK | Disk I/O |
| INODES | Inode usage |

### Container логи

```bash
crictl logs <CONTAINER_ID>
crictl logs <CONTAINER_ID> --tail=100
crictl logs <CONTAINER_ID> --since=1h
crictl logs <CONTAINER_ID> -f
```

| Флаг | Описание |
|------|----------|
| `--tail` | Последние N строк |
| `--since` | Логи с определенного времени (1h, 10m) |
| `-f, --follow` | Stream логов |
| `--timestamps` | Включить timestamps |

### Exec в контейнер

```bash
crictl exec <CONTAINER_ID> <COMMAND>
crictl exec -it <CONTAINER_ID> /bin/sh
crictl exec -it <CONTAINER_ID> /bin/bash
```

| Флаг | Описание |
|------|----------|
| `-i, --interactive` | Интерактивный режим |
| `-t, --tty` | Выделить pseudo-TTY |

Выполнение команд внутри контейнера.

### Attach к контейнеру

```bash
crictl attach <CONTAINER_ID>
```

Подключение к running контейнеру (stdin/stdout/stderr).

### Port forward

```bash
crictl port-forward <POD_ID> <LOCAL_PORT>:<REMOTE_PORT>
```

Проброс портов для debugging.

### Создание контейнера

```bash
crictl create <POD_ID> <CONTAINER_CONFIG> <POD_CONFIG>
```

Создание контейнера из конфигурационных файлов.

### Запуск контейнера

```bash
crictl start <CONTAINER_ID>
```

Запуск созданного контейнера.

### Остановка контейнера

```bash
crictl stop <CONTAINER_ID>
crictl stop <CONTAINER_ID> --timeout=30
```

Graceful остановка контейнера с timeout.

### Удаление контейнера

```bash
crictl rm <CONTAINER_ID>
crictl rm --all
crictl rm --force <CONTAINER_ID>
```

| Флаг | Описание |
|------|----------|
| `--all` | Удалить все stopped контейнеры |
| `--force` | Принудительное удаление |

---

## Image операции

### Список образов

```bash
crictl images
crictl images <IMAGE_NAME>
crictl images --digests
crictl images -q
```

| Флаг | Описание |
|------|----------|
| `--digests` | Показать digests |
| `-q, --quiet` | Только image IDs |
| `--no-trunc` | Полный вывод |

**Вывод:**

| Столбец | Описание |
|---------|----------|
| IMAGE | Image name:tag |
| IMAGE ID | Unique identifier |
| SIZE | Image size |

### Pull образа

```bash
crictl pull <IMAGE>
crictl pull nginx:latest
crictl pull registry.k8s.io/pause:3.9
```

Загрузка образа из registry.

**Поддерживаемые форматы:**

```bash
crictl pull nginx
crictl pull nginx:1.25
crictl pull docker.io/library/nginx:latest
crictl pull quay.io/organization/image:tag
crictl pull gcr.io/project/image:tag
```

### Inspect образа

```bash
crictl inspecti <IMAGE_ID>
crictl inspecti <IMAGE_NAME>
crictl inspecti <IMAGE_ID> -o json | jq
```

Детальная информация об образе.

**Информация:**
- Image layers и digests
- Environment variables
- Exposed ports
- Volume definitions
- Labels и annotations
- Entry point и CMD

### Удаление образа

```bash
crictl rmi <IMAGE_ID>
crictl rmi <IMAGE_NAME>
crictl rmi --prune
```

| Флаг | Описание |
|------|----------|
| `--prune` | Удалить unused образы |
| `--all` | Удалить все образы |

---

## Runtime информация

### Version

```bash
crictl version
```

Версия crictl и runtime.

**Вывод:**

```
Version:  0.1.0
RuntimeName:  containerd
RuntimeVersion:  1.7.2
RuntimeApiVersion:  v1
```

### Info

```bash
crictl info
crictl info -o json | jq
```

Детальная информация о runtime.

**Информация:**
- Runtime configuration
- Storage driver
- Plugin information
- CGroup driver
- Security options
- Kernel version

---

## Pod Sandbox операции

### Запуск sandbox

```bash
crictl runp <POD_CONFIG>
crictl runp pod-config.json
```

Создание и запуск pod sandbox из конфигурации.

**Пример pod-config.json:**

```json
{
  "metadata": {
    "name": "test-pod",
    "namespace": "default",
    "attempt": 1,
    "uid": "unique-pod-id"
  },
  "log_directory": "/var/log/pods",
  "dns_config": {
    "servers": ["10.96.0.10"]
  }
}
```

### Остановка sandbox

```bash
crictl stopp <POD_ID>
```

Остановка pod sandbox и всех контейнеров.

---

## Конфигурационные файлы

### Container config

```json
{
  "metadata": {
    "name": "container-name"
  },
  "image": {
    "image": "nginx:latest"
  },
  "command": ["/bin/sh"],
  "args": ["-c", "sleep 3600"],
  "envs": [
    {
      "key": "KEY",
      "value": "VALUE"
    }
  ],
  "mounts": [
    {
      "container_path": "/data",
      "host_path": "/var/data",
      "readonly": false
    }
  ],
  "linux": {
    "resources": {
      "cpu_quota": 100000,
      "memory_limit_in_bytes": 536870912
    }
  }
}
```

Конфигурация для создания контейнера.

---

## Debugging

### События runtime

```bash
crictl events
```

Stream runtime events в реальном времени.

### Проверка runtime

```bash
crictl version
crictl info
crictl pods
crictl ps -a
crictl images
```

Базовая проверка работоспособности runtime.

### Container файловая система

```bash
crictl exec <CONTAINER_ID> ls /
crictl exec <CONTAINER_ID> cat /etc/os-release
```

Исследование файловой системы контейнера.

### Network debugging

```bash
crictl inspectp <POD_ID> | grep -i network
crictl exec <CONTAINER_ID> ip addr
crictl exec <CONTAINER_ID> netstat -tulpn
```

Проверка сетевой конфигурации.

---

## Различия с docker

### Команды mapping

| Docker | crictl | Описание |
|--------|--------|----------|
| `docker ps` | `crictl ps` | Список контейнеров |
| `docker images` | `crictl images` | Список образов |
| `docker pull` | `crictl pull` | Pull образа |
| `docker exec` | `crictl exec` | Exec в контейнер |
| `docker logs` | `crictl logs` | Логи контейнера |
| `docker inspect` | `crictl inspect` | Inspect контейнера |
| `docker stats` | `crictl stats` | Статистика |
| `docker rm` | `crictl rm` | Удалить контейнер |
| `docker rmi` | `crictl rmi` | Удалить образ |

### Отсутствующие операции

crictl **НЕ** поддерживает:

- `docker build` - сборка образов
- `docker commit` - создание образа из контейнера
- `docker network` - управление сетями
- `docker volume` - управление volumes
- `docker compose` - multi-container приложения

crictl предназначен для debugging и inspecting, не для полного управления контейнерами.

---

## Troubleshooting

### Ошибка: connect: no such file or directory

```bash
ls -la /run/containerd/containerd.sock
ls -la /var/run/crio/crio.sock
```

Проверка существования runtime socket.

**Решение:**

```bash
systemctl status containerd
systemctl start containerd
```

Убедиться что runtime запущен.

### Ошибка: permission denied

```bash
sudo crictl ps
```

crictl требует root прав для доступа к runtime socket.

### Empty output

```bash
crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps
```

Явное указание runtime endpoint при проблемах с конфигурацией.

### Timeout errors

```bash
crictl --timeout 30s ps
```

Увеличение timeout для медленных операций.

---

## Integration с Kubernetes

### Kubernetes managed контейнеры

```bash
crictl ps --label io.kubernetes.pod.namespace=<NAMESPACE>
crictl ps --label io.kubernetes.container.name=<CONTAINER>
crictl pods --namespace kube-system
```

Фильтрация по Kubernetes labels.

**Стандартные labels:**

| Label | Описание |
|-------|----------|
| `io.kubernetes.pod.namespace` | Pod namespace |
| `io.kubernetes.pod.name` | Pod name |
| `io.kubernetes.pod.uid` | Pod UID |
| `io.kubernetes.container.name` | Container name |

### Debugging Kubernetes контейнеров

```bash
# Найти pod
crictl pods --name <POD_NAME>

# Найти контейнеры pod
crictl ps --pod <POD_ID>

# Логи контейнера
crictl logs <CONTAINER_ID>

# Exec в контейнер
crictl exec -it <CONTAINER_ID> /bin/sh
```

Типичный workflow для debugging.

### Comparison с kubectl

| Операция | kubectl | crictl |
|----------|---------|--------|
| Список pods | `kubectl get pods` | `crictl pods` |
| Логи | `kubectl logs` | `crictl logs` |
| Exec | `kubectl exec` | `crictl exec` |
| Describe | `kubectl describe` | `crictl inspect` |
| Delete pod | `kubectl delete pod` | `crictl rmp` (временно) |

crictl работает на уровне runtime, kubectl - на уровне Kubernetes API.

---

## Performance анализ

### Resource usage

```bash
crictl stats --all
watch -n 1 'crictl stats'
```

Мониторинг потребления ресурсов контейнерами.

### Image size анализ

```bash
crictl images | sort -k3 -h
```

Сортировка образов по размеру.

### Container lifecycle

```bash
crictl ps -a --no-trunc
```

Просмотр истории контейнеров с полной информацией.

---

## Security проверки

### Running контейнеры анализ

```bash
crictl inspect <CONTAINER_ID> | jq '.info.runtimeSpec.process.user'
crictl inspect <CONTAINER_ID> | jq '.info.runtimeSpec.linux.securityContext'
```

Проверка security context контейнеров.

### Privileged контейнеры

```bash
crictl inspect <CONTAINER_ID> | jq '.info.privileged'
```

Определение privileged контейнеров.

### Capabilities

```bash
crictl inspect <CONTAINER_ID> | jq '.info.runtimeSpec.process.capabilities'
```

Просмотр Linux capabilities контейнера.

---

## Best Practices

**Использование labels для фильтрации:**

```bash
crictl ps --label app=nginx
crictl pods --label tier=frontend
```

Эффективный поиск контейнеров и pods.

**Регулярная очистка:**

```bash
crictl rmi --prune
crictl rm $(crictl ps -a -q --state=exited)
```

Удаление unused образов и stopped контейнеров.

**Логирование с context:**

```bash
crictl logs --timestamps --tail=100 <CONTAINER_ID>
```

Включение timestamps для корреляции событий.

**Мониторинг в реальном времени:**

```bash
watch -n 2 'crictl stats --all'
crictl logs -f <CONTAINER_ID>
```

Постоянный мониторинг состояния.

**Безопасность:**

```bash
crictl inspect <CONTAINER_ID> | jq '.info.privileged'
crictl inspect <CONTAINER_ID> | jq '.info.runtimeSpec.linux.securityContext'
```

Регулярная проверка security settings контейнеров.