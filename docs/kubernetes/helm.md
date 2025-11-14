# Helm: Управление приложениями в Kubernetes

Практическое руководство по работе с Helm 3 для развертывания, управления и автоматизации приложений в Kubernetes.

---

## Предварительные требования

- Kubernetes кластер (minikube, kind или production)
- kubectl v1.31.0+
- Helm 3.16.0+
- Git для версионирования
- Базовые знания Kubernetes (Deployment, Service, Pod)

---

## Синтаксис шаблонов Helm

### Основные конструкции

**Вставка значений:**
```yaml
{{ .Values.image.repository }}
{{ .Values.replicaCount }}
```

**Значения по умолчанию:**
```yaml
{{ .Values.image.tag | default .Chart.AppVersion }}
```

**Условия:**
```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
{{- end }}
```

**Циклы:**
```yaml
{{- range .Values.dynamicPods }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
{{- end }}
```

**Helper функции:**
```yaml
{{ include "myapp.fullname" . }}
{{ include "myapp.labels" . | nindent 4 }}
```

**Контекст в циклах:**
```yaml
{{- range .Values.items }}
  name: {{ include "myapp.fullname" $ }}-{{ .name }}
{{- end }}
```

`$` - корневой контекст, `.` - текущий элемент цикла.

### Специальные объекты

| Объект | Описание |
|--------|----------|
| .Values | Значения из values.yaml |
| .Chart | Метаданные из Chart.yaml |
| .Release | Информация о релизе |
| .Files | Доступ к файлам чарта |
| .Capabilities | Информация о Kubernetes |

---

## Приоритеты значений

Helm объединяет значения из нескольких источников с определенным приоритетом:

**Порядок приоритета (от низшего к высшему):**

1. **Дефолтный values.yaml** (в чарте)
2. **Кастомный файл** через `-f custom.yaml`
3. **Флаг --set** через командную строку

**Пример:**

Дефолтный values.yaml:
```yaml
replicaCount: 1
service:
  type: ClusterIP
  port: 80
```

Кастомный prod-values.yaml:
```yaml
replicaCount: 3
service:
  type: LoadBalancer
```

Команда:
```bash
helm install myapp ./chart -f prod-values.yaml --set service.port=8080
```

Результат:
```yaml
replicaCount: 3           # из prod-values.yaml
service:
  type: LoadBalancer      # из prod-values.yaml
  port: 8080              # из --set (наивысший приоритет)
```

### Механизм слияния

Helm выполняет **глубокое слияние** (deep merge) на уровне ключей:
- Если ключ есть в кастомном файле, он заменяет дефолтное значение
- Вложенные объекты объединяются рекурсивно
- Массивы заменяются полностью, не объединяются

---

## Установка Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Проверка версии:

```bash
helm version
```

---

## Создание базового Helm-чарта

### Генерация структуры

```bash
helm create myapp
```

Создается стандартная структура:

```
myapp/
├── Chart.yaml              # Метаданные чарта
├── values.yaml             # Значения по умолчанию
├── charts/                 # Зависимости
└── templates/              # Шаблоны Kubernetes манифестов
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    ├── _helpers.tpl
    └── NOTES.txt
```

### Настройка типа сервиса

Изменение типа сервиса на LoadBalancer:

```bash
sed -i 's/type: ClusterIP/type: LoadBalancer/' myapp/values.yaml
```

Проверка изменений:

```bash
grep -A 2 "service:" myapp/values.yaml
```

### Развертывание чарта

```bash
helm install myapp-release myapp
```

Проверка статуса:

```bash
helm status myapp-release
kubectl get deployments,pods,svc -l app.kubernetes.io/instance=myapp-release
```

Для minikube получение URL:

```bash
minikube service myapp-release --url
```

---

## Шаблонизация с переменными

### Изменение версии образа

Установка конкретной версии в values.yaml:

```bash
sed -i 's/tag: ""/tag: "1.27"/' myapp/values.yaml
```

Обновление релиза:

```bash
helm upgrade myapp-release myapp
```

