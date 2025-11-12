# kubectl - Конфигурация и контексты

Справочник команд для управления ConfigMap, Secret, ServiceAccount, контекстами и kubeconfig.

## Предварительные требования

- kubectl версии 1.28+
- Доступ к Kubernetes кластеру
- Базовое понимание конфигурационных ресурсов

---

## ConfigMap операции

### Создание ConfigMap

**Из литеральных значений:**

```bash
kubectl create configmap <n> --from-literal=<KEY>=<VALUE>
kubectl create cm app-config --from-literal=env=production --from-literal=debug=false
```

**Из файла:**

```bash
kubectl create configmap <n> --from-file=<PATH>
kubectl create cm nginx-config --from-file=nginx.conf
kubectl create cm app-config --from-file=configs/
```

Имя ключа берется из имени файла.

**С пользовательским ключом:**

```bash
kubectl create configmap <n> --from-file=<KEY>=<PATH>
kubectl create cm app-config --from-file=config.json=/path/to/app-config.json
```

**Из env-файла:**

```bash
kubectl create configmap <n> --from-env-file=<PATH>
kubectl create cm app-env --from-env-file=.env
```

Формат env-файла:

```
KEY1=value1
KEY2=value2
```

**Комбинирование источников:**

```bash
kubectl create cm app-config --from-file=app.conf --from-literal=version=1.0 --from-env-file=.env
```

**Генерация YAML:**

```bash
kubectl create cm app-config --from-literal=key=value --dry-run=client -o yaml > configmap.yaml
```

**Из YAML манифеста:**

```bash
kubectl apply -f configmap.yaml
```

### Просмотр ConfigMap

```bash
kubectl get configmaps
kubectl get cm
kubectl get cm <n>
kubectl describe cm <n>
```

**Полный YAML вывод:**

```bash
kubectl get cm <n> -o yaml
kubectl get cm <n> -o json
```

**Извлечение конкретного ключа:**

```bash
kubectl get cm <n> -o jsonpath='{.data.<KEY>}'
kubectl get cm app-config -o jsonpath='{.data.env}'
```

**Список всех ключей:**

```bash
kubectl get cm <n> -o jsonpath='{.data}' | jq 'keys'
```

### Редактирование ConfigMap

**Интерактивное редактирование:**

```bash
kubectl edit cm <n>
```

**Через patch:**

```bash
kubectl patch cm <n> -p '{"data":{"<KEY>":"<NEW_VALUE>"}}'
kubectl patch cm app-config -p '{"data":{"env":"staging"}}'
```

**Замена из файла:**

```bash
kubectl create cm <n> --from-file=<PATH> --dry-run=client -o yaml | kubectl replace -f -
```

### Удаление ConfigMap

```bash
kubectl delete cm <n>
kubectl delete cm -l app=<LABEL>
```

### Использование ConfigMap в Pod

**Environment переменные из ConfigMap:**

```yaml
spec:
  containers:
  - name: app
    envFrom:
    - configMapRef:
        name: app-config
```

**Отдельные переменные:**

```yaml
spec:
  containers:
  - name: app
    env:
    - name: ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: env
```

**Volume из ConfigMap:**

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: config
      mountPath: /etc/config
  volumes:
  - name: config
    configMap:
      name: app-config
```

**Отдельные ключи как файлы:**

```yaml
volumes:
- name: config
  configMap:
    name: app-config
    items:
    - key: nginx.conf
      path: nginx.conf
    - key: app.conf
      path: app.conf
