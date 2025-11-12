# kubectl - Продвинутые операции

Справочник продвинутых команд kubectl: debug, patch, JSONPath, custom resources, plugin management.

## Предварительные требования

- kubectl версии 1.28+
- Доступ к Kubernetes кластеру
- Понимание JSON и YAML форматов

---

## Debug операции

### kubectl debug

**Debug существующего pod:**

```bash
kubectl debug <POD_NAME> -it --image=<DEBUG_IMAGE>
kubectl debug nginx -it --image=busybox
kubectl debug app -it --image=ubuntu --share-processes
```

| Флаг | Описание |
|------|----------|
| `--image` | Debug container image |
| `--share-processes` | Общий process namespace с pod |
| `--copy-to` | Создание копии pod для debugging |
| `--container` | Target container для debug |
| `--target` | Target container в shared process namespace |
| `--profile` | Debug profile (legacy/general/baseline/restricted) |

**Debug с копированием pod:**

```bash
kubectl debug <POD_NAME> -it --copy-to=<NEW_POD_NAME> --image=<IMAGE>
kubectl debug nginx -it --copy-to=nginx-debug --image=busybox
```

**Debug с изменением pod spec:**

```bash
kubectl debug nginx -it --copy-to=nginx-debug --container=nginx --image=nginx:debug --set-image=nginx=nginx:debug
```

**Debug на node:**

```bash
kubectl debug node/<NODE_NAME> -it --image=ubuntu
```

Создает privileged pod на node с host filesystem в `/host`.

**Доступ к node filesystem:**

```bash
kubectl debug node/<NODE_NAME> -it --image=ubuntu -- chroot /host
```

### Ephemeral containers

**Добавление ephemeral container:**

```yaml
kubectl debug <POD_NAME> -it --image=busybox --target=<CONTAINER_NAME>
```

Ephemeral containers добавляются к running pod для debugging.

**Проверка ephemeral containers:**

```bash
kubectl get pod <POD_NAME> -o jsonpath='{.spec.ephemeralContainers}'
```

---

## Patch операции

### Strategic Merge Patch

**Patch через JSON:**

```bash
kubectl patch <RESOURCE> <n> -p '<JSON_PATCH>'
kubectl patch deployment nginx -p '{"spec":{"replicas":3}}'
```

**Patch через YAML:**

```bash
kubectl patch deployment nginx -p '
spec:
  replicas: 5
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:1.22
'
```

**Patch из файла:**

```bash
kubectl patch deployment nginx --patch-file=patch.yaml
```

**Добавление label:**

```bash
kubectl patch pod <POD_NAME> -p '{"metadata":{"labels":{"env":"production"}}}'
```

**Удаление label:**

```bash
kubectl patch pod <POD_NAME> -p '{"metadata":{"labels":{"env":null}}}'
```

### JSON Patch

```bash
kubectl patch <RESOURCE> <n> --type='json' -p='<JSON_PATCH_ARRAY>'
kubectl patch deployment nginx --type='json' -p='[{"op":"replace","path":"/spec/replicas","value":5}]'
```

**JSON Patch операции:**

| Операция | Описание |
|----------|----------|
| add | Добавление значения |
| remove | Удаление значения |
| replace | Замена значения |
| move | Перемещение значения |
| copy | Копирование значения |
| test | Проверка значения |

**Примеры JSON Patch:**

```bash
kubectl patch deployment nginx --type='json' -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/env","value":[{"name":"DEBUG","value":"true"}]},
  {"op":"replace","path":"/spec/replicas","value":3}
]'
```

**Удаление элемента:**

```bash
kubectl patch deployment nginx --type='json' -p='[{"op":"remove","path":"/spec/template/spec/containers/0/env/0"}]'
```

### Merge Patch

```bash
kubectl patch <RESOURCE> <n> --type='merge' -p='<JSON>'
kubectl patch service nginx --type='merge' -p '{"spec":{"type":"NodePort"}}'
```

Merge patch заменяет указанные поля полностью.

### Patch примеры

**Обновление image:**

```bash
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.22"}]}}}}'
```

**Добавление environment переменной:**

```bash
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","env":[{"name":"DEBUG","value":"true"}]}]}}}}'
```

**Изменение resource limits:**

```bash
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"limits":{"cpu":"500m","memory":"512Mi"}}}]}}}}'
```

**Добавление volume:**

```bash
kubectl patch deployment nginx -p '{"spec":{"template":{"spec":{"volumes":[{"name":"data","emptyDir":{}}]}}}}'
```

