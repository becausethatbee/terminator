# kubectl - Управление Workloads

Справочник команд для управления Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob и ReplicaSet.

## Предварительные требования

- kubectl версии 1.28+
- Доступ к Kubernetes кластеру
- Понимание концепций workloads

---

## Pod операции

### Создание Pod

**Императивное создание:**

```bash
kubectl run <POD_NAME> --image=<IMAGE>
kubectl run nginx --image=nginx:1.21
kubectl run busybox --image=busybox --command -- sleep 3600
kubectl run test --image=busybox --rm -it -- sh
```

| Флаг | Описание |
|------|----------|
| `--image` | Container image |
| `--port` | Container port |
| `--env` | Environment переменная KEY=VALUE |
| `--labels` | Labels для pod (KEY=VALUE) |
| `--annotations` | Annotations для pod |
| `--command` | Использовать команду вместо entrypoint |
| `--restart` | Политика перезапуска (Always/OnFailure/Never) |
| `--rm` | Удалить pod после завершения |
| `--attach` | Подключиться к stdin/stdout |
| `-it` | Interactive TTY |
| `--dry-run` | Режим тестирования |
| `--overrides` | JSON override для спецификации |
| `--pod-running-timeout` | Таймаут ожидания запуска |

**С переменными окружения:**

```bash
kubectl run app --image=app:v1 --env="ENV=prod" --env="DEBUG=false"
kubectl run app --image=app:v1 --env="CONFIG_PATH=/etc/config"
```

**С командой:**

```bash
kubectl run busybox --image=busybox -- echo "Hello World"
kubectl run busybox --image=busybox -- /bin/sh -c "while true; do date; sleep 5; done"
```

**С resource requests/limits:**

```bash
kubectl run nginx --image=nginx --requests='cpu=100m,memory=256Mi' --limits='cpu=200m,memory=512Mi'
```

**Генерация YAML:**

```bash
kubectl run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
kubectl run nginx --image=nginx --dry-run=client -o yaml | kubectl apply -f -
```

### Просмотр Pod

```bash
kubectl get pods
kubectl get pod <POD_NAME>
kubectl get pods -o wide
kubectl get pods --all-namespaces
kubectl get pods -A
```

**С дополнительной информацией:**

```bash
kubectl get pods --show-labels
kubectl get pods -L app,version
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName
```

Флаг `-L` добавляет указанные labels как отдельные колонки.

**Фильтрация:**

```bash
kubectl get pods -l app=nginx
kubectl get pods -l 'app in (nginx,apache)'
kubectl get pods --field-selector status.phase=Running
kubectl get pods --field-selector status.phase=Running,spec.nodeName=<NODE_NAME>
```

**Сортировка:**

```bash
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by=.status.startTime
kubectl get pods --sort-by=.status.containerStatuses[0].restartCount
```

### Детальная информация

```bash
kubectl describe pod <POD_NAME>
kubectl describe pods -l app=nginx
```

Вывод включает: metadata, spec, status, volumes, containers, conditions, events.

### Логи Pod

**Базовые команды:**

```bash
kubectl logs <POD_NAME>
kubectl logs <POD_NAME> -c <CONTAINER_NAME>
kubectl logs <POD_NAME> --all-containers
```

**С фильтрацией времени:**

```bash
kubectl logs <POD_NAME> --since=1h
kubectl logs <POD_NAME> --since=10m
kubectl logs <POD_NAME> --since-time=2024-01-01T00:00:00Z
```

**Tail логов:**

```bash
kubectl logs <POD_NAME> -f
kubectl logs <POD_NAME> --tail=100
kubectl logs <POD_NAME> --tail=100 -f
```