```

---

## Secret операции

### Создание Secret

**Generic secret из литералов:**

```bash
kubectl create secret generic <n> --from-literal=<KEY>=<VALUE>
kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password=<PASSWORD>
```

**Из файла:**

```bash
kubectl create secret generic <n> --from-file=<PATH>
kubectl create secret generic tls-cert --from-file=tls.crt --from-file=tls.key
```

**Из env-файла:**

```bash
kubectl create secret generic <n> --from-env-file=<PATH>
```

**Docker registry secret:**

```bash
kubectl create secret docker-registry <n> --docker-server=<SERVER> --docker-username=<USER> --docker-password=<PASS> --docker-email=<EMAIL>
kubectl create secret docker-registry regcred --docker-server=registry.example.com --docker-username=admin --docker-password=<PASSWORD>
```

**TLS secret:**

```bash
kubectl create secret tls <n> --cert=<CERT_FILE> --key=<KEY_FILE>
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key
```

**Generic secret с Base64 в манифесте:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
```

Values должны быть Base64 encoded.

**Secret с plain text в манифесте:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-creds
type: Opaque
stringData:
  username: admin
  password: password
```

`stringData` автоматически кодируется в Base64.

### Просмотр Secret

```bash
kubectl get secrets
kubectl get secret <n>
kubectl describe secret <n>
```

**Вывод с декодированием:**

```bash
kubectl get secret <n> -o yaml
kubectl get secret <n> -o json
```

**Декодирование конкретного ключа:**

```bash
kubectl get secret <n> -o jsonpath='{.data.<KEY>}' | base64 --decode
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d
```

Флаг `-d` для декодирования Base64.

**Извлечение всех значений:**

```bash
kubectl get secret <n> -o json | jq '.data | map_values(@base64d)'
```

### Редактирование Secret

**Интерактивное редактирование:**

```bash
kubectl edit secret <n>
```

**Через patch:**

```bash
kubectl patch secret <n> -p '{"stringData":{"<KEY>":"<NEW_VALUE>"}}'
```

**Обновление из файла:**

```bash
kubectl create secret generic <n> --from-file=<PATH> --dry-run=client -o yaml | kubectl apply -f -
```

### Удаление Secret

```bash
kubectl delete secret <n>
kubectl delete secret -l app=<LABEL>
```

### Типы Secret

| Тип | Назначение |
|-----|------------|
| `Opaque` | Произвольные пары ключ-значение (default) |
| `kubernetes.io/service-account-token` | ServiceAccount token |
| `kubernetes.io/dockercfg` | Docker config (legacy) |
| `kubernetes.io/dockerconfigjson` | Docker config JSON |
| `kubernetes.io/basic-auth` | Basic authentication credentials |
| `kubernetes.io/ssh-auth` | SSH authentication |
| `kubernetes.io/tls` | TLS сертификат и ключ |
| `bootstrap.kubernetes.io/token` | Bootstrap token |

### Использование Secret в Pod

**Environment переменные из Secret:**

```yaml
spec:
  containers:
  - name: app
    envFrom:
    - secretRef:
        name: db-creds
```

**Отдельные переменные:**

```yaml
spec:
  containers:
  - name: app
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-creds
          key: password
```

**Volume из Secret:**

```yaml
spec:
  containers:
  - name: app
    volumeMounts:
    - name: secrets
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secrets
    secret:
      secretName: db-creds
```

**ImagePullSecrets:**

```yaml
spec:
  imagePullSecrets:
  - name: regcred
```

**Права доступа к Secret файлам:**

```yaml
volumes:
- name: secrets
  secret:
    secretName: db-creds
    defaultMode: 0400
```

---

## ServiceAccount операции

### Создание ServiceAccount

```bash
kubectl create serviceaccount <n>
kubectl create sa <n>
```

**Генерация YAML:**

```bash
kubectl create sa app-sa --dry-run=client -o yaml > serviceaccount.yaml
```

### Просмотр ServiceAccount

```bash
kubectl get serviceaccounts
kubectl get sa
kubectl get sa <n>
kubectl describe sa <n>
```

**Связанные секреты:**

```bash
kubectl get sa <n> -o jsonpath='{.secrets[*].name}'
```

### ServiceAccount token

**Создание token (1.24+):**

```bash
kubectl create token <SA_NAME>
kubectl create token <SA_NAME> --duration=1h
kubectl create token <SA_NAME> --bound-object-kind=Pod --bound-object-name=<POD_NAME>
```

| Флаг | Описание |
|------|----------|
| `--duration` | Время жизни token (default 1h) |
| `--audience` | Intended audience для token |
| `--bound-object-kind` | Тип объекта для binding |
| `--bound-object-name` | Имя объекта для binding |

**Legacy token secret (до 1.24):**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: sa-token
  annotations:
    kubernetes.io/service-account.name: <SA_NAME>
type: kubernetes.io/service-account-token
```