---

## JSONPath операции

### Базовый синтаксис

```bash
kubectl get <RESOURCE> -o jsonpath='{<JSONPATH_EXPRESSION>}'
```

**Извлечение поля:**

```bash
kubectl get pod <POD_NAME> -o jsonpath='{.metadata.name}'
kubectl get pod <POD_NAME> -o jsonpath='{.status.podIP}'
kubectl get pod <POD_NAME> -o jsonpath='{.spec.containers[0].image}'
```

**Множественные поля:**

```bash
kubectl get pod <POD_NAME> -o jsonpath='{.metadata.name}{"\t"}{.status.podIP}{"\n"}'
```

Использование `{"\t"}` для tab, `{"\n"}` для newline.

### Range выражения

**Итерация по массиву:**

```bash
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'
```

**Вложенные range:**

```bash
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{range .spec.containers[*]}{"\t"}{.name}{end}{"\n"}{end}'
```

### Фильтрация

**Filter по условию:**

```bash
kubectl get pods -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'
kubectl get nodes -o jsonpath='{.items[?(@.spec.unschedulable==true)].metadata.name}'
```

**Операторы фильтрации:**

| Оператор | Описание |
|----------|----------|
| `==` | Равно |
| `!=` | Не равно |
| `<` | Меньше |
| `>` | Больше |
| `<=` | Меньше или равно |
| `>=` | Больше или равно |

**Примеры фильтров:**

```bash
kubectl get pods -o jsonpath='{.items[?(@.status.containerStatuses[0].restartCount>5)].metadata.name}'
kubectl get services -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].metadata.name}'
```

### Сортировка

```bash
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get pods --sort-by=.status.startTime
kubectl get nodes --sort-by=.status.capacity.cpu
```

### Специальные функции

**Length:**

```bash
kubectl get deployments -o jsonpath='{.items[*].spec.replicas}' | wc -w
```

**Keys:**

```bash
kubectl get configmap <n> -o jsonpath='{.data}' | jq 'keys'
```

### Custom columns с JSONPath

```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP,NODE:.spec.nodeName
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```

**С range выражениями:**

```bash
kubectl get pods -o custom-columns='NAME:.metadata.name,IMAGES:.spec.containers[*].image'
```

### JSONPath примеры

**Все container images в namespace:**

```bash
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}' | tr -s '[[:space:]]' '\n' | sort | uniq
```

**Pod IPs и nodes:**

```bash
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\t"}{.spec.nodeName}{"\n"}{end}'
```

**Resource requests:**

```bash
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources.requests.cpu}{"\n"}{end}'
```

