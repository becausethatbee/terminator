# kubectl - Базовые операции

Справочник базовых команд kubectl для работы с ресурсами Kubernetes.

## Предварительные требования

- kubectl версии 1.28+
- Доступ к Kubernetes кластеру
- Настроенный kubeconfig файл

---

## Синтаксис команд

### Общая структура

```bash
kubectl [command] [TYPE] [NAME] [flags]
```

**Компоненты:**
- `command` - операция (get, create, apply, delete)
- `TYPE` - тип ресурса (pod, deployment, service)
- `NAME` - имя конкретного ресурса
- `flags` - опциональные флаги

### Сокращения типов ресурсов

| Полное имя | Сокращение | Множественное число |
|------------|------------|---------------------|
| pod | po | pods |
| service | svc | services |
| deployment | deploy | deployments |
| replicaset | rs | replicasets |
| statefulset | sts | statefulsets |
| daemonset | ds | daemonsets |
| namespace | ns | namespaces |
| configmap | cm | configmaps |
| secret | secret | secrets |
| persistentvolume | pv | persistentvolumes |
| persistentvolumeclaim | pvc | persistentvolumeclaims |
| storageclass | sc | storageclasses |
| ingress | ing | ingresses |
| networkpolicy | netpol | networkpolicies |

---

## Глобальные флаги

### Основные флаги

```bash
kubectl get pods -n production
kubectl get pods --all-namespaces
kubectl get pods -o yaml
```

| Флаг | Короткая форма | Описание |
|------|----------------|----------|
| `--namespace` | `-n` | Указать namespace для операции |
| `--all-namespaces` | `-A` | Работа со всеми namespaces |
| `--output` | `-o` | Формат вывода результата |
| `--selector` | `-l` | Фильтрация по label selector |
| `--field-selector` | | Фильтрация по полям метаданных |
| `--watch` | `-w` | Мониторинг изменений в реальном времени |
| `--dry-run` | | Тестовый запуск без применения изменений |
| `--force` | | Принудительное выполнение операции |
| `--grace-period` | | Период ожидания перед удалением (секунды) |
| `--filename` | `-f` | Путь к файлу манифеста |
| `--recursive` | `-R` | Рекурсивная обработка директорий |
| `--kubeconfig` | | Путь к файлу kubeconfig |
| `--context` | | Использовать указанный context |
| `--cluster` | | Использовать указанный cluster |
| `--user` | | Использовать указанные credentials |
| `--request-timeout` | | Таймаут для запроса к API |
| `--v` | | Уровень детализации логов (0-10) |

### Форматы вывода

```bash
kubectl get pods -o json
kubectl get pods -o yaml
kubectl get pods -o wide
kubectl get pods -o name
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
```

| Формат | Описание |
|--------|----------|
| `json` | JSON формат полного объекта |
| `yaml` | YAML формат полного объекта |
| `wide` | Дополнительные колонки в табличном формате |
| `name` | Только тип и имя ресурса |
| `jsonpath` | Выборка данных через JSONPath выражение |
| `jsonpath-file` | JSONPath выражение из файла |
| `custom-columns` | Пользовательские колонки |
| `custom-columns-file` | Пользовательские колонки из файла |
| `go-template` | Go template форматирование |
| `go-template-file` | Go template из файла |

### Селекторы

**Label селекторы:**

```bash
kubectl get pods -l app=nginx
kubectl get pods -l 'app in (nginx,apache)'
kubectl get pods -l 'app,env=production'
kubectl get pods -l 'app!=nginx'
kubectl get pods -l 'version'
kubectl get pods -l '!version'
```

| Оператор | Синтаксис | Описание |
|----------|-----------|----------|
| Equality | `key=value` | Точное совпадение |
| Inequality | `key!=value` | Не равно |
| Set | `key in (value1,value2)` | Значение в множестве |
| Not in set | `key notin (value1,value2)` | Значение не в множестве |
| Exists | `key` | Label существует |
| Not exists | `!key` | Label не существует |

**Field селекторы:**

