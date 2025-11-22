# Helm и шаблонизация манифестов

Разработка параметризованных Helm чартов с условной логикой и управление множественными релизами через Helmfile для staging/production окружений.

## Предварительные требования

- Kubernetes кластер >= 1.28
- Helm >= 3.19
- kubectl с настроенным kubeconfig
- just для автоматизации (опционально)

---

## Helm чарт с шаблонизацией

### Helm vs Ansible: сравнение подходов

| Аспект | Ansible | Helm |
|--------|---------|------|
| Scope | Universal (servers, network, cloud) | Kubernetes-specific |
| Approach | Imperative (steps sequence) | Declarative (desired state) |
| Lifecycle | Stateless | Stateful (release history) |
| Rollback | Manual | Built-in `helm rollback` |
| Package | Roles/Collections | Charts (versioned) |
| Templates | Jinja2 | Go templates |

**Helm специализация:**
- Release management (upgrade/rollback/history)
- Dependencies между charts
- Hooks для lifecycle events (pre-install, post-upgrade)
- Chart repositories (ArtifactHub, custom repos)
- Values inheritance и overrides

**В итоге:** Helm = package manager для K8s с template engine и release management, Ansible = universal orchestration для любой инфраструктуры.

### Создание структуры чарта

Генерация стандартной структуры:
```bash
mkdir -p ~/helm-lab
cd ~/helm-lab
helm create webapp
```

Структура чарта:
```
webapp/
├── Chart.yaml              # Metadata чарта
├── values.yaml             # Default values
├── templates/
│   ├── deployment.yaml     # Deployment template
│   ├── service.yaml        # Service template
│   ├── _helpers.tpl        # Template helpers
│   └── NOTES.txt          # Post-install notes
└── charts/                # Dependencies
```

Очистка ненужных templates:
```bash
rm webapp/templates/serviceaccount.yaml
rm webapp/templates/ingress.yaml
rm webapp/templates/hpa.yaml
rm webapp/templates/httproute.yaml
rm -rf webapp/templates/tests
```

### Конфигурация values.yaml

Параметризация приложения:
```yaml
# Application settings
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"

service:
  type: ClusterIP
  port: 80

# Database settings
database:
  enabled: true
  image: postgres:15.3
  storageSize: 5Gi
  password: changeme

# Cache settings
enableCache: false
cache:
  image: redis:7-alpine
  replicas: 1
  resources:
    limits:
      memory: 256Mi
      cpu: 200m
    requests:
      memory: 128Mi
      cpu: 100m

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: false
```

Values организованы в секции:
- `replicaCount` - количество реплик webapp
- `database.*` - параметры PostgreSQL
- `enableCache` - флаг для условного создания cache
- `cache.*` - параметры Redis cache

### Template для Database

Database deployment с условием:
```yaml
{{- if .Values.database.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "webapp.fullname" . }}-database
  labels:
    app: database
    {{- include "webapp.labels" . | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      {{- include "webapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        app: database
        {{- include "webapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: postgres
        image: {{ .Values.database.image }}
        env:
        - name: POSTGRES_PASSWORD
          value: {{ .Values.database.password }}
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          limits:
            memory: 512Mi
            cpu: 500m
          requests:
            memory: 256Mi
            cpu: 250m
{{- end }}
```

Условие `{{- if .Values.database.enabled }}` позволяет включать/отключать database через values.

Database service:
```yaml
{{- if .Values.database.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "webapp.fullname" . }}-database
  labels:
    {{- include "webapp.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  selector:
    app: database
    {{- include "webapp.selectorLabels" . | nindent 4 }}
{{- end }}
```

### Template для Cache с условной логикой

Cache deployment создается только при `enableCache: true`:
```yaml
{{- if .Values.enableCache }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "webapp.fullname" . }}-cache
  labels:
    app: cache
    {{- include "webapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.cache.replicas }}
  selector:
    matchLabels:
      app: cache
      {{- include "webapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        app: cache
        {{- include "webapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: redis
        image: {{ .Values.cache.image }}
        ports:
        - containerPort: 6379
          name: redis
        resources:
          {{- toYaml .Values.cache.resources | nindent 10 }}
{{- end }}
```

`{{- toYaml .Values.cache.resources | nindent 10 }}` вставляет YAML блок с правильным отступом.