| Флаг | Описание |
|------|----------|
| `-f, --follow` | Stream логов в реальном времени |
| `--tail` | Количество последних строк для вывода |
| `--since` | Логи за указанный период (1h, 30m, 60s) |
| `--since-time` | Логи начиная с timestamp (RFC3339) |
| `--timestamps` | Включение timestamps в вывод |
| `--prefix` | Префикс с именем pod для каждой строки |
| `--all-containers` | Логи всех контейнеров в pod |
| `-c, --container` | Указать контейнер в multi-container pod |
| `--previous` | Логи предыдущего экземпляра контейнера |
| `--limit-bytes` | Ограничение размера логов (байты) |
| `--max-log-requests` | Максимум параллельных запросов |
| `--insecure-skip-tls-verify-backend` | Пропустить TLS верификацию backend |

**Логи init containers:**

```bash
kubectl logs <POD_NAME> -c <INIT_CONTAINER_NAME>
kubectl logs <POD_NAME> -c <INIT_CONTAINER_NAME> --previous
```

**Логи после краша:**

```bash
kubectl logs <POD_NAME> --previous
kubectl logs <POD_NAME> -c <CONTAINER_NAME> --previous
```

Флаг `--previous` показывает логи предыдущего terminated контейнера.

**Множественные pods:**

```bash
kubectl logs -l app=nginx
kubectl logs -l app=nginx --all-containers=true
kubectl logs -l app=nginx --max-log-requests=10
```

### Выполнение команд в Pod

**Базовый exec:**

```bash
kubectl exec <POD_NAME> -- <command>
kubectl exec <POD_NAME> -- ls /app
kubectl exec <POD_NAME> -- env
```

**Interactive shell:**

```bash
kubectl exec -it <POD_NAME> -- /bin/bash
kubectl exec -it <POD_NAME> -- /bin/sh
kubectl exec -it <POD_NAME> -- sh
```

**Multi-container pod:**

```bash
kubectl exec <POD_NAME> -c <CONTAINER_NAME> -- <command>
kubectl exec -it <POD_NAME> -c <CONTAINER_NAME> -- sh
```

**С переменными окружения:**

```bash
kubectl exec <POD_NAME> -- env
kubectl exec <POD_NAME> -- printenv
```

| Флаг | Описание |
|------|----------|
| `-it` | Interactive TTY |
| `-c, --container` | Указать контейнер |
| `--stdin` | Передать stdin в контейнер |
| `--tty` | Выделить TTY |
| `--pod-running-timeout` | Таймаут ожидания running статуса |

### Attach к Pod

```bash
kubectl attach <POD_NAME>
kubectl attach <POD_NAME> -c <CONTAINER_NAME>
kubectl attach <POD_NAME> -it
```

Подключение к stdin/stdout/stderr running контейнера.

### Port forwarding

**К Pod:**

```bash
kubectl port-forward <POD_NAME> <LOCAL_PORT>:<POD_PORT>
kubectl port-forward pod/<POD_NAME> 8080:80
kubectl port-forward <POD_NAME> 8080:80 --address=0.0.0.0
```

**К Service:**

```bash
kubectl port-forward service/<SERVICE_NAME> <LOCAL_PORT>:<SERVICE_PORT>
kubectl port-forward svc/<SERVICE_NAME> 8080:80
```

**К Deployment:**

```bash
kubectl port-forward deployment/<DEPLOYMENT_NAME> <LOCAL_PORT>:<POD_PORT>
kubectl port-forward deploy/<DEPLOYMENT_NAME> 8080:80
```

| Флаг | Описание |
|------|----------|
| `--address` | IP адрес для bind (default localhost) |
| `--pod-running-timeout` | Таймаут ожидания running pod |

**Множественные порты:**

```bash
kubectl port-forward <POD_NAME> 8080:80 8443:443
```

### Копирование файлов

**Из pod на локальную систему:**

```bash
kubectl cp <POD_NAME>:/path/to/file /local/path
kubectl cp <POD_NAME>:/app/logs/app.log ./app.log
```

**С локальной системы в pod:**

```bash
kubectl cp /local/path <POD_NAME>:/path/to/file
kubectl cp ./config.yaml <POD_NAME>:/etc/config/config.yaml
```

**Multi-container pod:**

```bash
kubectl cp <POD_NAME>:/path/to/file /local/path -c <CONTAINER_NAME>
```

**Директории:**