```bash
kubectl get pods --field-selector status.phase=Running
kubectl get pods --field-selector metadata.namespace!=default
kubectl get pods --field-selector status.phase=Running,spec.nodeName=<NODE_NAME>
```

| Поле | Применимо к |
|------|-------------|
| `metadata.name` | Все ресурсы |
| `metadata.namespace` | Все namespaced ресурсы |
| `status.phase` | Pod |
| `spec.nodeName` | Pod |
| `spec.restartPolicy` | Pod |
| `spec.schedulerName` | Pod |
| `spec.serviceAccountName` | Pod |
| `status.podIP` | Pod |

---

## Get - Просмотр ресурсов

### Базовый синтаксис

```bash
kubectl get <resource>
kubectl get <resource> <name>
kubectl get <resource> -n <namespace>
```

### Примеры использования

**Список ресурсов:**

```bash
kubectl get pods
kubectl get pods -n kube-system
kubectl get pods --all-namespaces
kubectl get pods -A
```

**Детальная информация:**

```bash
kubectl get pods -o wide
kubectl get pods -o yaml
kubectl get pods -o json
```

Флаг `-o wide` добавляет колонки: IP, Node, Nominated Node, Readiness Gates.

**Мониторинг изменений:**

```bash
kubectl get pods -w
kubectl get pods --watch-only
```

Отображение изменений в реальном времени.

**Фильтрация:**

```bash
kubectl get pods -l app=nginx
kubectl get pods --field-selector status.phase=Running
kubectl get pods -l app=nginx --field-selector status.phase=Running
```

Комбинирование label и field селекторов.

**Сортировка:**

```bash
kubectl get pods --sort-by='.metadata.creationTimestamp'
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
```

Сортировка по JSONPath выражению.

**Множественные типы:**

```bash
kubectl get pods,services
kubectl get all
kubectl get all -A
```

Получение нескольких типов ресурсов одновременно.

### Специальные флаги

```bash
kubectl get pods --show-labels
kubectl get pods --show-kind
kubectl get pods --no-headers
kubectl get pods --chunk-size=500
```

| Флаг | Описание |
|------|----------|
| `--show-labels` | Отображение всех labels в отдельной колонке |
| `--show-kind` | Добавление колонки с типом ресурса |
| `--label-columns` | Указать labels для отдельных колонок |
| `--no-headers` | Вывод без заголовков таблицы |
| `--chunk-size` | Размер пакета данных от API |
| `--ignore-not-found` | Не выводить ошибку если ресурс не найден |
| `--export` | Экспорт без cluster-specific полей (deprecated) |

### Custom columns

```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
kubectl get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName
```

Создание пользовательского табличного вывода.

**Примеры выборки данных:**

```bash
kubectl get pods -o custom-columns='NAME:.metadata.name,IMAGES:.spec.containers[*].image'
kubectl get nodes -o custom-columns='NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory'
```

---

## Describe - Детальная информация

### Базовый синтаксис

```bash
kubectl describe <resource> <name>
kubectl describe <resource>/<name>
kubectl describe -f <file>
```

### Примеры использования

**Детали ресурса:**

```bash
kubectl describe pod <POD_NAME>
kubectl describe node <NODE_NAME>
kubectl describe service <SERVICE_NAME>
```

Вывод включает: метаданные, спецификацию, состояние, события.

**Множественные ресурсы:**

```bash
kubectl describe pods
kubectl describe nodes
```

Описание всех ресурсов указанного типа в namespace.

**С селекторами:**

```bash
kubectl describe pods -l app=nginx
kubectl describe pods --field-selector status.phase=Running
```

**Из файла:**

```bash
kubectl describe -f deployment.yaml
kubectl describe -f configs/
```

---

## Create - Создание ресурсов

### Базовый синтаксис

```bash
kubectl create -f <file>
kubectl create <resource> <name> [flags]
```

### Создание из файла

```bash
kubectl create -f pod.yaml
kubectl create -f https://example.com/manifest.yaml
kubectl create -f configs/ --recursive
```

Создание ресурсов из локального файла, URL или директории.

### Императивное создание

**Namespace:**