### Использование ServiceAccount в Pod

```yaml
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: true
```

Параметр `automountServiceAccountToken` контролирует автоматический mount token.

### Удаление ServiceAccount

```bash
kubectl delete sa <n>
```

---

## Kubeconfig управление

### Структура kubeconfig

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <CA_DATA>
    server: https://<API_SERVER>:6443
  name: <CLUSTER_NAME>
contexts:
- context:
    cluster: <CLUSTER_NAME>
    user: <USER_NAME>
    namespace: default
  name: <CONTEXT_NAME>
current-context: <CONTEXT_NAME>
users:
- name: <USER_NAME>
  user:
    client-certificate-data: <CERT_DATA>
    client-key-data: <KEY_DATA>
```

### Просмотр конфигурации

**Полная конфигурация:**

```bash
kubectl config view
kubectl config view --raw
kubectl config view --minify
```

Флаг `--minify` показывает только текущий context.

**Текущий context:**

```bash
kubectl config current-context
```

**Список contexts:**

```bash
kubectl config get-contexts
kubectl config get-contexts -o name
```

**Список clusters:**

```bash
kubectl config get-clusters
```

**Список users:**

```bash
kubectl config get-users
```

### Управление Clusters

**Добавление cluster:**

```bash
kubectl config set-cluster <CLUSTER_NAME> --server=https://<API_SERVER>:6443 --certificate-authority=<CA_FILE>
kubectl config set-cluster <CLUSTER_NAME> --server=https://<API_SERVER>:6443 --insecure-skip-tls-verify=true
```

**Удаление cluster:**

```bash
kubectl config delete-cluster <CLUSTER_NAME>
```

**Установка параметров cluster:**

```bash
kubectl config set clusters.<CLUSTER_NAME>.server https://<NEW_SERVER>:6443
kubectl config set clusters.<CLUSTER_NAME>.certificate-authority-data <CA_DATA>
```

### Управление Users

**Добавление user с сертификатом:**

```bash
kubectl config set-credentials <USER_NAME> --client-certificate=<CERT_FILE> --client-key=<KEY_FILE>
```

**User с token:**

```bash
kubectl config set-credentials <USER_NAME> --token=<TOKEN>
```

**User с username/password:**

```bash
kubectl config set-credentials <USER_NAME> --username=<USER> --password=<PASS>
```

**User с exec provider:**

```bash
kubectl config set-credentials <USER_NAME> --exec-command=aws --exec-arg=eks --exec-arg=get-token --exec-arg=--cluster-name --exec-arg=<CLUSTER>
```

**Удаление user:**

```bash
kubectl config delete-user <USER_NAME>
```

### Управление Contexts

**Создание context:**

```bash
kubectl config set-context <CONTEXT_NAME> --cluster=<CLUSTER_NAME> --user=<USER_NAME> --namespace=<NAMESPACE>
```

**Переключение context:**

```bash
kubectl config use-context <CONTEXT_NAME>
```

**Установка namespace для context:**

```bash
kubectl config set-context <CONTEXT_NAME> --namespace=<NAMESPACE>
kubectl config set-context --current --namespace=<NAMESPACE>
```

Флаг `--current` применяет к текущему context.

**Переименование context:**

```bash
kubectl config rename-context <OLD_NAME> <NEW_NAME>
```

**Удаление context:**

```bash
kubectl config delete-context <CONTEXT_NAME>
```

### Работа с kubeconfig файлами

**Указание kubeconfig файла:**

```bash
kubectl --kubeconfig=<PATH> get pods
kubectl --kubeconfig=/path/to/config get nodes
```

**Environment переменная:**

```bash
export KUBECONFIG=/path/to/config
kubectl get pods
```

**Множественные kubeconfig:**

```bash
export KUBECONFIG=/path/to/config1:/path/to/config2
kubectl config view --flatten > merged-config
```

Объединение конфигураций из нескольких файлов.

**Изоляция kubeconfig:**

```bash
KUBECONFIG=/path/to/config kubectl get pods
```

Временное использование без изменения глобального KUBECONFIG.

### Установка параметров

**Unset параметра:**

```bash
kubectl config unset users.<USER_NAME>.password
kubectl config unset contexts.<CONTEXT_NAME>.namespace
```

**Установка current context:**

```bash
kubectl config set current-context <CONTEXT_NAME>
```

---

## Namespace операции

### Создание Namespace

```bash
kubectl create namespace <n>
kubectl create ns <n>
```

**Из файла:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <NAMESPACE_NAME>
```