```bash
kubectl cp <POD_NAME>:/app/logs ./logs
kubectl cp ./configs <POD_NAME>:/etc/configs
```

| Флаг | Описание |
|------|----------|
| `-c, --container` | Указать контейнер |
| `--no-preserve` | Не сохранять права доступа |
| `--retries` | Количество повторов при ошибке |

### Удаление Pod

```bash
kubectl delete pod <POD_NAME>
kubectl delete pods -l app=nginx
kubectl delete pod <POD_NAME> --force --grace-period=0
kubectl delete pod <POD_NAME> --wait=false
```

---

## Deployment операции

### Создание Deployment

**Императивное создание:**

```bash
kubectl create deployment <n> --image=<IMAGE>
kubectl create deployment nginx --image=nginx:1.21
kubectl create deployment app --image=app:v1 --replicas=3
kubectl create deployment app --image=app:v1 --port=8080
```

| Флаг | Описание |
|------|----------|
| `--image` | Container image |
| `--replicas` | Количество реплик (default 1) |
| `--port` | Container port |
| `--env` | Environment переменные |
| `--dry-run` | Тестовый запуск |
| `--save-config` | Сохранение конфигурации в аннотации |

**Генерация YAML:**

```bash
kubectl create deployment nginx --image=nginx:1.21 --dry-run=client -o yaml > deployment.yaml
```

**Из файла:**

```bash
kubectl apply -f deployment.yaml
kubectl create -f deployment.yaml
```

### Просмотр Deployment

```bash
kubectl get deployments
kubectl get deployment <n>
kubectl get deploy <n> -o wide
kubectl describe deployment <n>
```

**Статус развертывания:**

```bash
kubectl rollout status deployment/<n>
kubectl rollout status deploy/<n> --watch
```

**История ревизий:**

```bash
kubectl rollout history deployment/<n>
kubectl rollout history deployment/<n> --revision=<NUMBER>
```

### Масштабирование Deployment

**Ручное масштабирование:**

```bash
kubectl scale deployment <n> --replicas=<COUNT>
kubectl scale deployment nginx --replicas=5
kubectl scale deployment nginx --replicas=0
```

**С условием:**

```bash
kubectl scale deployment nginx --current-replicas=3 --replicas=5
```

Масштабирование только если текущее количество реплик соответствует условию.

**Автомасштабирование:**

```bash
kubectl autoscale deployment <n> --min=<MIN> --max=<MAX> --cpu-percent=<PERCENT>
kubectl autoscale deployment nginx --min=2 --max=10 --cpu-percent=80
```

Создание HorizontalPodAutoscaler для deployment.

### Обновление Deployment

**Обновление образа:**

```bash
kubectl set image deployment/<n> <CONTAINER>=<IMAGE>
kubectl set image deployment/nginx nginx=nginx:1.22
kubectl set image deployment/app *=app:v2
```

Использование `*` обновляет все контейнеры в pod template.

**Обновление через edit:**

```bash
kubectl edit deployment <n>
```

**Обновление через patch:**

```bash
kubectl patch deployment <n> -p '{"spec":{"replicas":5}}'
kubectl patch deployment <n> --type='json' -p='[{"op": "replace", "path": "/spec/replicas", "value":5}]'
```

**Обновление через apply:**

```bash
kubectl apply -f deployment.yaml
```

### Rollout управление

**Пауза rollout:**

```bash
kubectl rollout pause deployment/<n>
```

Приостановка rollout для внесения множественных изменений.

**Возобновление rollout:**

```bash
kubectl rollout resume deployment/<n>
```

**Откат к предыдущей версии:**

```bash
kubectl rollout undo deployment/<n>
kubectl rollout undo deployment/<n> --to-revision=<NUMBER>
```

**Перезапуск Deployment:**

```bash
kubectl rollout restart deployment/<n>
```

Перезапуск всех pods с текущей конфигурацией.

### Стратегии обновления

**RollingUpdate параметры в манифесте:**

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

| Параметр | Описание |
|----------|----------|
| `maxSurge` | Максимум дополнительных pods сверх desired |
| `maxUnavailable` | Максимум unavailable pods во время update |