```bash
kubectl create namespace <NAMESPACE_NAME>
kubectl create ns <NAMESPACE_NAME>
```

**Deployment:**

```bash
kubectl create deployment <NAME> --image=<IMAGE>
kubectl create deployment nginx --image=nginx:1.21
kubectl create deployment app --image=app:v1 --replicas=3
kubectl create deployment app --image=app:v1 --port=8080
```

| Флаг | Описание |
|------|----------|
| `--image` | Container image для использования |
| `--replicas` | Количество реплик |
| `--port` | Порт который открывает контейнер |
| `--env` | Environment переменные (KEY=VALUE) |
| `--command` | Переопределение команды контейнера |
| `--dry-run` | Режим тестирования |
| `--save-config` | Сохранение конфигурации в аннотации |

**Service:**

```bash
kubectl create service clusterip <NAME> --tcp=<PORT>:<TARGET_PORT>
kubectl create service nodeport <NAME> --tcp=<PORT>:<TARGET_PORT> --node-port=<NODE_PORT>
kubectl create service loadbalancer <NAME> --tcp=<PORT>:<TARGET_PORT>
```

**Service для существующего ресурса:**

```bash
kubectl expose deployment <NAME> --port=<PORT> --target-port=<TARGET_PORT>
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl expose pod <POD_NAME> --port=<PORT> --name=<SERVICE_NAME>
```

**ConfigMap:**

```bash
kubectl create configmap <NAME> --from-file=<PATH>
kubectl create configmap <NAME> --from-file=<KEY>=<PATH>
kubectl create configmap <NAME> --from-literal=<KEY>=<VALUE>
kubectl create configmap <NAME> --from-env-file=<PATH>
```

| Источник | Описание |
|----------|----------|
| `--from-file` | Файл или директория |
| `--from-literal` | Пары ключ-значение через CLI |
| `--from-env-file` | Env-файл формата KEY=VALUE |

**Secret:**

```bash
kubectl create secret generic <NAME> --from-file=<PATH>
kubectl create secret generic <NAME> --from-literal=<KEY>=<VALUE>
kubectl create secret docker-registry <NAME> --docker-server=<SERVER> --docker-username=<USER> --docker-password=<PASS> --docker-email=<EMAIL>
kubectl create secret tls <NAME> --cert=<CERT_FILE> --key=<KEY_FILE>
```

| Тип | Использование |
|-----|---------------|
| `generic` | Произвольные данные |
| `docker-registry` | Credentials для container registry |
| `tls` | TLS сертификат и ключ |

**ServiceAccount:**

```bash
kubectl create serviceaccount <NAME>
kubectl create sa <NAME>
```

**Job:**

```bash
kubectl create job <NAME> --image=<IMAGE>
kubectl create job test --image=busybox -- echo "Hello World"
kubectl create job test --image=busybox --dry-run=client -o yaml > job.yaml
```

**CronJob:**

```bash
kubectl create cronjob <NAME> --image=<IMAGE> --schedule="<CRON>"
kubectl create cronjob backup --image=backup:v1 --schedule="0 2 * * *" -- /backup.sh
```

Формат cron: минута час день месяц день_недели.

### Специальные флаги

```bash
kubectl create -f manifest.yaml --dry-run=client
kubectl create -f manifest.yaml --dry-run=server
kubectl create -f manifest.yaml --validate=true
kubectl create -f manifest.yaml --save-config
kubectl create -f manifest.yaml --record
```

| Флаг | Описание |
|------|----------|
| `--dry-run=client` | Валидация на стороне клиента |
| `--dry-run=server` | Валидация на стороне сервера |
| `--validate` | Schema валидация манифеста |
| `--save-config` | Сохранение текущей конфигурации в аннотации |
| `--record` | Запись команды в аннотацию (deprecated) |
| `--edit` | Редактирование перед созданием |
| `--windows-line-endings` | Использование Windows line endings |

---

## Apply - Применение конфигурации

### Базовый синтаксис

```bash
kubectl apply -f <file>
kubectl apply -k <directory>
```

### Декларативное управление

```bash
kubectl apply -f deployment.yaml
kubectl apply -f https://example.com/manifest.yaml
kubectl apply -f configs/ --recursive
```