```bash
kubectl apply -f namespace.yaml
```

### Просмотр Namespace

```bash
kubectl get namespaces
kubectl get ns
kubectl describe ns <n>
```

**Ресурсы в namespace:**

```bash
kubectl get all -n <NAMESPACE>
kubectl get pods,services -n <NAMESPACE>
```

### Переключение namespace

**В текущем context:**

```bash
kubectl config set-context --current --namespace=<NAMESPACE>
```

**Проверка текущего namespace:**

```bash
kubectl config view --minify | grep namespace
```

### Удаление Namespace

```bash
kubectl delete namespace <n>
kubectl delete ns <n>
```

Удаление namespace удаляет все ресурсы внутри него.

**Принудительное удаление застрявшего namespace:**

```bash
kubectl get namespace <n> -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/<n>/finalize" -f -
```

### ResourceQuota для Namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: <NAMESPACE>
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "100"
    services: "50"
    persistentvolumeclaims: "20"
```

```bash
kubectl apply -f resourcequota.yaml
kubectl get resourcequota -n <NAMESPACE>
kubectl describe quota compute-quota -n <NAMESPACE>
```

### LimitRange для Namespace

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: <NAMESPACE>
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

```bash
kubectl apply -f limitrange.yaml
kubectl get limitrange -n <NAMESPACE>
kubectl describe limitrange resource-limits -n <NAMESPACE>
```

---

## Annotations

### Управление Annotations

**Добавление annotation:**

```bash
kubectl annotate pods <POD_NAME> <KEY>=<VALUE>
kubectl annotate deployment <n> description="Production deployment"
```

**Обновление annotation:**

```bash
kubectl annotate pods <POD_NAME> <KEY>=<NEW_VALUE> --overwrite
```

**Удаление annotation:**

```bash
kubectl annotate pods <POD_NAME> <KEY>-
```

**Множественные annotations:**

```bash
kubectl annotate pods <POD_NAME> key1=value1 key2=value2 key3=value3
```

### Общие annotations

| Annotation | Назначение |
|------------|------------|
| `kubernetes.io/change-cause` | Причина изменения для rollout history |
| `kubectl.kubernetes.io/last-applied-configuration` | Последняя примененная конфигурация |
| `kubernetes.io/ingress.class` | Класс Ingress controller |
| `prometheus.io/scrape` | Включение scraping Prometheus |
| `prometheus.io/port` | Порт для Prometheus scraping |
| `prometheus.io/path` | Path для Prometheus metrics |

### Просмотр annotations

```bash
kubectl describe <resource> <n>
kubectl get <resource> <n> -o jsonpath='{.metadata.annotations}'
```

---

## Environment переменные

### Определение env в Pod

**Литеральные значения:**

```yaml
spec:
  containers:
  - name: app
    env:
    - name: ENV
      value: "production"
    - name: LOG_LEVEL
      value: "info"
```

**Из ConfigMap:**

```yaml
env:
- name: CONFIG_ENV
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: env
```

**Из Secret:**

```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-creds
      key: password