**Node capacity:**

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'
```

**Service external IPs:**

```bash
kubectl get services -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}'
```

**PVC binding status:**

```bash
kubectl get pvc -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.spec.volumeName}{"\n"}{end}'
```

---

## Go Template

### Базовый синтаксис

```bash
kubectl get pods -o go-template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'
```

**С функциями:**

```bash
kubectl get pods -o go-template='{{range .items}}{{.metadata.name | printf "%-30s"}}{{.status.phase}}{{"\n"}}{{end}}'
```

### Go Template функции

| Функция | Описание |
|---------|----------|
| `printf` | Форматирование строки |
| `len` | Длина массива/строки |
| `index` | Элемент массива по индексу |
| `upper` | Верхний регистр |
| `lower` | Нижний регистр |
| `title` | Title case |
| `trim` | Удаление пробелов |
| `default` | Значение по умолчанию |

**Примеры:**

```bash
kubectl get pods -o go-template='{{range .items}}{{.metadata.name | upper}}{{"\n"}}{{end}}'
kubectl get configmap <n> -o go-template='{{.data.key | default "N/A"}}'
```

### Go Template из файла

```bash
kubectl get pods -o go-template-file=template.txt
```

**template.txt:**

```
{{range .items}}
Name: {{.metadata.name}}
Status: {{.status.phase}}
IP: {{.status.podIP}}
{{end}}
```

---

## Custom Resource Definitions

### Просмотр CRD

```bash
kubectl get customresourcedefinitions
kubectl get crd
kubectl get crd <CRD_NAME>
kubectl describe crd <CRD_NAME>
```

**Список версий CRD:**

```bash
kubectl get crd <CRD_NAME> -o jsonpath='{.spec.versions[*].name}'
```

### Работа с Custom Resources

**Получение CR:**

```bash
kubectl get <CUSTOM_RESOURCE>
kubectl get <CUSTOM_RESOURCE> <n>
kubectl describe <CUSTOM_RESOURCE> <n>
```

**Создание CR:**

```bash
kubectl apply -f custom-resource.yaml
```

**Удаление CR:**

```bash
kubectl delete <CUSTOM_RESOURCE> <n>
```

### API Resources

```bash
kubectl api-resources
kubectl api-resources --namespaced=true
kubectl api-resources --api-group=<GROUP>
```

**Фильтрация по verbs:**

```bash
kubectl api-resources --verbs=list,get
kubectl api-resources --verbs=create,update,patch
```

**Короткие имена:**

```bash
kubectl api-resources -o wide
```

---

## Raw API запросы

### kubectl proxy

**Запуск proxy:**

```bash
kubectl proxy --port=8080
```

**API запрос через proxy:**

```bash
curl http://localhost:8080/api/v1/namespaces/default/pods
curl http://localhost:8080/apis/apps/v1/namespaces/default/deployments
```

### kubectl raw

```bash
kubectl get --raw <API_PATH>
kubectl get --raw /api/v1/namespaces/default/pods
kubectl get --raw /apis/apps/v1/namespaces/default/deployments
```

**Metrics API:**

```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /apis/metrics.k8s.io/v1beta1/pods
```

**Health endpoints:**

```bash
kubectl get --raw /healthz
kubectl get --raw /livez
kubectl get --raw /readyz
```

**API versions:**

```bash
kubectl get --raw /api
kubectl get --raw /apis
```

### POST/PUT/DELETE через raw

**POST запрос:**

```bash
kubectl create --raw /api/v1/namespaces/default/pods -f pod.json
```

**DELETE запрос:**

```bash
kubectl delete --raw /api/v1/namespaces/default/pods/<POD_NAME>
```

---

## Plugin управление

### Krew - plugin manager

**Установка Krew:**

```bash
kubectl krew install <PLUGIN>
kubectl krew install ctx
kubectl krew install ns
kubectl krew install view-secret
```

**Обновление plugins:**

```bash
kubectl krew update
kubectl krew upgrade
kubectl krew upgrade <PLUGIN>
```

**Список установленных plugins:**

```bash
kubectl krew list
```

**Поиск plugins:**

```bash
kubectl krew search <KEYWORD>
kubectl krew search secret
```

**Удаление plugin:**

```bash
kubectl krew uninstall <PLUGIN>
```

**Информация о plugin:**

```bash
kubectl krew info <PLUGIN>
```

### Популярные plugins

**ctx - context switching:**

```bash
kubectl ctx
kubectl ctx <CONTEXT_NAME>
kubectl ctx -
```

**ns - namespace switching:**

```bash
kubectl ns
kubectl ns <NAMESPACE>
kubectl ns -
```

**view-secret - декодирование secrets:**

```bash
kubectl view-secret <SECRET_NAME>
kubectl view-secret <SECRET_NAME> <KEY>
```

**node-shell - shell на node:**

```bash
kubectl node-shell <NODE_NAME>
```

**tree - иерархия ресурсов:**

```bash
kubectl tree deployment <n>
kubectl tree statefulset <n>
```

**tail - tail логов:**

```bash
kubectl tail <POD_NAME>
kubectl tail -l app=nginx
```

**images - список images:**

```bash
kubectl images
kubectl images -n <NAMESPACE>
```

**neat - очистка YAML:**

```bash
kubectl get pod <POD_NAME> -o yaml | kubectl neat
```

Удаляет managed fields и runtime metadata.

---

## Batch операции

### Множественные ресурсы

**Apply множественных файлов:**

```bash
kubectl apply -f file1.yaml -f file2.yaml -f file3.yaml
kubectl apply -f configs/
kubectl apply -f configs/ --recursive
```

**Delete множественных ресурсов:**

```bash
kubectl delete -f configs/
kubectl delete pod pod1 pod2 pod3
kubectl delete pods --all
```

### Dry run для batch операций

```bash
kubectl apply -f configs/ --dry-run=server
kubectl delete -f configs/ --dry-run=client
```

---

## Таймауты и retry

### Request timeout

```bash
kubectl get pods --request-timeout=5s
kubectl get nodes --request-timeout=10s
```

**Server timeout для watch:**

```bash
kubectl get pods -w --server-timeout=300s
```

### Chunk size для больших списков

```bash
kubectl get pods --chunk-size=500
kubectl get nodes --chunk-size=100
```

Размер batch для пагинации API запросов.

---

## Server-side operations

### Server-side apply

```bash
kubectl apply -f manifest.yaml --server-side
kubectl apply -f manifest.yaml --server-side --field-manager=<MANAGER_NAME>
kubectl apply -f manifest.yaml --server-side --force-conflicts
```

**Field manager:**

```bash
kubectl get <RESOURCE> <n> -o yaml | grep -A 10 managedFields
```

### Server-side dry run

```bash
kubectl apply -f manifest.yaml --dry-run=server
kubectl create -f manifest.yaml --dry-run=server
```

Server-side dry run валидирует через API server.

---

## Impersonation

### Выполнение от имени пользователя

```bash
kubectl get pods --as=<USER>
kubectl get deployments --as=alice
```

**От имени group:**

```bash
kubectl get pods --as=<USER> --as-group=<GROUP>
kubectl get nodes --as=john --as-group=system:masters
```

**От имени ServiceAccount:**

```bash
kubectl get pods --as=system:serviceaccount:<NAMESPACE>:<SA_NAME>
kubectl get secrets --as=system:serviceaccount:default:app-sa
```

### UID impersonation

```bash
kubectl get pods --as-uid=<UID>
```

---

## Field Selectors

### Поддерживаемые поля

**Pod:**

```bash
kubectl get pods --field-selector status.phase=Running
kubectl get pods --field-selector spec.nodeName=<NODE_NAME>
kubectl get pods --field-selector spec.restartPolicy=Always
```

**Node:**

```bash
kubectl get nodes --field-selector spec.unschedulable=false
```

**Event:**

```bash
kubectl get events --field-selector type=Warning
kubectl get events --field-selector reason=Failed
kubectl get events --field-selector involvedObject.name=<POD_NAME>
```

**Service:**

```bash
kubectl get services --field-selector spec.type=LoadBalancer
```

### Комбинирование селекторов

```bash
kubectl get pods --field-selector status.phase=Running,spec.nodeName=<NODE_NAME>
kubectl get pods -l app=nginx --field-selector status.phase=Running
```

---

## Прочие продвинутые операции

### Subresources

**Logs subresource:**

```bash
kubectl get pods/<POD_NAME>/log
```

**Status subresource:**

```bash
kubectl get deployments/<n>/status
```

**Scale subresource:**

```bash
kubectl get deployments/<n>/scale
```

### Watch с фильтрами

```bash
kubectl get pods -w --field-selector status.phase=Pending
kubectl get events -w --field-selector type=Warning
```

### Delete collection

```bash
kubectl delete pods --all
kubectl delete deployments --all -n <NAMESPACE>
kubectl delete all --all
```

Delete collection удаляет множественные ресурсы одной командой.

### Grace period fine tuning

```bash
kubectl delete pod <POD_NAME> --grace-period=30
kubectl delete pod <POD_NAME> --grace-period=0 --force
```

---

## Performance tuning

### Кэширование

**Список cached API resources:**

```bash
kubectl api-resources --cached
kubectl api-resources --no-headers=true --cached=false
```

### Compression

```bash
kubectl get pods --disable-compression=false
```

API response compression для экономии bandwidth.

### Paging

```bash
kubectl get pods --limit=100
kubectl get pods --limit=100 --continue=<CONTINUE_TOKEN>
```

---

## Troubleshooting продвинутых операций

### Debug JSONPath

**Проверка структуры:**

```bash
kubectl get <RESOURCE> <n> -o json | jq '.'
kubectl get <RESOURCE> <n> -o yaml
```

**Тест JSONPath выражения:**

```bash
kubectl get <RESOURCE> <n> -o jsonpath='{<EXPRESSION>}'
```

### Verbose mode

```bash
kubectl get pods -v=6
kubectl get pods -v=8
```

| Level | Детализация |
|-------|-------------|
| 0 | Только output команды |
| 1-5 | Базовая debug информация |
| 6 | HTTP request/response headers |
| 7 | HTTP request/response body |
| 8 | Полные HTTP exchanges |
| 9 | Максимальная детализация |

### API discovery issues

```bash
kubectl api-resources --cached=false
kubectl api-versions
```

### Plugin проблемы

```bash
kubectl krew list
kubectl plugin list
```

**Manual plugin execution:**

```bash
kubectl-<PLUGIN_NAME>
```

Plugins находятся в `$PATH` как `kubectl-<name>`.