Создание или обновление ресурсов из файлов.

### Server-Side Apply

```bash
kubectl apply -f manifest.yaml --server-side
kubectl apply -f manifest.yaml --server-side --field-manager=<MANAGER_NAME>
kubectl apply -f manifest.yaml --server-side --force-conflicts
```

| Флаг | Описание |
|------|----------|
| `--server-side` | Применение изменений на стороне сервера |
| `--field-manager` | Имя field manager для tracking изменений |
| `--force-conflicts` | Принудительное разрешение конфликтов полей |

Server-side apply решает проблемы с field ownership и concurrent updates.

### Kustomize

```bash
kubectl apply -k ./kustomization/
kubectl apply -k https://github.com/user/repo/kustomization
```

Применение манифестов с Kustomize трансформациями.

### Специальные флаги

```bash
kubectl apply -f manifest.yaml --dry-run=client -o yaml
kubectl apply -f manifest.yaml --dry-run=server
kubectl apply -f manifest.yaml --prune -l app=nginx
kubectl apply -f manifest.yaml --cascade=background
kubectl apply -f manifest.yaml --wait
kubectl apply -f manifest.yaml --timeout=5m
```

| Флаг | Описание |
|------|----------|
| `--dry-run` | Тестовый запуск без применения |
| `--prune` | Удаление ресурсов не в конфигурации |
| `--prune-whitelist` | Разрешенные для prune типы |
| `--cascade` | Стратегия cascade удаления (background/foreground/orphan) |
| `--wait` | Ожидание готовности ресурса |
| `--timeout` | Таймаут для wait операции |
| `--overwrite` | Автоматическое разрешение конфликтов |
| `--validate` | Schema валидация |

---

## Delete - Удаление ресурсов

### Базовый синтаксис

```bash
kubectl delete <resource> <name>
kubectl delete -f <file>
```

### Удаление по имени

```bash
kubectl delete pod <POD_NAME>
kubectl delete deployment <DEPLOYMENT_NAME>
kubectl delete service <SERVICE_NAME>
```

### Удаление из файла

```bash
kubectl delete -f pod.yaml
kubectl delete -f configs/ --recursive
```

### Удаление по селектору

```bash
kubectl delete pods -l app=nginx
kubectl delete all -l app=nginx
kubectl delete pods --field-selector status.phase=Failed
```

Удаление всех ресурсов соответствующих селектору.

### Удаление всех ресурсов типа

```bash
kubectl delete pods --all
kubectl delete all --all
kubectl delete all --all -n <NAMESPACE>
```

Удаление всех ресурсов указанного типа в namespace.

### Grace period и force

```bash
kubectl delete pod <POD_NAME> --grace-period=0
kubectl delete pod <POD_NAME> --grace-period=0 --force
kubectl delete pod <POD_NAME> --now
```

| Флаг | Описание |
|------|----------|
| `--grace-period` | Время ожидания перед SIGKILL (секунды) |
| `--force` | Немедленное удаление без graceful shutdown |
| `--now` | Alias для --grace-period=1 |

Значение `--grace-period=0 --force` используется для принудительного удаления застрявших pod.

### Cascade deletion

```bash
kubectl delete deployment <NAME> --cascade=orphan
kubectl delete deployment <NAME> --cascade=background
kubectl delete deployment <NAME> --cascade=foreground
```

| Режим | Описание |
|-------|----------|
| `background` | Асинхронное удаление зависимых ресурсов (default) |
| `foreground` | Ожидание удаления зависимых перед удалением owner |
| `orphan` | Оставить зависимые ресурсы без удаления |

### Специальные флаги

```bash
kubectl delete pod <POD_NAME> --wait=false
kubectl delete -f manifest.yaml --ignore-not-found
kubectl delete pods --all --dry-run=client
```

| Флаг | Описание |
|------|----------|
| `--wait` | Ожидание завершения удаления |
| `--timeout` | Таймаут для операции удаления |
| `--ignore-not-found` | Не выводить ошибку если ресурс не найден |
| `--dry-run` | Показать что будет удалено без удаления |