```

**Из Field selectors:**

```yaml
env:
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
```

**Из Resource limits:**

```yaml
env:
- name: CPU_LIMIT
  valueFrom:
    resourceFieldRef:
      containerName: app
      resource: limits.cpu
- name: MEMORY_REQUEST
  valueFrom:
    resourceFieldRef:
      resource: requests.memory
      divisor: 1Mi
```

### EnvFrom для импорта всех ключей

**Из ConfigMap:**

```yaml
spec:
  containers:
  - name: app
    envFrom:
    - configMapRef:
        name: app-config
```

**Из Secret:**

```yaml
envFrom:
- secretRef:
    name: db-creds
```

**С префиксом:**

```yaml
envFrom:
- configMapRef:
    name: app-config
  prefix: APP_
```

Все ключи получат префикс `APP_`.

### Проверка environment переменных

```bash
kubectl exec <POD_NAME> -- env
kubectl exec <POD_NAME> -- printenv
kubectl exec <POD_NAME> -- printenv <VAR_NAME>
```

---

## Cluster Info

### Информация о кластере

```bash
kubectl cluster-info
kubectl cluster-info dump
kubectl cluster-info dump --output-directory=/path/to/dump
```

**Адрес API server:**

```bash
kubectl cluster-info | grep "Kubernetes control plane"
```

**Адреса сервисов:**

```bash
kubectl cluster-info | grep -E "CoreDNS|Metrics"
```

### Component статусы

```bash
kubectl get componentstatuses
kubectl get cs
```

Проверка состояния control plane компонентов: scheduler, controller-manager, etcd.

### API Server endpoint

```bash
kubectl config view -o jsonpath='{.clusters[0].cluster.server}'
```

---

## Authentication и Authorization

### Проверка доступа

**Can-I проверки:**

```bash
kubectl auth can-i <VERB> <RESOURCE>
kubectl auth can-i create pods
kubectl auth can-i delete deployments
kubectl auth can-i get nodes
```

**От имени другого пользователя:**

```bash
kubectl auth can-i create pods --as=<USER>
kubectl auth can-i delete deployments --as=system:serviceaccount:<NAMESPACE>:<SA_NAME>
```

**В определенном namespace:**

```bash
kubectl auth can-i create pods -n <NAMESPACE>
kubectl auth can-i delete deployments --all-namespaces
```

**Список разрешенных действий:**

```bash
kubectl auth can-i --list
kubectl auth can-i --list --as=<USER>
kubectl auth can-i --list -n <NAMESPACE>
```

### Who Am I

```bash
kubectl auth whoami
kubectl auth whoami -o yaml
```

Отображение текущего user/serviceaccount и групп.

---

## Troubleshooting

### Проблемы с ConfigMap

**ConfigMap не монтируется:**

```bash
kubectl describe pod <POD_NAME>
kubectl get events --field-selector involvedObject.name=<POD_NAME>
```

Проверка существования ConfigMap и корректности имени.

**Изменения не применяются:**

ConfigMap обновления не триггерят перезапуск pods. Требуется:

```bash
kubectl rollout restart deployment/<n>
```

### Проблемы с Secret

**Secret не найден:**

```bash
kubectl get secret <n>
kubectl describe pod <POD_NAME>
```

**ImagePullBackOff с docker-registry secret:**

```bash
kubectl get secret <REGCRED_NAME> -o yaml
kubectl describe pod <POD_NAME>
```

Проверка корректности credentials и imagePullSecrets в pod spec.

### Проблемы с Context

**Context не переключается:**

```bash
kubectl config use-context <CONTEXT_NAME>
kubectl config current-context
```

**Ресурсы не видны:**

```bash
kubectl config get-contexts
kubectl config view --minify
```

Проверка namespace в текущем context.

**Connection refused:**

```bash
kubectl config view -o jsonpath='{.clusters[*].cluster.server}'
kubectl cluster-info
```

Проверка доступности API server endpoint.