Проверка обновления:

```bash
kubectl get pod -l app.kubernetes.io/instance=myapp-release -o jsonpath='{.items[0].spec.containers[0].image}'
```

### Переопределение имени приложения

Изменение nameOverride:

```bash
sed -i 's/nameOverride: ""/nameOverride: "webapp"/' myapp/values.yaml
```

Предпросмотр изменений без применения:

```bash
helm upgrade myapp-release myapp --dry-run
```

Применение изменений:

```bash
helm upgrade myapp-release myapp
```

### История релизов

Просмотр истории обновлений:

```bash
helm history myapp-release
```

Откат к предыдущей версии:

```bash
helm rollback myapp-release
```

Откат к конкретной ревизии:

```bash
helm rollback myapp-release 2
```

---

## Работа с Helm репозиториями

### Установка через OCI Registry

Современные Helm чарты распространяются через OCI (Open Container Initiative) реестры.

Просмотр информации о чарте:

```bash
helm show chart oci://registry-1.docker.io/bitnamicharts/wordpress
```

### Просмотр параметров чарта

**Метод 1: CLI**

```bash
helm show values oci://registry-1.docker.io/bitnamicharts/wordpress
```

Фильтрация нужных параметров:

```bash
helm show values oci://registry-1.docker.io/bitnamicharts/wordpress | grep -A 10 "mariadb:"
```

**Метод 2: Web документация**

ArtifactHub:
```
https://artifacthub.io/packages/helm/bitnami/wordpress
```

GitHub:
```
https://github.com/bitnami/charts/tree/main/bitnami/wordpress
```

В web-интерфейсе доступен полный values.yaml с описаниями всех параметров.

### Создание кастомного values.yaml

```bash
cat > wordpress-values.yaml << 'EOF'
mariadb:
  auth:
    rootPassword: "<ROOT_PASSWORD>"
    password: "<DB_PASSWORD>"
    username: "<DB_USER>"
    database: "<DB_NAME>"

wordpressPassword: "<WP_PASSWORD>"
wordpressUsername: "admin"
EOF
```

### Установка с кастомными параметрами

**Флаг -f (--values):**

Указывает Helm использовать кастомный файл со значениями вместо дефолтных.

```bash
helm install wordpress-release oci://registry-1.docker.io/bitnamicharts/wordpress -f wordpress-values.yaml
```

Механизм работы:
1. Helm загружает дефолтный values.yaml из чарта
2. Объединяет его с wordpress-values.yaml
3. Значения из wordpress-values.yaml имеют приоритет
4. Создает Kubernetes ресурсы с финальными значениями

Проверка развертывания:

```bash
kubectl get pods,svc -l app.kubernetes.io/instance=wordpress-release
```

Проверка применения кастомных паролей:

```bash
kubectl get secret wordpress-release -o jsonpath="{.data.wordpress-password}" | base64 -d
```

---

## Обновление релизов

### Изменение количества реплик

Редактирование values.yaml:

```bash
sed -i 's/replicaCount: 1/replicaCount: 3/' myapp/values.yaml
```

Применение изменений:

```bash
helm upgrade myapp-release myapp
```

Helm выполняет:
- Сравнение текущего и нового состояния
- Rolling update Deployment
- Создание новой ревизии релиза

Проверка масштабирования:

```bash
kubectl get deployment myapp-release-webapp -o jsonpath='{.spec.replicas}'
kubectl get pods -l app.kubernetes.io/instance=myapp-release
```

### Upgrade с дополнительными параметрами

```bash
helm upgrade myapp-release myapp \
  --set replicaCount=5 \
  --set image.tag=1.28 \
  --timeout 5m \
  --wait
```

Параметры:
- `--set` - переопределение значений
- `--timeout` - максимальное время ожидания
- `--wait` - ожидание готовности всех ресурсов

---

## Шифрование секретов с SOPS

### Установка инструментов

**SOPS:**

```bash
wget https://github.com/getsops/sops/releases/download/v3.9.2/sops-v3.9.2.linux.amd64 -O /tmp/sops
sudo mv /tmp/sops /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
```

