# GitLab Container Registry: Deploy и локальное развертывание

Настройка CI/CD pipeline для автоматической публикации Docker образов в GitLab Container Registry и локального развертывания контейнеров.

## Предварительные требования

- GitLab project с настроенным Runner
- Docker 20.10+ локально
- Personal Access Token с правами `read_registry`, `write_registry`
- Существующий Dockerfile в репозитории
- Работающий CI/CD pipeline с build stage

---

## Настройка аутентификации

### Создание Personal Access Token

GitLab UI: User Settings → Access Tokens

Параметры токена:

| Параметр | Значение |
|----------|----------|
| Token name | container-registry-token |
| Expiration | По требованию или бессрочный |
| Scopes | read_registry, write_registry |

Сохранить сгенерированный токен формата `glpat-...`

### Конфигурация CI/CD переменных

Project Settings → CI/CD → Variables

Добавить переменные:
```
CI_REGISTRY = registry.gitlab.com
CI_REGISTRY_IMAGE = registry.gitlab.com/<NAMESPACE>/<PROJECT>
CI_REGISTRY_USER = <GITLAB_USERNAME>
CI_REGISTRY_PASSWORD = <PERSONAL_ACCESS_TOKEN>
```

Настройки переменных:

| Переменная | Visibility | Flags |
|------------|------------|-------|
| CI_REGISTRY | Visible | - |
| CI_REGISTRY_IMAGE | Visible | Expand variable reference |
| CI_REGISTRY_USER | Visible | - |
| CI_REGISTRY_PASSWORD | Masked | - |

---

## Deploy stage в CI/CD pipeline

### Конфигурация .gitlab-ci.yml
```yaml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_TLS_CERTDIR: ""
  DOCKER_HOST: tcp://docker:2375
  IMAGE_NAME: "app:${CI_COMMIT_SHORT_SHA}"

deploy:
  stage: deploy
  image: docker:24.0.5
  services:
    - name: docker:24.0.5-dind
      command: ["--tls=false"]
  tags:
    - infra
  dependencies:
    - build
  before_script:
    - sleep 5
    - docker info
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin $CI_REGISTRY
  script:
    - docker load -i app-image.tar
    - docker tag ${IMAGE_NAME} ${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}
    - docker tag ${IMAGE_NAME} ${CI_REGISTRY_IMAGE}:latest
    - docker push ${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}
    - docker push ${CI_REGISTRY_IMAGE}:latest
  rules:
    - if: $CI_COMMIT_BRANCH == "master"
```

### Компоненты конфигурации

**Docker login:**
Использование `echo` с pipe для передачи пароля через stdin предотвращает exposure credentials в process list.

**Image tagging стратегия:**
- `${CI_COMMIT_SHORT_SHA}` - уникальный тег для каждого коммита, обеспечивает immutable versioning
- `latest` - указатель на последний успешный build из master ветки

**Rules секция:**
Ограничение deploy только master веткой предотвращает публикацию development образов в registry.

**Dependencies:**
Указание `build` в dependencies гарантирует доступность артефакта `app-image.tar` созданного на build stage.

### Проверка публикации

После успешного выполнения pipeline:

Project → Deploy → Container Registry

Должны быть видны образы с тегами:
- `latest`
- `<commit-sha>` для каждого коммита

---

## Локальное развертывание

### Аутентификация в Registry
```bash
docker login registry.gitlab.com -u <GITLAB_USERNAME>
```

Password: Personal Access Token (`glpat-...`)

Валидация:
```
Login Succeeded
```

### Pull образа
```bash
docker pull registry.gitlab.com/<NAMESPACE>/<PROJECT>:latest
```

Альтернатива - pull специфичной версии:
```bash
docker pull registry.gitlab.com/<NAMESPACE>/<PROJECT>:<COMMIT_SHA>
```

### Запуск контейнера
```bash
docker run -d --name app \
  -p <HOST_PORT>:<CONTAINER_PORT> \
  registry.gitlab.com/<NAMESPACE>/<PROJECT>:latest
```

Параметры:
- `-d` - detached mode
- `--name` - идентификатор контейнера
- `-p` - port mapping host:container

### Проверка работы

Статус контейнера:
```bash
docker ps | grep app
```

Логи приложения:
```bash
docker logs app
```

Тестирование API:
```bash
curl http://localhost:<HOST_PORT>/<ENDPOINT>
```