Cache service:
```yaml
{{- if .Values.enableCache }}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "webapp.fullname" . }}-cache
  labels:
    {{- include "webapp.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
    protocol: TCP
    name: redis
  selector:
    app: cache
    {{- include "webapp.selectorLabels" . | nindent 4 }}
{{- end }}
```

### Параметризация Deployment

Обновление webapp deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "webapp.fullname" . }}
  labels:
    {{- include "webapp.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "webapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "webapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

Template использует:
- `.Values.*` - значения из values.yaml
- `.Chart.*` - metadata из Chart.yaml
- `include "webapp.fullname"` - helper функции из _helpers.tpl

### Валидация чарта

Проверка синтаксиса:
```bash
helm lint webapp
```

Lint проверяет:
- YAML синтаксис
- Template корректность
- Required fields в Chart.yaml
- Best practices

Генерация манифестов без установки:
```bash
helm template webapp webapp | head -50
```

Template рендерит все files с default values, показывает финальные manifests.

### Установка и upgrade

Установка чарта:
```bash
helm install webapp-release webapp --namespace default
```

Проверка развернутых ресурсов:
```bash
helm list
kubectl get pods
kubectl get svc
```

По умолчанию развернуто:
- 2 webapp replicas
- 1 database pod
- Database и webapp services
- Cache отсутствует (enableCache: false)

Upgrade с изменением параметров:
```bash
helm upgrade webapp-release webapp --set enableCache=true --set replicaCount=3
```

Параметры `--set` переопределяют values.yaml:
- enableCache=true создает cache deployment
- replicaCount=3 увеличивает webapp replicas

Проверка изменений:
```bash
kubectl get pods
```

Появляется cache pod, третья webapp replica создается.

### Release history и rollback

Просмотр истории релиза:
```bash
helm history webapp-release
```

Вывод показывает:
- REVISION - номер версии
- STATUS - deployed/superseded
- DESCRIPTION - тип операции

Проверка текущих values:
```bash
helm get values webapp-release
```

Показывает только user-supplied values (переопределенные через --set).

Откат к предыдущей ревизии:
```bash
helm rollback webapp-release 1
```

Rollback восстанавливает конфигурацию ревизии 1:
- Cache pod удаляется
- Webapp возвращается к 2 репликам
- Создается новая ревизия с типом "Rollback to 1"

Проверка после rollback:
```bash
kubectl get pods
helm history webapp-release
```

---

## Helmfile для multi-environment

### Установка Helmfile

Скачивание и установка:
```bash
curl -fsSL https://github.com/helmfile/helmfile/releases/download/v0.169.1/helmfile_0.169.1_linux_amd64.tar.gz -o helmfile.tar.gz
tar -xzf helmfile.tar.gz
sudo mv helmfile /usr/local/bin/
chmod +x /usr/local/bin/helmfile
```

Проверка версии:
```bash
helmfile version
```

Helmfile предоставляет:
- Декларативное описание множественных releases
- Environment-specific values
- Dependency management между charts
- Diff перед применением (через helm-diff plugin)

### Установка helm-diff plugin
```bash
helm plugin install https://github.com/databus23/helm-diff
```

Plugin обязателен для helmfile - используется для расчета изменений перед apply.

### Создание независимых чартов

Структура для database:
```bash
helm create database-chart
rm database-chart/templates/*.yaml database-chart/templates/NOTES.txt
rm -rf database-chart/templates/tests
```

Database deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "database-chart.fullname" . }}
  labels:
    {{- include "database-chart.labels" . | nindent 4 }}