**Helm Secrets плагин:**

```bash
helm plugin install https://github.com/jkroepke/helm-secrets --version v4.6.2
```

**Age (инструмент шифрования):**

```bash
wget https://github.com/FiloSottile/age/releases/download/v1.2.1/age-v1.2.1-linux-amd64.tar.gz
tar xzf age-v1.2.1-linux-amd64.tar.gz
sudo mv age/age age/age-keygen /usr/local/bin/
```

### Генерация ключей

```bash
age-keygen -o keys.txt
```

Файл keys.txt содержит:
- Приватный ключ (AGE-SECRET-KEY-...)
- Публичный ключ (age1...)

Сохранение публичного ключа в переменную:

```bash
export AGE_PUBLIC_KEY=$(grep "public key:" keys.txt | cut -d: -f2 | tr -d ' ')
```

### Конфигурация SOPS

Создание .sops.yaml:

```bash
cat > .sops.yaml << EOF
creation_rules:
  - path_regex: \.sops\.yaml$
    age: $AGE_PUBLIC_KEY
EOF
```

Правило определяет:
- Какие файлы шифровать (по regex паттерну)
- Каким ключом шифровать

### Создание и шифрование секретов

Создание файла с секретами:

```bash
cat > myapp-secrets.sops.yaml << 'EOF'
adminPassword: "SuperSecret123"
dbPassword: "DBSecret456"
EOF
```

Шифрование:

```bash
sops -e -i myapp-secrets.sops.yaml
```

Параметры:
- `-e` - encrypt
- `-i` - in-place (изменить файл)

Результат - зашифрованный YAML:

```yaml
adminPassword: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
dbPassword: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
sops:
    age:
        - recipient: age1...
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
            -----END AGE ENCRYPTED FILE-----
```

### Механизм работы SOPS в Helm

**Схема деплоя:**

```
.sops.yaml (зашифрован на диске)
  ↓
sops -d (расшифровка с keys.txt)
  ↓
Plain text values (только в памяти)
  ↓
Helm (получает расшифрованные значения)
  ↓
Kubernetes Secret (base64, не шифрование)
  ↓
Pod (читает Secret как переменные окружения)
```

**Важно:**
- Pod не выполняет криптографию
- Расшифровка происходит на этапе деплоя
- keys.txt хранится отдельно от репозитория
- .sops.yaml можно коммитить в Git (зашифрован)

### Добавление Secret в чарт

Создание шаблона:

```bash
cat > myapp/templates/secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "myapp.fullname" . }}-secret
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
type: Opaque
stringData:
  admin-password: {{ .Values.adminPassword | quote }}
  db-password: {{ .Values.dbPassword | quote }}
EOF
```

### Установка с зашифрованными секретами

Установка переменной окружения:

```bash
export SOPS_AGE_KEY_FILE=$(pwd)/keys.txt
```

Деплой с расшифровкой:

```bash
helm upgrade myapp-release myapp -f <(sops -d myapp-secrets.sops.yaml)
```

Process substitution `<(...)`:
- Создает временный file descriptor
- SOPS расшифровывает на лету
- Helm получает plain text

Проверка создания Secret:

```bash
kubectl get secret myapp-release-webapp-secret -o jsonpath='{.data.admin-password}' | base64 -d
```

---

## Динамические шаблоны с циклами

### Подготовка данных

Добавление параметров в values.yaml:

```bash
cat >> dynamic-app/values.yaml << 'EOF'

dynamicPods:
  - name: pod-alpha
    label: alpha
    color: red
  - name: pod-beta
    label: beta
    color: green
  - name: pod-gamma
    label: gamma
    color: blue
EOF
```

**Примечание:**
В values.yaml можно добавлять произвольные поля любой структуры и вложенности.

### Шаблон с циклом

Создание deployment.yaml с циклом:

```yaml
{{- range .Values.dynamicPods }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "dynamic-app.fullname" $ }}-{{ .name }}
  labels:
    {{- include "dynamic-app.labels" $ | nindent 4 }}
    pod-label: {{ .label }}
    pod-color: {{ .color }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ include "dynamic-app.name" $ }}
      pod-label: {{ .label }}
  template:
    metadata:
      labels:
        app: {{ include "dynamic-app.name" $ }}
        pod-label: {{ .label }}
        pod-color: {{ .color }}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
{{- end }}
```

Механизм:
- `range` итерируется по массиву dynamicPods
- Для каждого элемента создается отдельный Deployment
- `$` - ссылка на корневой контекст
- `.` внутри цикла - текущий элемент

### Service для выборки подов

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "dynamic-app.fullname" . }}
  labels:
    {{- include "dynamic-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
      protocol: TCP
      name: http
  selector:
    app: {{ include "dynamic-app.name" . }}
```

Selector выбирает все поды с label `app: dynamic-app`.

### Развертывание

```bash
helm install dynamic-release dynamic-app
```

Проверка созданных ресурсов:

```bash
kubectl get deployments -l app.kubernetes.io/instance=dynamic-release
kubectl get pods -l app=dynamic-app --show-labels
kubectl get endpoints dynamic-release-dynamic-app
```

Результат:
- 3 Deployment с уникальными именами
- 3 Pod с уникальными labels
- 1 Service с 3 endpoints

---

## CI/CD автоматизация с GitLab

### Конфигурация GitLab CI

Создание .gitlab-ci.yml:

```yaml
stages:
  - deploy

variables:
  HELM_CHART: "myapp"
  RELEASE_NAME: "myapp-release"
  NAMESPACE: "default"

deploy:
  stage: deploy
  script:
    - helm upgrade --install $RELEASE_NAME $HELM_CHART --namespace $NAMESPACE -f $HELM_CHART/values.yaml
  tags:
    - kubernetes
```

**Важно о версиях:**
- Не использовать `latest` для образов
- Указывать конкретные версии инструментов
- Фиксировать версии в переменных

Для docker-executor (альтернативный подход):

```yaml
deploy:
  stage: deploy
  image: alpine/helm:3.16.2
  variables:
    KUBECTL_VERSION: "v1.31.0"
  before_script:
    - apk add --no-cache curl
    - curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    - chmod +x kubectl
    - mv kubectl /usr/local/bin/
  script:
    - helm upgrade --install $RELEASE_NAME $HELM_CHART --namespace $NAMESPACE -f $HELM_CHART/values.yaml
```

### Установка GitLab Runner

```bash
curl -L --output /tmp/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64"
sudo mv /tmp/gitlab-runner /usr/local/bin/
sudo chmod +x /usr/local/bin/gitlab-runner
```

Регистрация runner:

```bash
sudo gitlab-runner register
```

Параметры регистрации:
- URL: `https://gitlab.com`
- Token: получить в Settings → CI/CD → Runners
- Executor: `shell`

Установка как системный сервис:

```bash
sudo gitlab-runner install --user=root --working-directory=/root
sudo gitlab-runner start
```

### Настройка доступа к Kubernetes

Копирование kubeconfig для runner:

```bash
sudo mkdir -p /root/.kube
sudo cp ~/.kube/config /root/.kube/config
```

Проверка доступа:

```bash
sudo -u root kubectl get nodes
```

### Настройка Git репозитория

Инициализация и первый коммит:

```bash
git init
git add myapp/ .gitlab-ci.yml
git commit -m "Initial Helm chart and CI/CD"
```

Добавление remote:

```bash
git remote add origin https://gitlab.com/<USERNAME>/<PROJECT>.git
```

Настройка токена для push:

```bash
git remote set-url origin https://<USERNAME>:<TOKEN>@gitlab.com/<USERNAME>/<PROJECT>.git
```

Push кода:

```bash
git push -u origin master
```

### Тестирование автоматизации

Изменение values.yaml:

```bash
sed -i 's/replicaCount: 5/replicaCount: 6/' myapp/values.yaml
```

Коммит и push:

```bash
git add myapp/values.yaml
git commit -m "Scale to 6 replicas via CI/CD"
git push
```

Проверка результата:

```bash
kubectl get deployment myapp-release-webapp -o jsonpath='{.spec.replicas}'
kubectl get pods -l app.kubernetes.io/instance=myapp-release
```

Workflow:
1. Push изменения в GitLab
2. GitLab CI обнаруживает изменения
3. Runner выполняет helm upgrade
4. Kubernetes обновляет Deployment
5. Rolling update подов

---

## GitHub Actions

### Конфигурация workflow

Создание .github/workflows/helm-deploy.yml:

```yaml
name: Helm Deploy

on:
  push:
    paths:
      - 'myapp/values.yaml'
    branches:
      - main

env:
  HELM_VERSION: v3.16.2
  KUBECTL_VERSION: v1.31.0

jobs:
  deploy:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout code
        uses: actions/checkout@v4.2.2

      - name: Install Helm
        uses: azure/setup-helm@v4.2.0
        with:
          version: ${{ env.HELM_VERSION }}

      - name: Install kubectl
        uses: azure/setup-kubectl@v4.0.0
        with:
          version: ${{ env.KUBECTL_VERSION }}

      - name: Configure kubeconfig
        run: |
          echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig

      - name: Deploy with Helm
        run: |
          helm upgrade --install myapp-release myapp \
            --namespace default \
            -f myapp/values.yaml
```

Настройка секретов в GitHub:
1. Repository Settings → Secrets → New repository secret
2. Name: `KUBECONFIG`
3. Value: `cat ~/.kube/config | base64 -w 0`

---

## Troubleshooting

### Helm lint errors

**Проблема:** Ошибки валидации чарта.

**Решение:**

```bash
helm lint myapp/
```

Исправление ошибок в шаблонах согласно выводу lint.

### Release already exists

**Проблема:**
```
Error: cannot re-use a name that is still in use
```

**Решение:**

Удаление существующего релиза:

```bash
helm uninstall myapp-release
```

Или использование флага `--replace`:

```bash
helm install myapp-release myapp --replace
```

### Template rendering issues

**Проблема:** Некорректный YAML после рендеринга шаблонов.

**Диагностика:**

```bash
helm template myapp-release myapp --debug
```

Проверка синтаксиса шаблонов:
- Закрытие всех блоков `{{- end }}`
- Правильный контекст (`.` vs `$`)
- Корректные пути к значениям

### Values not applied

**Проблема:** Изменения в values.yaml не применяются.

**Проверка:**

```bash
helm get values myapp-release
```

Просмотр финальных значений:

```bash
helm get manifest myapp-release
```

**Решение:**

Явное указание файла:

```bash
helm upgrade myapp-release myapp -f myapp/values.yaml
```

### SOPS decryption fails

**Проблема:**
```
Failed to get the data key required to decrypt the SOPS file
```

**Решение:**

Установка переменной окружения:

```bash
export SOPS_AGE_KEY_FILE=/path/to/keys.txt
```

Проверка ключа:

```bash
age-keygen -y keys.txt
```

### GitLab Runner shell issues

**Проблема:**
```
Job failed: prepare environment: exit status 1
```

**Причины:**
- Несовместимость shell (zsh vs bash)
- Отсутствие .bashrc или .bash_profile
- Проблемы с PATH

**Решение:**

Использование bash-совместимого пользователя:

```bash
sudo gitlab-runner install --user=root --working-directory=/root
```

Или создание минимального .bash_profile:

```bash
cat > ~/.bash_profile << 'EOF'
export PATH=/usr/local/bin:/usr/bin:/bin
export HOME=$HOME
EOF
```

### Runner не находит kubectl/helm

**Проблема:**
```
bash: helm: command not found
```

**Решение для shell executor:**

Убедиться что инструменты установлены глобально:

```bash
which helm
which kubectl
```

Добавить в PATH в config.toml:

```toml
[[runners]]
  environment = ["PATH=/usr/local/bin:/usr/bin:/bin"]
```

**Решение для docker executor:**

Использовать образ с предустановленными инструментами:

```yaml
image: alpine/helm:3.16.2
```

### Kubernetes RBAC denied

**Проблема:**
```
Error: configmaps is forbidden: User cannot create resource
```

**Решение:**

Проверка прав:

```bash
kubectl auth can-i create deployments --namespace default
```

Создание ServiceAccount с правами:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: helm-deployer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: helm-deployer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: helm-deployer
```

---

## Best Practices

### Версионирование

**Chart.yaml:**
```yaml
version: 1.2.0      # Версия чарта (SemVer)
appVersion: 2.5.1   # Версия приложения
```

Правила:
- Инкремент version при изменении чарта
- appVersion = версия приложения
- Следовать Semantic Versioning

### Организация values.yaml

```yaml
# Глобальные параметры
global:
  environment: production
  region: us-east-1

# Параметры приложения
replicaCount: 3
image:
  repository: myapp
  tag: "1.2.0"
  pullPolicy: IfNotPresent

# Ресурсы
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Сервис
service:
  type: ClusterIP
  port: 80
```

Группировка по категориям для читаемости.

### Секреты

**Не хранить в values.yaml:**
- Пароли
- API ключи
- Токены
- Сертификаты

**Использовать:**
- SOPS для шифрования
- External Secrets Operator
- Vault integration
- Kubernetes Secrets с RBAC

### Зависимости

Указание зависимостей в Chart.yaml:

```yaml
dependencies:
  - name: postgresql
    version: 12.0.0
    repository: oci://registry-1.docker.io/bitnamicharts
    condition: postgresql.enabled
```

Обновление зависимостей:

```bash
helm dependency update
```

### Хуки

Использование хуков для задач до/после деплоя:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "myapp.fullname" . }}-pre-install
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: pre-install
        image: busybox
        command: ['sh', '-c', 'echo Pre-install tasks']
      restartPolicy: Never
```

Типы хуков:
- pre-install
- post-install
- pre-upgrade
- post-upgrade
- pre-delete
- post-delete

### Тестирование

Создание тестов в templates/tests/:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "myapp.fullname" . }}-test
  annotations:
    "helm.sh/hook": test