**Recreate стратегия:**

```yaml
spec:
  strategy:
    type: Recreate
```

Все pods удаляются перед созданием новых.

---

## ReplicaSet операции

### Просмотр ReplicaSet

```bash
kubectl get replicasets
kubectl get rs
kubectl get rs <n>
kubectl describe rs <n>
```

**Связанные с Deployment:**

```bash
kubectl get rs -l app=<DEPLOYMENT_NAME>
```

### Масштабирование ReplicaSet

```bash
kubectl scale replicaset <n> --replicas=<COUNT>
kubectl scale rs <n> --replicas=3
```

Прямое масштабирование ReplicaSet обычно не рекомендуется - используй Deployment.

### Удаление ReplicaSet

```bash
kubectl delete replicaset <n>
kubectl delete rs <n> --cascade=orphan
```

Флаг `--cascade=orphan` сохраняет pods при удалении ReplicaSet.

---

## StatefulSet операции

### Создание StatefulSet

```bash
kubectl apply -f statefulset.yaml
```

StatefulSet обычно создается декларативно через манифест.

### Просмотр StatefulSet

```bash
kubectl get statefulsets
kubectl get sts
kubectl get sts <n>
kubectl describe sts <n>
```

**Pods StatefulSet:**

```bash
kubectl get pods -l app=<STATEFULSET_NAME>
```

Pods создаются с предсказуемыми именами: `<NAME>-0`, `<NAME>-1`, `<NAME>-2`.

### Масштабирование StatefulSet

```bash
kubectl scale statefulset <n> --replicas=<COUNT>
kubectl scale sts <n> --replicas=5
```

Масштабирование происходит последовательно по одному pod.

### Обновление StatefulSet

**Стратегия RollingUpdate:**

```bash
kubectl set image statefulset/<n> <CONTAINER>=<IMAGE>
kubectl set image sts/<n> app=app:v2
```

**Partition update:**

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 3
```

Обновляются только pods с ordinal >= partition.

**OnDelete стратегия:**

```yaml
spec:
  updateStrategy:
    type: OnDelete
```

Pods обновляются только при ручном удалении.

### Rollout управление

```bash
kubectl rollout status statefulset/<n>
kubectl rollout history statefulset/<n>
kubectl rollout undo statefulset/<n>
kubectl rollout restart statefulset/<n>
```

### Удаление StatefulSet

```bash
kubectl delete statefulset <n>
kubectl delete sts <n> --cascade=orphan
```

Флаг `--cascade=orphan` сохраняет pods и PVCs при удалении StatefulSet.

**Каскадное удаление:**

```bash
kubectl delete sts <n> --cascade=foreground
kubectl delete sts <n> --cascade=background
```

---

## DaemonSet операции

### Создание DaemonSet

```bash
kubectl apply -f daemonset.yaml
```

DaemonSet создается декларативно через манифест.

### Просмотр DaemonSet

```bash
kubectl get daemonsets
kubectl get ds
kubectl get ds <n>
kubectl describe ds <n>
```

**Pods DaemonSet:**

```bash
kubectl get pods -l app=<DAEMONSET_NAME> -o wide
```

DaemonSet создает по одному pod на каждой node.

### Обновление DaemonSet

**Обновление образа:**

```bash
kubectl set image daemonset/<n> <CONTAINER>=<IMAGE>
kubectl set image ds/<n> app=app:v2
```

**Стратегия RollingUpdate:**

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
```

**OnDelete стратегия:**

```yaml
spec:
  updateStrategy:
    type: OnDelete
```

### Rollout управление

```bash
kubectl rollout status daemonset/<n>
kubectl rollout history daemonset/<n>
kubectl rollout undo daemonset/<n>
kubectl rollout restart daemonset/<n>
```

### Node selector

**Добавление node selector:**

```bash
kubectl patch daemonset <n> -p '{"spec":{"template":{"spec":{"nodeSelector":{"disktype":"ssd"}}}}}'
```

