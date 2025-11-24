# GitLab Runner: Установка и настройка CI/CD

Руководство по развертыванию GitLab Runner в Docker и Kubernetes с конфигурацией DinD-пайплайнов для сборки и тестирования приложений.

## Предварительные требования

- Docker 20.10+
- Kubernetes кластер 1.28+
- Helm 3.0+
- Доступ к GitLab instance (gitlab.com или self-hosted)
- Registration token из Settings → CI/CD → Runners

---

## Установка GitLab Runner локально

### Docker-based deployment
```bash
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
```

Конфигурация монтирует Docker socket для executor типа `docker`, позволяя runner запускать jobs в изолированных контейнерах.

### Регистрация runner
```bash
docker exec -it gitlab-runner gitlab-runner register
```

Параметры регистрации:

| Параметр | Значение | Назначение |
|----------|----------|------------|
| GitLab URL | https://gitlab.com/ | Endpoint GitLab API |
| Registration token | glrt-<TOKEN> | Токен из project settings |
| Description | infra-runner | Идентификатор runner |
| Tags | infra,docker | Теги для job matching |
| Executor | docker | Тип исполнителя |
| Default image | ubuntu:22.04 | Fallback образ |

### Конфигурация тегов

Проверка config.toml:
```bash
docker exec gitlab-runner cat /etc/gitlab-runner/config.toml
```

Структура конфигурации:
```toml
concurrent = 1
[[runners]]
  name = "infra-runner"
  url = "https://gitlab.com/"
  token = "<RUNNER_TOKEN>"
  executor = "docker"
  tags = ["infra", "docker"]
  [runners.docker]
    image = "ubuntu:22.04"
    privileged = false
    volumes = ["/cache"]
```

Обновление конфигурации:
```bash
docker cp /tmp/config.toml gitlab-runner:/etc/gitlab-runner/config.toml
docker restart gitlab-runner
```

### Валидация
```bash
docker ps | grep gitlab-runner
docker logs gitlab-runner --tail=20
```

Runner должен показывать статус "Configuration loaded" и "Checking for jobs".

---

## Установка GitLab Runner в Kubernetes

### Добавление Helm репозитория
```bash
helm repo add gitlab https://charts.gitlab.io
helm repo update
```

### Создание namespace
```bash
kubectl create namespace gitlab-runner
```

### Конфигурация через values.yaml
```yaml
gitlabUrl: https://gitlab.com/

runnerToken: "<REGISTRATION_TOKEN>"

runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        namespace = "{{.Release.Namespace}}"
        image = "ubuntu:22.04"
        privileged = true
      [[runners.kubernetes.volumes.empty_dir]]
        name = "docker-certs"
        mount_path = "/certs/client"
        medium = "Memory"

  tags: "k8s-runner,docker"

rbac:
  create: true

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

Параметр `privileged: true` необходим для Docker-in-Docker (DinD) сценариев.

### Установка через Helm
```bash
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values gitlab-runner-values.yaml
```

### Проверка deployment
```bash
kubectl get pods -n gitlab-runner
kubectl logs -n gitlab-runner -l app=gitlab-runner --tail=20
```

Pod должен достичь статуса `Running 1/1` и показывать "Runner registered successfully" в логах.

---

## Настройка DinD-пайплайна

### Структура .gitlab-ci.yml
```yaml
stages:
  - build
  - test-api
  - test-logic

variables:
  DOCKER_TLS_CERTDIR: "/certs"
  DOCKER_HOST: tcp://docker:2376
  DOCKER_TLS_VERIFY: 1
  DOCKER_CERT_PATH: "$DOCKER_TLS_CERTDIR/client"
  IMAGE_NAME: "app:${CI_COMMIT_SHORT_SHA}"

build:
  stage: build
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  tags:
    - k8s-runner
  before_script:
    - until docker info; do sleep 1; done
  script:
    - docker build -t ${IMAGE_NAME} .
    - docker save ${IMAGE_NAME} -o app-image.tar
  artifacts:
    paths:
      - app-image.tar
    expire_in: 1 hour

test-api:
  stage: test-api
  image: python:3.9
  tags:
    - k8s-runner
  dependencies:
    - build
  before_script:
    - pip install -r requirements.txt
    - python app.py &
    - sleep 5
  script:
    - pytest test_api.py -v

test-logic:
  stage: test-logic
  image: python:3.9
  tags:
    - k8s-runner
  dependencies:
    - build
  before_script:
    - pip install -r requirements.txt
  script:
    - pytest test_logic.py -v
