# Kubernetes Workloads: Pod, Deployment, StatefulSet, DaemonSet, Job

Практическое руководство по работе с основными типами рабочих нагрузок в Kubernetes.

## Предварительные требования

- Установленный kubectl версии 1.34+
- Minikube или доступ к Kubernetes кластеру
- Docker runtime
- Минимум 4 GB RAM, 2 CPU cores
- Базовое понимание контейнеризации

---

## Часть 1: Работа с Pod

### Создание Pod

```bash
mkdir -p ~/k8s-tasks/task1
cd ~/k8s-tasks/task1
nano nginx-pod.yaml
```

Манифест Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

Применение манифеста:

```bash
kubectl apply -f nginx-pod.yaml
kubectl get pods
```

Pod создаётся как минимальная единица развёртывания в Kubernetes.

### Проверка состояния

```bash
kubectl get pods
kubectl describe pod nginx-pod
```

Команда `describe` выводит детальную информацию о Pod: события, статус контейнеров, назначенную ноду.

### Доступ к приложению

```bash
kubectl port-forward nginx-pod 8080:80
```

Проброс порта создаёт туннель между localhost:8080 и портом контейнера.

Проверка доступности:

```bash
curl http://localhost:8080
```

### Просмотр логов

```bash
kubectl logs nginx-pod
```

Логи отображают stdout/stderr контейнера.

---

## Часть 2: Управление репликами

### Создание Deployment

```bash
cd ~/k8s-tasks
mkdir task2
cd task2
nano nginx-deployment.yaml
```

Манифест Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

Параметры стратегии:

| Параметр | Значение | Описание |
|----------|----------|----------|
| maxSurge | 1 | Максимум дополнительных Pod при обновлении |
| maxUnavailable | 1 | Максимум недоступных Pod при обновлении |

Применение:

```bash
kubectl apply -f nginx-deployment.yaml
kubectl get deployments
kubectl get replicasets
kubectl get pods
```

Deployment автоматически создаёт ReplicaSet, который управляет Pod.

### Обновление образа

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.23.3
```

Отслеживание процесса обновления:

```bash
kubectl get pods -w
```

Флаг `-w` включает режим watch для мониторинга изменений в реальном времени.

Проверка статуса:

```bash
kubectl rollout status deployment/nginx-deployment
```

### Создание ReplicaSet

```bash
nano nginx-replicaset.yaml
```

Манифест ReplicaSet:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
spec:
  replicas: 5
  selector:
    matchLabels:
      app: nginx-rs
  template:
    metadata:
      labels:
        app: nginx-rs
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 8080
```

Применение:

```bash
kubectl apply -f nginx-replicaset.yaml
kubectl get replicasets
kubectl get pods
```

ReplicaSet поддерживает заданное количество идентичных Pod.

---

## Часть 3: Специфические объекты

### DaemonSet для мониторинга

```bash
cd ~/k8s-tasks
mkdir task3
cd task3
nano fluentd-daemonset.yaml
```

Манифест DaemonSet:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-daemonset
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:latest
```

Применение:

```bash
kubectl apply -f fluentd-daemonset.yaml
kubectl get daemonsets
kubectl get pods -o wide
```

DaemonSet запускает по одному Pod на каждой ноде кластера.

### StatefulSet для stateful приложений

```bash
nano redis-statefulset.yaml
```

Манифест StatefulSet с headless Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  clusterIP: None
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-statefulset
spec:
  serviceName: redis
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:latest
        ports:
        - containerPort: 6379
        volumeMounts:
        - name: redis-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

Применение:

```bash
kubectl apply -f redis-statefulset.yaml
kubectl get statefulsets
kubectl get pods -l app=redis -w
```

StatefulSet создаёт Pod последовательно: redis-0 → redis-1 → redis-2.

Проверка PersistentVolumeClaim:

```bash
kubectl get pvc
kubectl get pv
```

Каждый Pod получает уникальный PVC для хранения данных.

### Job для одноразовых задач

```bash
nano data-processing-job.yaml
```

Манифест Job:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing-job
spec:
  template:
    metadata:
      labels:
        app: data-processor
    spec:
      containers:
      - name: processor
        image: busybox:latest
        command: ['sh', '-c', 'echo "Data processed" && sleep 5']
      restartPolicy: Never
  backoffLimit: 3
```