**Tolerations для специальных nodes:**

```yaml
spec:
  template:
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
```

---

## Job операции

### Создание Job

**Императивное создание:**

```bash
kubectl create job <n> --image=<IMAGE>
kubectl create job test --image=busybox -- echo "Hello World"
kubectl create job backup --image=backup:v1 -- /backup.sh
```

**Генерация YAML:**

```bash
kubectl create job test --image=busybox --dry-run=client -o yaml > job.yaml
```

**Из CronJob:**

```bash
kubectl create job <n> --from=cronjob/<CRONJOB_NAME>
```

Создание Job из CronJob template для немедленного выполнения.

### Просмотр Job

```bash
kubectl get jobs
kubectl get job <n>
kubectl describe job <n>
```

**Pods Job:**

```bash
kubectl get pods -l job-name=<JOB_NAME>
```

### Мониторинг Job

```bash
kubectl wait --for=condition=complete job/<n> --timeout=300s
kubectl wait --for=condition=failed job/<n> --timeout=300s
```

**Логи Job:**

```bash
kubectl logs job/<n>
kubectl logs -l job-name=<JOB_NAME>
```

### Параллельность Job

**Манифест с параллельностью:**

```yaml
spec:
  completions: 5
  parallelism: 2
  backoffLimit: 3
```

| Параметр | Описание |
|----------|----------|
| `completions` | Количество успешных завершений |
| `parallelism` | Количество параллельных pods |
| `backoffLimit` | Лимит повторных попыток при ошибке |
| `activeDeadlineSeconds` | Максимальное время выполнения |
| `ttlSecondsAfterFinished` | TTL для автоудаления после завершения |

### Удаление Job

```bash
kubectl delete job <n>
kubectl delete job <n> --cascade=orphan
```

**Автоудаление после завершения:**

```yaml
spec:
  ttlSecondsAfterFinished: 100
```

Job автоматически удалится через 100 секунд после завершения.

---

## CronJob операции

### Создание CronJob

**Императивное создание:**

```bash
kubectl create cronjob <n> --image=<IMAGE> --schedule="<CRON>"
kubectl create cronjob backup --image=backup:v1 --schedule="0 2 * * *" -- /backup.sh
kubectl create cronjob report --image=report:v1 --schedule="*/15 * * * *" -- /report.sh
```

Формат cron: `минута час день месяц день_недели`.

| Выражение | Описание |
|-----------|----------|
| `* * * * *` | Каждую минуту |
| `*/5 * * * *` | Каждые 5 минут |
| `0 * * * *` | Каждый час |
| `0 0 * * *` | Каждый день в полночь |
| `0 2 * * *` | Каждый день в 02:00 |
| `0 0 * * 0` | Каждое воскресенье в полночь |
| `0 0 1 * *` | Первый день месяца в полночь |

### Просмотр CronJob

```bash
kubectl get cronjobs
kubectl get cj
kubectl get cj <n>
kubectl describe cj <n>
```

**Jobs созданные CronJob:**

```bash
kubectl get jobs -l app=<CRONJOB_NAME>
```

### Управление CronJob

**Приостановка выполнения:**

```bash
kubectl patch cronjob <n> -p '{"spec":{"suspend":true}}'
```

**Возобновление выполнения:**

```bash
kubectl patch cronjob <n> -p '{"spec":{"suspend":false}}'
```

**Немедленный запуск:**

```bash
kubectl create job --from=cronjob/<n> <JOB_NAME>
```

### Конфигурация CronJob

```yaml
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Allow
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  startingDeadlineSeconds: 200
```

| Параметр | Описание |
|----------|----------|
| `concurrencyPolicy` | Политика одновременного выполнения (Allow/Forbid/Replace) |
| `successfulJobsHistoryLimit` | Количество успешных Jobs для хранения |
| `failedJobsHistoryLimit` | Количество failed Jobs для хранения |
| `startingDeadlineSeconds` | Deadline для старта пропущенного Job |
| `suspend` | Приостановка выполнения |

**ConcurrencyPolicy значения:**