```

### Компоненты DinD конфигурации

**Variables секция:**
- `DOCKER_TLS_CERTDIR` - директория TLS сертификатов для secure communication
- `DOCKER_HOST` - TCP endpoint Docker daemon в DinD service
- `DOCKER_TLS_VERIFY` - включение TLS верификации
- `DOCKER_CERT_PATH` - путь к client сертификатам

**Services:**
Контейнер `docker:24.0.5-dind` запускается параллельно с job контейнером, предоставляя Docker daemon через сеть.

**before_script в build:**
Цикл `until docker info` ожидает готовности Docker daemon перед выполнением команд сборки.

**Artifacts:**
Сохранение Docker образа как tar archive для использования в последующих stages или внешней загрузки.

### Isolation моделей

| Executor | Job execution | Networking | Resources |
|----------|---------------|------------|-----------|
| docker | Container на host | Shared network | Host resources |
| kubernetes | Pod в кластере | CNI isolated | Namespace limits |

---

## Troubleshooting

### Pipeline stuck: "no runners match tags"

**Симптомы:**
- Job статус "pending" или "stuck"
- Сообщение "no runners that match all of the job's tags"

**Причина:** Несоответствие тегов в `.gitlab-ci.yml` и runner конфигурации.

**Решение:**

Проверка тегов runner через GitLab UI:
Settings → CI/CD → Runners → Runner details

Синхронизация тегов в `.gitlab-ci.yml`:
```yaml
job:
  tags:
    - <ACTUAL_RUNNER_TAG>
```

Альтернатива - включение "Run untagged jobs" в runner settings.

### DinD: Cannot connect to Docker daemon

**Симптомы:**
```
ERROR: Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Причина:** Отсутствие переменных окружения для подключения к DinD service через TCP.

**Решение:**

Добавление переменных в `.gitlab-ci.yml`:
```yaml
variables:
  DOCKER_HOST: tcp://docker:2376
  DOCKER_TLS_VERIFY: 1
  DOCKER_CERT_PATH: "$DOCKER_TLS_CERTDIR/client"
```

Проверка доступности daemon:
```yaml
before_script:
  - until docker info; do sleep 1; done
```

### Runner offline после restart

**Симптомы:**
- Runner статус "Offline" в GitLab UI
- Логи показывают ошибки аутентификации

**Причина:** Token expiry или изменение конфигурации без сохранения в persistent volume.

**Решение:**

Docker runner:
```bash
docker exec gitlab-runner cat /etc/gitlab-runner/config.toml
```

Проверка наличия корректного token. При отсутствии - повторная регистрация.

Kubernetes runner:
```bash
kubectl logs -n gitlab-runner -l app=gitlab-runner
```

Проверка Helm values на корректность `runnerToken`.

### Privileged mode требуется но запрещен

**Симптомы:**
```
ERROR: Job failed: Cannot start service docker:dind
```

**Причина:** DinD требует `privileged: true`, но настройка отсутствует в runner конфигурации.

**Решение:**

Docker executor:
```toml
[runners.docker]
  privileged = true
```

Kubernetes executor (values.yaml):
```yaml
runners:
  config: |
    [[runners]]
      [runners.kubernetes]
        privileged = true
```

Применение изменений:
```bash
# Docker
docker restart gitlab-runner

# Kubernetes
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values updated-values.yaml
```

---

## Best Practices

**Executor выбор:**
- Docker executor для простых окружений и единичных серверов
- Kubernetes executor для production с масштабированием и изоляцией

**Теги стратегия:**
- Специфичные теги для типов workloads (infra, build, deploy)
- Раздельные runner для infrastructure и application кода
- Тег naming convention: `<environment>-<purpose>` (prod-deploy, dev-build)

**Security:**
- Минимизация использования `privileged: true` (только для DinD)
- Раздельные runner для trusted/untrusted repositories
- Token rotation через GitLab UI с invalidation старых

**Resources:**
- Конфигурация limits/requests в Kubernetes executor
- Monitoring runner utilization через Prometheus metrics
- Concurrent jobs настройка согласно доступным ресурсам

**Конфигурация management:**
- Infrastructure as Code для runner deployment (Helm charts, Terraform)
- Version control для runner values.yaml
- Централизованная конфигурация через ConfigMaps в Kubernetes

---

## Полезные команды

### Docker runner
```bash
# Проверка статуса
docker ps -a | grep gitlab-runner

# Просмотр логов
docker logs -f gitlab-runner

# Перезапуск
docker restart gitlab-runner

# Проверка конфигурации
docker exec gitlab-runner gitlab-runner verify

# Unregister runner
docker exec gitlab-runner gitlab-runner unregister --name <RUNNER_NAME>
```

### Kubernetes runner
```bash
# Статус deployment
kubectl get all -n gitlab-runner

# Логи в реальном времени
kubectl logs -n gitlab-runner -l app=gitlab-runner -f

# Проверка runner конфигурации
kubectl exec -n gitlab-runner <POD_NAME> -- cat /etc/gitlab-runner/config.toml

# Обновление через Helm
helm upgrade gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runner \
  --values values.yaml

# Удаление runner
helm uninstall gitlab-runner --namespace gitlab-runner
kubectl delete namespace gitlab-runner
```

### GitLab CI/CD
```bash
# Валидация .gitlab-ci.yml
docker run --rm -v $(pwd):/builds gitlab/gitlab-runner:alpine exec \
  --docker-privileged --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  <JOB_NAME>

# Запуск pipeline через API
curl --request POST --header "PRIVATE-TOKEN: <TOKEN>" \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/pipeline"
```