Параметр `backoffLimit` определяет максимальное количество попыток при ошибке.

Применение:

```bash
kubectl apply -f data-processing-job.yaml
kubectl get jobs
kubectl get pods
```

Просмотр результата:

```bash
kubectl logs <JOB_POD_NAME>
```

### CronJob для периодических задач

```bash
nano backup-cronjob.yaml
```

Манифест CronJob:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-cronjob
spec:
  schedule: "*/2 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: busybox:latest
            command: ['sh', '-c', 'echo "Backup complete" && date']
          restartPolicy: Never
```

Формат расписания (cron):

| Поле | Значение |
|------|----------|
| Минуты | */2 (каждые 2 минуты) |
| Часы | * (любой час) |
| День месяца | * (любой день) |
| Месяц | * (любой месяц) |
| День недели | * (любой день недели) |

Применение:

```bash
kubectl apply -f backup-cronjob.yaml
kubectl get cronjobs
kubectl get jobs
```

CronJob автоматически создаёт Job согласно расписанию.

---

## Часть 4: Анализ и мониторинг

### Просмотр всех объектов

```bash
kubectl get all
```

Отображение всех ресурсов в текущем namespace.

### Детальная информация

```bash
kubectl describe deployment nginx-deployment
```

Вывод включает стратегию обновления, историю изменений, состояние ReplicaSet.

### Установка Metrics Server

```bash
minikube addons enable metrics-server
```

Ожидание готовности:

```bash
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s
```

### Мониторинг ресурсов

```bash
kubectl top nodes
kubectl top pods --sort-by=memory
```

Команды отображают текущее потребление CPU и памяти.

### Удаление объектов

```bash
kubectl delete pod nginx-pod
kubectl delete deployment nginx-deployment
kubectl delete replicaset nginx-replicaset
kubectl delete daemonset fluentd-daemonset
kubectl delete statefulset redis-statefulset
kubectl delete job data-processing-job
kubectl delete cronjob backup-cronjob
```

Удаление Deployment автоматически удаляет связанные ReplicaSet и Pod.

---

## Сравнение типов объектов

### Deployment vs ReplicaSet

| Параметр | ReplicaSet | Deployment |
|----------|------------|------------|
| Управление | Количество реплик | ReplicaSet + обновления |
| Обновления | Отсутствуют | RollingUpdate, Recreate |
| Rollback | Отсутствует | Поддерживается |
| История версий | Нет | Да |
| Использование | Редко напрямую | Стандартный способ |

### Типы контроллеров

| Тип | Поведение | Использование |
|-----|-----------|---------------|
| Deployment | N реплик, обновления | Stateless приложения |
| ReplicaSet | N реплик, без обновлений | Управляется Deployment |
| StatefulSet | Уникальные Pod, persistent storage | БД, очереди, кластеры |
| DaemonSet | 1 Pod на каждой ноде | Мониторинг, логи, сеть |
| Job | Выполнить до завершения | Пакетные задачи |
| CronJob | Периодическое выполнение | Бэкапы, очистка |

### Особенности StatefulSet

**Характеристики:**
- Последовательное создание Pod (0 → 1 → 2)
- Стабильные имена (redis-0, redis-1, redis-2)
- Уникальный PersistentVolumeClaim для каждого Pod
- Стабильная сетевая идентификация через headless Service
- Сохранение данных при пересоздании Pod

**Применение:**
- Базы данных (PostgreSQL, MySQL, MongoDB)
- Распределённые системы (Elasticsearch, Cassandra, Kafka)
- Очереди сообщений (RabbitMQ, ZooKeeper)

### Rolling Update механизм

**Параметры:**

```yaml
rollingUpdate:
  maxSurge: 1
  maxUnavailable: 1