| Значение | Поведение |
|----------|-----------|
| `Allow` | Разрешить одновременное выполнение |
| `Forbid` | Запретить, пропустить новый если предыдущий еще running |
| `Replace` | Отменить running и запустить новый |

---

## Labels и Selectors

### Управление Labels

**Добавление label:**

```bash
kubectl label pods <POD_NAME> <KEY>=<VALUE>
kubectl label deployment <n> version=v1.0
```

**Обновление label:**

```bash
kubectl label pods <POD_NAME> <KEY>=<NEW_VALUE> --overwrite
```

**Удаление label:**

```bash
kubectl label pods <POD_NAME> <KEY>-
```

**Множественные labels:**

```bash
kubectl label pods <POD_NAME> app=nginx env=prod version=1.0
```

### Selector в Deployment

```yaml
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
        version: v1
```

`matchLabels` в selector должны совпадать с labels в pod template.

### Selector выражения

```yaml
spec:
  selector:
    matchExpressions:
    - key: tier
      operator: In
      values:
      - frontend
      - backend
    - key: environment
      operator: NotIn
      values:
      - dev
```

| Operator | Описание |
|----------|----------|
| `In` | Значение в списке |
| `NotIn` | Значение не в списке |
| `Exists` | Label существует |
| `DoesNotExist` | Label не существует |

---

## Resource Management

### Resource Requests и Limits

**В манифесте:**

```yaml
spec:
  containers:
  - name: app
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "200m"
```

**Императивно при создании:**

```bash
kubectl run nginx --image=nginx --requests='cpu=100m,memory=256Mi' --limits='cpu=200m,memory=512Mi'
```

**Обновление через patch:**

```bash
kubectl patch deployment <n> -p '{"spec":{"template":{"spec":{"containers":[{"name":"<CONTAINER>","resources":{"requests":{"cpu":"100m"}}}]}}}}'
```

### QoS классы

| QoS класс | Условие |
|-----------|---------|
| Guaranteed | Requests == Limits для всех ресурсов |
| Burstable | Requests < Limits или только Requests |
| BestEffort | Нет Requests и Limits |

**Проверка QoS:**

```bash
kubectl get pod <POD_NAME> -o jsonpath='{.status.qosClass}'
```

### LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
spec:
  limits:
  - max:
      cpu: "1"
      memory: "1Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "200m"
      memory: "256Mi"
    type: Container
```

LimitRange устанавливает default значения для namespace.

### ResourceQuota

```bash
kubectl create quota <n> --hard=pods=10,services=5
kubectl get resourcequota
kubectl describe quota <n>
```

Ограничение ресурсов на уровне namespace.

---

## Troubleshooting

### Распространенные проблемы Pod

**ImagePullBackOff:**

```bash
kubectl describe pod <POD_NAME>
kubectl get events --field-selector involvedObject.name=<POD_NAME>
```

Проверка правильности имени image и доступа к registry.

**CrashLoopBackOff:**

```bash
kubectl logs <POD_NAME>
kubectl logs <POD_NAME> --previous
kubectl describe pod <POD_NAME>
```

Анализ логов для определения причины краша.

**Pending статус:**

```bash
kubectl describe pod <POD_NAME>
kubectl get nodes
kubectl top nodes
```

Проверка availability ресурсов на nodes.

**Failed статус:**

```bash
kubectl logs <POD_NAME>
kubectl describe pod <POD_NAME>
kubectl get events --sort-by='.lastTimestamp'
```

### Проверка состояния

**Deployment статус:**

```bash
kubectl rollout status deployment/<n>
kubectl get deployment <n> -o wide
kubectl describe deployment <n>
```

**Pod readiness:**

```bash
kubectl wait --for=condition=ready pod/<POD_NAME> --timeout=60s
kubectl get pod <POD_NAME> -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

**Container статус:**

```bash
kubectl get pod <POD_NAME> -o jsonpath='{.status.containerStatuses[*].ready}'
kubectl get pod <POD_NAME> -o jsonpath='{.status.containerStatuses[*].state}'
```