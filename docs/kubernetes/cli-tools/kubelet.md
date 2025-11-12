# kubelet - Управление нодой

Исчерпывающий справочник по kubelet - агенту Kubernetes, запускающемуся на каждой node и управляющему контейнерами.

## Предварительные требования

- Установленный kubelet
- Root или sudo доступ
- systemd для управления сервисом

---

## Архитектура

**Компоненты:**
- kubelet service - systemd сервис
- kubelet binary - основной исполняемый файл
- configuration file - конфигурация YAML
- kubeconfig - аутентификация в API server

**Расположение файлов:**

| Файл | Путь | Назначение |
|------|------|------------|
| Binary | `/usr/bin/kubelet` | Исполняемый файл |
| Config | `/var/lib/kubelet/config.yaml` | Конфигурация kubelet |
| Kubeconfig | `/etc/kubernetes/kubelet.conf` | API server credentials |
| Service | `/etc/systemd/system/kubelet.service` | Systemd unit |
| Drop-in | `/etc/systemd/system/kubelet.service.d/` | Дополнительные настройки |

---

## Systemd управление

### Базовые операции

```bash
systemctl start kubelet
systemctl stop kubelet
systemctl restart kubelet
systemctl reload kubelet
```

Управление жизненным циклом сервиса.

```bash
systemctl status kubelet
systemctl is-active kubelet
systemctl is-enabled kubelet
systemctl is-failed kubelet
```

Проверка состояния сервиса.

### Автозагрузка

```bash
systemctl enable kubelet
systemctl disable kubelet
systemctl enable --now kubelet
```

| Команда | Описание |
|---------|----------|
| `enable` | Добавление в автозагрузку |
| `disable` | Удаление из автозагрузки |
| `enable --now` | Включение автозагрузки + немедленный запуск |

### Зависимости

```bash
systemctl list-dependencies kubelet
systemctl show kubelet
```

Просмотр зависимостей и параметров сервиса.

---

## Логирование

### journalctl команды

```bash
journalctl -u kubelet
journalctl -u kubelet -f
journalctl -u kubelet --since "1 hour ago"
journalctl -u kubelet --since "2024-01-01" --until "2024-01-02"
journalctl -u kubelet -n 100
```

| Флаг | Описание |
|------|----------|
| `-u` | Unit name (kubelet) |
| `-f` | Follow mode (tail -f) |
| `--since` | Логи с определенного времени |
| `--until` | Логи до определенного времени |
| `-n` | Последние N строк |
| `--no-pager` | Вывод без пейджера |

### Фильтрация логов

```bash
journalctl -u kubelet -p err
journalctl -u kubelet -p warning
journalctl -u kubelet --grep="Failed"
journalctl -u kubelet -o json-pretty
```

| Приоритет | Описание |
|-----------|----------|
| `emerg` | Emergency (0) |
| `alert` | Alert (1) |
| `crit` | Critical (2) |
| `err` | Error (3) |
| `warning` | Warning (4) |
| `notice` | Notice (5) |
| `info` | Info (6) |
| `debug` | Debug (7) |

### Экспорт логов

```bash
journalctl -u kubelet > kubelet.log
journalctl -u kubelet --since today -o json > kubelet.json
journalctl -u kubelet --vacuum-time=7d
```

Сохранение и ротация логов.

---

## Конфигурация

### Параметры запуска

**Через systemd drop-in:**

```bash
cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
```

Основные параметры для kubeadm установки.

**Основные флаги:**

| Флаг | Описание | Пример |
|------|----------|--------|
| `--config` | Путь к config file | `--config=/var/lib/kubelet/config.yaml` |
| `--kubeconfig` | Путь к kubeconfig | `--kubeconfig=/etc/kubernetes/kubelet.conf` |
| `--node-ip` | IP адрес node | `--node-ip=192.168.1.10` |
| `--hostname-override` | Override hostname | `--hostname-override=node01` |
| `--pod-manifest-path` | Static pods директория | `--pod-manifest-path=/etc/kubernetes/manifests` |
| `--bootstrap-kubeconfig` | Bootstrap config | `--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf` |
| `--cert-dir` | Директория сертификатов | `--cert-dir=/var/lib/kubelet/pki` |

### KubeletConfiguration

```bash
cat /var/lib/kubelet/config.yaml
```

**Основные параметры:**