### Cleanup
```bash
docker stop app
docker rm app
docker rmi registry.gitlab.com/<NAMESPACE>/<PROJECT>:latest
```

---

## Troubleshooting

### Login failed: unauthorized

**Симптомы:**
```
Error response from daemon: Get https://registry.gitlab.com/v2/: unauthorized
```

**Причина:** Истекший или невалидный Personal Access Token.

**Решение:**

Создать новый токен:
1. GitLab → User Settings → Access Tokens
2. Revoke старый токен
3. Создать новый с `read_registry`, `write_registry`
4. Обновить `CI_REGISTRY_PASSWORD` в project variables
5. Повторить `docker login`

### Push denied: requested access to resource is denied

**Симптомы:**
```
denied: requested access to the resource is denied
```

**Причина:** Недостаточные permissions для push в registry проекта.

**Решение:**

Проверка роли:
- Project → Members → минимум Developer role
- Personal Access Token содержит `write_registry` scope

Для project access token:
- Project Settings → Access Tokens
- Минимум Developer role и `write_registry` scope

### DinD service unavailable

**Симптомы:**
```
Cannot connect to the Docker daemon at tcp://docker:2375
```

**Причина:** Docker-in-Docker service не запущен или недоступен.

**Решение:**

Проверка конфигурации:
```yaml
services:
  - name: docker:24.0.5-dind
    command: ["--tls=false"]

variables:
  DOCKER_TLS_CERTDIR: ""
  DOCKER_HOST: tcp://docker:2375
```

Добавление wait loop:
```yaml
before_script:
  - sleep 5
  - until docker info; do sleep 1; done
```

### Image size optimization

**Симптомы:**
Образ 400+ MB для простого Python приложения.

**Причина:** Использование полного Python образа вместо slim/alpine варианта.

**Решение:**

Multi-stage build в Dockerfile:
```dockerfile
# Build stage
FROM python:3.9 as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Runtime stage
FROM python:3.9-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "app.py"]
```

Alpine вариант:
```dockerfile
FROM python:3.9-alpine
RUN apk add --no-cache gcc musl-dev
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

---

## Best Practices

**Tagging стратегия:**
- Semantic versioning для releases: `v1.2.3`
- Commit SHA для traceability: `${CI_COMMIT_SHORT_SHA}`
- Branch name для feature branches: `feature-xyz`
- `latest` только для stable master branch

**Security:**
- Использовать project/group access tokens вместо personal
- Rotate tokens периодически
- Masked variables для credentials
- Scan образов на vulnerabilities перед push

**Registry cleanup:**
- Настроить cleanup policies для старых образов
- Project Settings → Packages & Registries → Cleanup policies
- Удалять untagged images после N дней
- Сохранять последние N версий

**Image optimization:**
- Multi-stage builds для минимизации размера
- `.dockerignore` для исключения ненужных файлов
- Layer caching для ускорения сборки
- Базовые образы `-slim` или `-alpine`

**CI/CD оптимизация:**
- Deploy только из master/main ветки
- Manual approval для production deployments
- Artifacts expiration для экономии storage
- Parallel jobs где возможно

---

## Полезные команды

### Registry management
```bash
# Список всех образов
curl -H "PRIVATE-TOKEN: <TOKEN>" \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/registry/repositories"

# Список тегов
curl -H "PRIVATE-TOKEN: <TOKEN>" \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/registry/repositories/<REPO_ID>/tags"

# Удаление образа
curl -X DELETE -H "PRIVATE-TOKEN: <TOKEN>" \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/registry/repositories/<REPO_ID>/tags/<TAG>"
```

### Docker local operations
```bash
# Проверка локальных образов
docker images | grep registry.gitlab.com

# Удаление всех остановленных контейнеров
docker container prune

# Удаление неиспользуемых образов
docker image prune -a

# Проверка размера образа
docker images registry.gitlab.com/<NAMESPACE>/<PROJECT>:latest

# Inspect образа
docker inspect registry.gitlab.com/<NAMESPACE>/<PROJECT>:latest
```

### CI/CD debugging
```bash
# Локальное выполнение CI job
docker run --rm -v $(pwd):/builds \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:alpine exec docker deploy

# Проверка variables в pipeline
echo $CI_REGISTRY_IMAGE

# Валидация .gitlab-ci.yml
curl --header "Content-Type: application/json" \
  --data "{\"content\": \"$(cat .gitlab-ci.yml | jq -Rs .)\"}" \
  "https://gitlab.com/api/v4/ci/lint"
```