spec:
  replicas: 1
  selector:
    matchLabels:
      {{- include "database-chart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "database-chart.selectorLabels" . | nindent 8 }}
    spec:
      containers:
      - name: postgres
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        env:
        - name: POSTGRES_PASSWORD
          value: {{ .Values.password }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
```

Database service и values аналогично webapp паттерну.

Структура для cache:
```bash
helm create cache-chart
rm cache-chart/templates/*.yaml cache-chart/templates/NOTES.txt
rm -rf cache-chart/templates/tests
```

Cache deployment и service с параметризацией replicas, resources.

### Конфигурация Helmfile

Helmfile с environment support:
```yaml
repositories:
  - name: stable
    url: https://charts.helm.sh/stable

environments:
  staging:
    values:
      - environments/staging.yaml
  production:
    values:
      - environments/production.yaml

releases:
  - name: webapp
    chart: ./webapp
    namespace: {{ .Environment.Name }}
    values:
      - replicaCount: {{ .Values.webapp.replicas }}
      - image:
          tag: {{ .Values.webapp.imageTag }}
      - database:
          enabled: false
      - enableCache: {{ .Values.webapp.enableCache }}
      
  - name: database
    chart: ./database-chart
    namespace: {{ .Environment.Name }}
    values:
      - password: {{ .Values.database.password }}
      
  - name: cache
    chart: ./cache-chart
    namespace: {{ .Environment.Name }}
    condition: cache.enabled
    values:
      - replicaCount: {{ .Values.cache.replicas }}
```

Helmfile использует:
- `{{ .Environment.Name }}` - текущий environment (staging/production)
- `{{ .Values.* }}` - values из environment-specific файлов
- `condition` - условное развертывание release

### Environment-specific values

Staging конфигурация (`environments/staging.yaml`):
```yaml
webapp:
  replicas: 1
  imageTag: "1.25"
  enableCache: false

database:
  password: staging-pass

cache:
  enabled: false
  replicas: 1
```

Staging использует минимальные ресурсы:
- 1 webapp replica
- Cache отключен
- Слабый password (не production)

Production конфигурация (`environments/production.yaml`):
```yaml
webapp:
  replicas: 3
  imageTag: "1.25"
  enableCache: true

database:
  password: production-pass

cache:
  enabled: true
  replicas: 2
```

Production конфигурация с HA:
- 3 webapp replicas
- Cache включен с 2 репликами
- Отдельный password

### Развертывание окружений

Создание namespaces:
```bash
kubectl create namespace staging
kubectl create namespace production
```

Dry-run staging:
```bash
helmfile -e staging template
```

Template показывает финальные manifests без применения.

Применение staging:
```bash
helmfile -e staging apply
```

Helmfile выполняет:
- Diff текущего и желаемого состояния
- Установку/upgrade releases
- Вывод summary по изменениям

Проверка staging:
```bash
kubectl get pods -n staging
kubectl get svc -n staging
```

Staging содержит:
- 1 webapp pod
- 1 database pod
- Сервисы для webapp и database
- Cache отсутствует

Применение production:
```bash
helmfile -e production apply
```

Проверка production:
```bash
kubectl get pods -n production
```

Production содержит:
- 3 webapp pods
- 1 database pod
- 2 cache pods
- Соответствующие services

Сравнение environments:
```bash
echo "=== STAGING ==="
kubectl get pods -n staging

echo "=== PRODUCTION ==="
kubectl get pods -n production
```

### Управление releases через Helmfile

Список managed releases:
```bash
helmfile -e staging list
helmfile -e production list
```

Показывает ENABLED/INSTALLED статус для каждого release.

Проверка через Helm:
```bash
helm list --all-namespaces
```

Все releases управляются Helmfile, но видимы через стандартный Helm CLI.

Sync изменений:
```bash
# После изменения values
helmfile -e production sync
```

Sync = diff + apply в одной команде.

Удаление environment:
```bash
helmfile -e staging destroy
```

Destroy удаляет все releases из environment.

---

## Troubleshooting

### Helm template rendering error

**Симптомы:**
- `helm install` возвращает template error
- Невозможно отрендерить chart

**Ошибка:**
```
Error: template: webapp/templates/NOTES.txt:2:14: executing "webapp/templates/NOTES.txt" 
at <.Values.httpRoute.enabled>: nil pointer evaluating interface {}.enabled
```

**Причина:** Template ссылается на несуществующее значение в values.yaml.

**Решение:**

Удаление проблемного template:
```bash
rm webapp/templates/NOTES.txt
```

Или добавление значения в values.yaml:
```yaml
httpRoute:
  enabled: false
```

**Проверка:**
```bash
helm template webapp webapp
```

### Helmfile: unknown command "diff"

**Симптомы:**
- `helmfile apply` возвращает ошибку
- helm-diff plugin отсутствует

**Ошибка:**
```
Error: unknown command "diff" for "helm"
```

**Причина:** Helmfile требует helm-diff plugin для расчета изменений.

**Решение:**
```bash
helm plugin install https://github.com/databus23/helm-diff
```

**Проверка:**
```bash
helm plugin list
helmfile -e staging diff
```

### Values не применяются

**Симптомы:**
- `helm upgrade --set` не изменяет параметры
- Pods остаются с старыми значениями

**Причина:** Template не использует .Values или кэширование образов.

**Решение:**

Проверка template:
```bash
helm template webapp webapp --set replicaCount=5 | grep -A 5 "kind: Deployment"
```

Должно показать `replicas: 5`.

Принудительный пересоздание pods:
```bash
kubectl rollout restart deployment -n default
```

**Проверка:**
```bash
kubectl get pods
```

### Helmfile: environment values not loaded

**Симптомы:**
- Helmfile использует default values вместо environment-specific
- Staging и production идентичны

**Ошибка:**
```
WARNING: environments and releases cannot be defined within the same YAML part
```

**Причина:** YAML структура helmfile.yaml некорректна.

**Решение:**

Разделение environments и releases через `---`:
```yaml
environments:
  staging:
    values:
      - environments/staging.yaml
---
releases:
  - name: webapp
    chart: ./webapp
```

**Проверка:**
```bash
helmfile -e staging template | grep "replicas:"
```

Должно показать значение из staging.yaml.

### Release stuck in pending-upgrade

**Симптомы:**
- `helm list` показывает pending-upgrade
- Невозможно upgrade или rollback

**Причина:** Предыдущий upgrade прерван, lock не освобожден.

**Решение:**

Просмотр secrets с release history:
```bash
kubectl get secrets -n default | grep webapp-release
```

Удаление pending upgrade secret:
```bash
kubectl delete secret -n default sh.helm.release.v1.webapp-release.v3
```

**Проверка:**
```bash
helm list
helm history webapp-release
```

---

## Best Practices

**Chart Development:**
- Версионировать charts в Git
- Использовать semver для Chart.yaml version
- Документировать все values в README
- Добавлять default values для всех параметров
- Тестировать templates с разными values комбинациями

**Values Organization:**
- Группировать values логически (database.*, cache.*)
- Использовать nested структуры вместо flat
- Избегать глубокой вложенности (>3 уровней)
- Документировать ranges и constraints
- Предоставлять secure defaults

**Template Best Practices:**
- Использовать `{{- }}` для trim whitespace
- Применять `toYaml` для вставки блоков
- Добавлять conditions для optional ресурсов
- Использовать _helpers.tpl для reusable logic
- Избегать сложной логики в templates

**Helmfile Patterns:**
- Разделять environments в отдельные файлы
- Использовать condition для optional releases
- Группировать related charts
- Версионировать helmfile.yaml
- Тестировать на staging перед production

**Security:**
- Не хранить secrets в values.yaml
- Использовать external secret management (SOPS, Vault)
- Применять RBAC для Helm operations
- Audit логировать helm operations
- Использовать signed charts для production

---

## Полезные команды

### Helm Chart Operations
```bash
# Создание чарта
helm create mychart

# Lint чарта
helm lint mychart

# Template рендеринг
helm template myrelease mychart
helm template myrelease mychart --debug

# Template с values
helm template myrelease mychart -f custom-values.yaml
helm template myrelease mychart --set key=value

# Package чарта
helm package mychart
```

### Helm Release Management
```bash
# Установка
helm install myrelease mychart
helm install myrelease mychart -n namespace --create-namespace

# Upgrade
helm upgrade myrelease mychart
helm upgrade myrelease mychart --set key=value
helm upgrade --install myrelease mychart

# Список releases
helm list
helm list --all-namespaces
helm list -n namespace

# Статус релиза
helm status myrelease
helm get values myrelease
helm get manifest myrelease

# История
helm history myrelease

# Rollback
helm rollback myrelease 1
helm rollback myrelease

# Удаление
helm uninstall myrelease
helm uninstall myrelease --keep-history
```

### Helmfile Operations
```bash
# Template рендеринг
helmfile -e staging template
helmfile -e production template

# Diff изменений
helmfile -e staging diff

# Применение
helmfile -e staging apply
helmfile -e staging sync

# Список releases
helmfile -e staging list

# Удаление
helmfile -e staging destroy
helmfile -e staging delete
```

### Debugging
```bash
# Dry-run install
helm install myrelease mychart --dry-run --debug

# Values precedence
helm install myrelease mychart --dry-run --debug -f values1.yaml -f values2.yaml --set key=value

# Template specific file
helm template myrelease mychart -s templates/deployment.yaml

# Показать используемые values
helm get values myrelease --all
```