| Параметр | Тип | Описание | Default |
|----------|-----|----------|---------|
| `address` | string | Адрес для API | `0.0.0.0` |
| `port` | int | Порт для API | `10250` |
| `readOnlyPort` | int | Read-only порт (deprecated) | `0` |
| `authentication` | object | Настройки аутентификации | - |
| `authorization` | object | Настройки авторизации | - |
| `clusterDomain` | string | Cluster domain | `cluster.local` |
| `clusterDNS` | []string | DNS серверы | `["10.96.0.10"]` |
| `containerRuntimeEndpoint` | string | CRI endpoint | `unix:///var/run/containerd/containerd.sock` |
| `cgroupDriver` | string | Cgroup driver | `systemd` |
| `cpuManagerPolicy` | string | CPU manager | `none` |
| `maxPods` | int | Максимум pods | `110` |
| `podCIDR` | string | Pod CIDR range | - |
| `resolvConf` | string | resolv.conf path | `/etc/resolv.conf` |
| `staticPodPath` | string | Static pods path | `/etc/kubernetes/manifests` |
| `tlsCertFile` | string | TLS cert | `/var/lib/kubelet/pki/kubelet.crt` |
| `tlsPrivateKeyFile` | string | TLS key | `/var/lib/kubelet/pki/kubelet.key` |

### Eviction настройки

```yaml
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
```

Пороги для eviction pods при нехватке ресурсов.

### Resource reservation

```yaml
kubeReserved:
  cpu: "100m"
  memory: "100Mi"
  ephemeral-storage: "1Gi"
systemReserved:
  cpu: "100m"
  memory: "100Mi"
  ephemeral-storage: "1Gi"
```

Резервирование ресурсов для system и Kubernetes компонентов.

---

## API endpoints

### Метрики и здоровье

```bash
curl -k https://<NODE_IP>:10250/metrics
curl -k https://<NODE_IP>:10250/healthz
curl -k https://<NODE_IP>:10250/stats/summary
```

**Требуется аутентификация** через client certificate или bearer token.

**Основные endpoints:**

| Endpoint | Описание |
|----------|----------|
| `/healthz` | Health check |
| `/metrics` | Prometheus metrics |
| `/metrics/cadvisor` | cAdvisor metrics |
| `/metrics/resource` | Resource metrics |
| `/metrics/probes` | Probe metrics |
| `/pods` | Список running pods |
| `/stats` | Runtime stats |
| `/logs/` | Container logs |
| `/exec/` | Container exec |
| `/portForward/` | Port forward |

### Аутентификация

```bash
curl --cert /var/lib/kubelet/pki/kubelet-client.crt \
     --key /var/lib/kubelet/pki/kubelet-client.key \
     --cacert /etc/kubernetes/pki/ca.crt \
     https://<NODE_IP>:10250/healthz
```

Доступ к kubelet API через client certificates.

---

## Static Pods

### Управление

```bash
ls /etc/kubernetes/manifests/
```

Директория для static pod манифестов.

```bash
cp pod.yaml /etc/kubernetes/manifests/
rm /etc/kubernetes/manifests/pod.yaml
```

Добавление и удаление static pods. kubelet автоматически применяет изменения.

**Особенности:**
- Запускаются kubelet напрямую, без API server
- Используются для control plane компонентов
- Автоматический перезапуск при изменении файла
- Mirror pods в API server для видимости

### Мониторинг

```bash
kubectl get pods -n kube-system -l tier=control-plane
```

Static pods видны через API server как mirror pods.

---

## Certificate управление

### Проверка сертификатов

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet.crt -text -noout
openssl x509 -in /var/lib/kubelet/pki/kubelet.crt -noout -dates
```

Просмотр информации о сертификате и срока действия.

### Ротация сертификатов

```yaml
rotateCertificates: true
serverTLSBootstrap: true
```

Параметры в kubelet config для автоматической ротации.

```bash
systemctl restart kubelet
```

Перезапуск для применения новых сертификатов.

---

## Node registration

### Bootstrap process

```bash
kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
        --kubeconfig=/etc/kubernetes/kubelet.conf