```

**Процесс обновления:**

1. Deployment создаёт новый ReplicaSet
2. Запускается 1 дополнительный Pod (maxSurge)
3. После Ready нового Pod удаляется 1 старый (maxUnavailable)
4. Процесс повторяется до полной замены

**Гарантии:**
- Минимум `replicas - maxUnavailable` Pod в состоянии Ready
- Максимум `replicas + maxSurge` Pod одновременно
- Zero-downtime deployment

---

## Troubleshooting

### ImagePullBackOff

**Ошибка:**
```
pod/nginx-pod   0/1     ImagePullBackOff   0          2m
```

**Причина:** Образ не найден или отсутствует доступ к registry.

**Решение:**
```bash
kubectl describe pod <POD_NAME>
kubectl get events
```

Проверить имя образа и наличие imagePullSecrets.

### CrashLoopBackOff

**Ошибка:**
```
pod/app   0/1     CrashLoopBackOff   5          3m
```

**Причина:** Контейнер завершается с ошибкой.

**Решение:**
```bash
kubectl logs <POD_NAME>
kubectl logs <POD_NAME> --previous
```

Анализ логов текущего и предыдущего запуска контейнера.

### Pending состояние

**Ошибка:**
```
pod/nginx   0/1     Pending   0          5m
```

**Причина:** Недостаточно ресурсов или проблемы с scheduler.

**Решение:**
```bash
kubectl describe pod <POD_NAME>
kubectl get nodes
kubectl top nodes
```

Проверить доступность ресурсов на нодах.

### PersistentVolumeClaim не создаётся

**Ошибка:**
```
pvc/data   Pending
```

**Причина:** Отсутствует StorageClass или динамический provisioner.

**Решение:**
```bash
kubectl get storageclass
minikube addons enable storage-provisioner
```

---

## Best Practices

**Deployment:**
- Использовать вместо ReplicaSet напрямую
- Задавать resource requests/limits
- Определять readiness/liveness probes
- Использовать RollingUpdate для zero-downtime

**StatefulSet:**
- Использовать headless Service
- Определять PodManagementPolicy при необходимости
- Задавать volumeClaimTemplates для persistent storage
- Использовать init containers для инициализации

**DaemonSet:**
- Применять tolerations для системных Pod
- Монтировать hostPath только при необходимости
- Задавать resource limits для предотвращения перегрузки ноды
- Использовать nodeSelector для таргетинга конкретных нод

**Job/CronJob:**
- Задавать activeDeadlineSeconds для ограничения времени выполнения
- Использовать backoffLimit для контроля повторных попыток
- Определять completions и parallelism для параллельных задач
- Очищать завершённые Job с помощью ttlSecondsAfterFinished

**Общие рекомендации:**
- Использовать labels для организации объектов
- Применять namespaces для изоляции окружений
- Версионировать манифесты в Git
- Использовать Helm для шаблонизации

---

## Полезные команды

### Просмотр ресурсов

```bash
kubectl get pods
kubectl get deployments
kubectl get replicasets
kubectl get statefulsets
kubectl get daemonsets
kubectl get jobs
kubectl get cronjobs
kubectl get all
kubectl get pods -o wide
kubectl get pods -l app=nginx
kubectl get pods --all-namespaces
```

### Детальная информация

```bash
kubectl describe pod <POD_NAME>
kubectl describe deployment <DEPLOYMENT_NAME>
kubectl logs <POD_NAME>
kubectl logs <POD_NAME> -c <CONTAINER_NAME>
kubectl logs <POD_NAME> --previous
kubectl logs -f <POD_NAME>
```

### Управление объектами

```bash
kubectl apply -f manifest.yaml
kubectl delete -f manifest.yaml
kubectl delete pod <POD_NAME>
kubectl delete deployment <DEPLOYMENT_NAME>
kubectl scale deployment <NAME> --replicas=5
kubectl set image deployment/<NAME> <CONTAINER>=<IMAGE>
kubectl rollout status deployment/<NAME>
kubectl rollout history deployment/<NAME>
kubectl rollout undo deployment/<NAME>
```

### Отладка

```bash
kubectl exec -it <POD_NAME> -- /bin/bash
kubectl exec <POD_NAME> -- <COMMAND>
kubectl port-forward <POD_NAME> 8080:80
kubectl top nodes
kubectl top pods
kubectl get events
kubectl get events --sort-by='.lastTimestamp'
```

### Мониторинг

```bash
kubectl get pods -w
kubectl get deployments -w
kubectl rollout status deployment/<NAME>
kubectl top nodes
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
```

### Namespace операции

```bash
kubectl get pods -n <NAMESPACE>
kubectl get all -n <NAMESPACE>
kubectl create namespace <NAME>
kubectl delete namespace <NAME>
```