---

## Replace - Замена ресурса

### Базовый синтаксис

```bash
kubectl replace -f <file>
```

### Примеры использования

```bash
kubectl replace -f pod.yaml
kubectl replace -f https://example.com/manifest.yaml
```

Полная замена существующего ресурса новым манифестом.

### Force replace

```bash
kubectl replace -f pod.yaml --force
kubectl replace -f deployment.yaml --force --grace-period=0
```

Флаг `--force` удаляет и пересоздает ресурс.

### Cascade replace

```bash
kubectl replace -f deployment.yaml --cascade=background
kubectl replace -f deployment.yaml --cascade=orphan
```

---

## Diff - Сравнение конфигураций

### Базовый синтаксис

```bash
kubectl diff -f <file>
```

### Примеры использования

```bash
kubectl diff -f deployment.yaml
kubectl diff -f configs/ --recursive
kubectl diff -k ./kustomization/
```

Отображение различий между текущей конфигурацией в кластере и файлом манифеста.

### Server-side diff

```bash
kubectl diff -f manifest.yaml --server-side
```

Сравнение для server-side apply.

---

## Wait - Ожидание условий

### Базовый синтаксис

```bash
kubectl wait <resource> <name> --for=<condition>
```

### Примеры использования

**Ожидание готовности:**

```bash
kubectl wait pod/<POD_NAME> --for=condition=Ready --timeout=60s
kubectl wait deployment/<NAME> --for=condition=Available --timeout=5m
```

**Ожидание удаления:**

```bash
kubectl wait pod/<POD_NAME> --for=delete --timeout=60s
```

**С селекторами:**

```bash
kubectl wait pods -l app=nginx --for=condition=Ready --all
kubectl wait pods --for=condition=Ready --all -n production
```

### Поддерживаемые условия

| Ресурс | Условие |
|--------|---------|
| Pod | Ready, ContainersReady, Initialized, PodScheduled |
| Deployment | Available, Progressing |
| ReplicaSet | ReplicaFailure |
| Job | Complete, Failed |
| Service | LoadBalancerReady |

---

## Events - Просмотр событий

### Базовый синтаксис

```bash
kubectl get events
kubectl get events -n <namespace>
```

### Примеры использования

**Фильтрация:**

```bash
kubectl get events --field-selector involvedObject.name=<POD_NAME>
kubectl get events --field-selector type=Warning
kubectl get events --field-selector reason=Failed
```

**Сортировка:**

```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --sort-by='.metadata.creationTimestamp'
```

**Мониторинг:**

```bash
kubectl get events -w
kubectl get events --watch-only
```

---

## API Resources

### Просмотр доступных ресурсов

```bash
kubectl api-resources
kubectl api-resources --namespaced=true
kubectl api-resources --namespaced=false
kubectl api-resources -o wide
kubectl api-resources --api-group=apps
kubectl api-resources --verbs=list,get
```

| Флаг | Описание |
|------|----------|
| `--namespaced` | Фильтр по namespaced ресурсам |
| `--api-group` | Фильтр по API group |
| `--verbs` | Фильтр по поддерживаемым операциям |
| `--sort-by` | Сортировка по полю |
| `--cached` | Использование кэшированного списка |

### API Versions

```bash
kubectl api-versions
```

Список всех доступных API версий в кластере.

---

## Explain - Документация ресурсов

### Базовый синтаксис

```bash
kubectl explain <resource>
kubectl explain <resource>.<field>
```

### Примеры использования

**Документация ресурса:**

```bash
kubectl explain pod
kubectl explain deployment
kubectl explain service
```

**Вложенные поля:**

```bash
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain deployment.spec.template.spec.containers
```

**Рекурсивное отображение:**

```bash
kubectl explain pod --recursive
kubectl explain deployment.spec --recursive
```

Флаг `--recursive` выводит все вложенные поля структуры.

---

## Version - Информация о версии

```bash
kubectl version
kubectl version --short
kubectl version --client
kubectl version --output=yaml
kubectl version --output=json
```

Отображение версий kubectl клиента и Kubernetes API сервера.