```

Начальная регистрация node в кластере.

**Этапы:**
1. Использование bootstrap token
2. Создание CSR (Certificate Signing Request)
3. Получение signed certificate
4. Сохранение в kubeconfig
5. Регистрация node в API server

### Node labels

```bash
kubectl label node <NODE_NAME> <KEY>=<VALUE>
kubectl label node <NODE_NAME> <KEY>-
```

Управление labels node выполняется через kubectl, не напрямую в kubelet.

### Node taints

```bash
kubectl taint node <NODE_NAME> <KEY>=<VALUE>:<EFFECT>
kubectl taint node <NODE_NAME> <KEY>-
```

Управление taints для control scheduling.

---

## Garbage collection

### Image GC

```yaml
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
```

Пороги для garbage collection образов.

```bash
crictl images
crictl rmi <IMAGE_ID>
```

Ручное управление образами через CRI.

### Container GC

```yaml
containerGCMinAge: 0
containerGCMaxPerPodContainer: 1
```

Настройки для очистки остановленных контейнеров.

---

## Troubleshooting

### Проверка состояния

```bash
systemctl status kubelet -l
journalctl -u kubelet -n 50 --no-pager
```

Базовая диагностика проблем.

### Частые ошибки

**Failed to get system container stats:**

```bash
journalctl -u kubelet | grep "Failed to get system container stats"
```

Проблема с cAdvisor или cgroup. Проверить cgroup driver.

**Failed to sync pod:**

```bash
journalctl -u kubelet | grep "Failed to sync pod"
```

Проблемы с pulling образов или network setup.

**Certificate has expired:**

```bash
openssl x509 -in /var/lib/kubelet/pki/kubelet.crt -noout -checkend 0
```

Проверка срока действия сертификата.

### Отладочные флаги

```bash
kubelet --v=4
```

| Level | Описание |
|-------|----------|
| `--v=0` | Critical errors только |
| `--v=1` | Reasonable default |
| `--v=2` | Полезная steady state информация |
| `--v=3` | Extended информация о изменениях |
| `--v=4` | Debug level |
| `--v=5` | Trace level |

---

## Performance tuning

### CPU Manager

```yaml
cpuManagerPolicy: "static"
cpuManagerReconcilePeriod: "10s"
```

Эксклюзивное выделение CPU cores для guaranteed pods.

### Memory Manager

```yaml
memoryManagerPolicy: "Static"
```

NUMA-aware memory allocation.

### Topology Manager

```yaml
topologyManagerPolicy: "best-effort"
```

| Policy | Описание |
|--------|----------|
| `none` | Default, без alignment |
| `best-effort` | Попытка alignment без гарантий |
| `restricted` | Alignment обязателен |
| `single-numa-node` | Строгий single-NUMA alignment |

---

## Monitoring

### Метрики kubelet

```bash
curl -k https://localhost:10250/metrics | grep kubelet
```

**Основные метрики:**

| Метрика | Описание |
|---------|----------|
| `kubelet_running_pods` | Количество running pods |
| `kubelet_running_containers` | Количество running containers |
| `kubelet_node_name` | Node name |
| `kubelet_runtime_operations_total` | CRI операции |
| `kubelet_pleg_relist_duration_seconds` | PLEG relist duration |
| `kubelet_pod_start_duration_seconds` | Pod start duration |
| `kubelet_pod_worker_duration_seconds` | Pod worker duration |

### Resource usage

```bash
curl -k https://localhost:10250/stats/summary
```

Детальная статистика по CPU, memory, filesystem для node и pods.

---

## Security

### Authentication

```yaml
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
    cacheTTL: "2m0s"
  x509:
    clientCAFile: "/etc/kubernetes/pki/ca.crt"
```

Настройки аутентификации kubelet API.

### Authorization

```yaml
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: "5m0s"
    cacheUnauthorizedTTL: "30s"
```

Делегирование авторизации API server.

### TLS settings

```yaml
tlsCipherSuites:
  - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
  - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
tlsMinVersion: "VersionTLS12"
```

Настройки TLS для security compliance.

---

## Best Practices

**Конфигурация через файл:**

Использовать `/var/lib/kubelet/config.yaml` вместо флагов командной строки для управляемости.

**Certificate rotation:**

```yaml
rotateCertificates: true
serverTLSBootstrap: true
```

Включение автоматической ротации сертификатов.

**Resource reservation:**

```yaml
kubeReserved:
  cpu: "100m"
  memory: "500Mi"
systemReserved:
  cpu: "100m"
  memory: "500Mi"
```

Резервирование ресурсов предотвращает node pressure.

**Monitoring:**

```bash
journalctl -u kubelet -f
```

Постоянный мониторинг логов для раннего обнаружения проблем.

**Graceful shutdown:**

```yaml
shutdownGracePeriod: "30s"
shutdownGracePeriodCriticalPods: "10s"
```

Корректное завершение pods при остановке node.