spec:
  containers:
  - name: test
    image: busybox
    command: ['wget', '-O-', 'http://{{ include "myapp.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

Запуск тестов:

```bash
helm test myapp-release
```

### Документация

**NOTES.txt:**

Создание информативного вывода после установки:

```
{{- if .Values.ingress.enabled }}
Application URL:
  http://{{ .Values.ingress.hostname }}
{{- else }}
Get the application URL:
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "myapp.name" . }}" -o jsonpath="{.items[0].metadata.name}")
  kubectl port-forward $POD_NAME 8080:80
{{- end }}

Credentials:
  Username: {{ .Values.admin.username }}
  Password: kubectl get secret {{ include "myapp.fullname" . }}-admin -o jsonpath="{.data.password}" | base64 -d
```

**README.md в чарте:**

Документировать:
- Описание чарта
- Параметры values.yaml
- Примеры использования
- Зависимости
- Версионность

---

## Полезные команды

### Управление релизами

```bash
# Список релизов
helm list

# Список всех релизов (включая failed)
helm list --all

# Релизы в конкретном namespace
helm list --namespace production

# Информация о релизе
helm status myapp-release

# История релиза
helm history myapp-release

# Откат на предыдущую версию
helm rollback myapp-release

# Откат на конкретную ревизию
helm rollback myapp-release 3

# Удаление релиза
helm uninstall myapp-release

# Удаление с сохранением истории
helm uninstall myapp-release --keep-history
```

### Работа с чартами

```bash
# Создание чарта
helm create mychart

# Валидация чарта
helm lint mychart/

# Упаковка чарта
helm package mychart/

# Проверка зависимостей
helm dependency list mychart/

# Обновление зависимостей
helm dependency update mychart/

# Рендеринг шаблонов
helm template myrelease mychart/

# Рендеринг с отладкой
helm template myrelease mychart/ --debug

# Dry-run установки
helm install myrelease mychart/ --dry-run --debug
```

### Работа с values

```bash
# Установка с кастомными values
helm install myrelease mychart/ -f custom-values.yaml

# Множественные values файлы
helm install myrelease mychart/ -f values-1.yaml -f values-2.yaml

# Переопределение через --set
helm install myrelease mychart/ --set replicaCount=3

# Просмотр values релиза
helm get values myrelease

# Просмотр всех values (включая дефолтные)
helm get values myrelease --all

# Просмотр manifest релиза
helm get manifest myrelease
```

### Работа с репозиториями

```bash
# Добавление репозитория
helm repo add bitnami https://charts.bitnami.com/bitnami

# Список репозиториев
helm repo list

# Обновление репозиториев
helm repo update

# Поиск чартов
helm search repo wordpress

# Поиск всех версий
helm search repo wordpress --versions

# Удаление репозитория
helm repo remove bitnami
```

### Отладка

```bash
# Подробный вывод
helm install myrelease mychart/ --debug

# Вывод значений после рендеринга
helm template myrelease mychart/ --set replicaCount=5 | grep replicas

# Проверка что будет установлено
helm get manifest myrelease

# Логи пода с хуком
kubectl logs -l "app.kubernetes.io/instance=myrelease" --namespace default

# События в namespace
kubectl get events --namespace default --sort-by='.lastTimestamp'
```

### Управление зависимостями

```bash
# Список зависимостей
helm dependency list mychart/

# Обновление зависимостей
helm dependency update mychart/

# Сборка зависимостей
helm dependency build mychart/

# Показ графа зависимостей
helm dependency list mychart/ --max-col-width 0
```

---

## Справочная информация

### Структура Chart.yaml

```yaml
apiVersion: v2
name: myapp
description: Application description
type: application
version: 1.0.0
appVersion: "1.0"
kubeVersion: ">=1.24.0"
keywords:
  - app
  - web
home: https://example.com
sources:
  - https://github.com/example/myapp
maintainers:
  - name: DevOps Team
    email: devops@example.com
dependencies:
  - name: postgresql
    version: "12.0.0"
    repository: "oci://registry-1.docker.io/bitnamicharts"
    condition: postgresql.enabled
```

### Операторы шаблонов

| Оператор | Описание |
|----------|----------|
| `{{ }}` | Вывод значения |
| `{{- }}` | Удаление пробелов слева |
| `{{ -}}` | Удаление пробелов справа |
| `{{- -}}` | Удаление пробелов с обеих сторон |

### Функции шаблонов

| Функция | Пример | Результат |
|---------|--------|-----------|
| default | `{{ .Values.tag \| default "latest" }}` | Значение по умолчанию |
| quote | `{{ .Values.name \| quote }}` | "value" |
| upper | `{{ .Values.env \| upper }}` | VALUE |
| lower | `{{ .Values.env \| lower }}` | value |
| trim | `{{ .Values.name \| trim }}` | Без пробелов |
| nindent | `{{ include "labels" . \| nindent 4 }}` | Отступ с новой строки |
| toYaml | `{{ .Values.resources \| toYaml }}` | YAML формат |

### Helm переменные окружения

| Переменная | Назначение |
|------------|------------|
| HELM_CACHE_HOME | Кеш чартов |
| HELM_CONFIG_HOME | Конфигурация |
| HELM_DATA_HOME | Данные плагинов |
| HELM_DEBUG | Режим отладки |
| HELM_KUBECONTEXT | Kubernetes контекст |
| HELM_NAMESPACE | Namespace по умолчанию |

---

## Дополнительные ресурсы

**Официальная документация:**
- https://helm.sh/docs/
- https://artifacthub.io/

**Лучшие практики:**
- https://helm.sh/docs/chart_best_practices/

**Примеры чартов:**
- https://github.com/helm/charts
- https://github.com/bitnami/charts
