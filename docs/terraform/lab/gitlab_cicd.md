# GitLab CI/CD для Terraform с Yandex Cloud

Настройка автоматизированного deployment инфраструктуры в Yandex Cloud через GitLab CI/CD с использованием remote state backend.

## Предварительные требования

- GitLab аккаунт с доступом к CI/CD
- Yandex Cloud CLI настроен
- Service account с правами на создание ресурсов
- SSH ключ для доступа к VM
- Terraform конфигурация проекта
- Git >= 2.0

---

## Архитектура решения

```
GitLab Repository
      ↓
GitLab CI/CD Runner
      ↓
Terraform ← Variables (CI/CD Secrets)
      ↓
Yandex Cloud API
      ↓
Infrastructure (VM, Network)
      ↓
State → Object Storage (S3)
```

---

## Подготовка проекта

### Инициализация Git репозитория

```bash
git init
```

### Создание .gitignore

Файл `.gitignore` предотвращает утечку чувствительных данных в репозиторий.

```
# Terraform files
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Sensitive files
key.json
*.pem
*.key

# OS files
.DS_Store
Thumbs.db
```

Критически важно исключить `key.json`, `*.tfstate`, `*.tfvars` из git.

---

## Настройка Remote Backend

### Создание S3 bucket

```bash
yc storage bucket create --name terraform-state-<UNIQUE_ID>
```

Bucket используется для хранения Terraform state с поддержкой locking.

### Конфигурация backend

Файл `backend.tf`:

```hcl
terraform {
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "terraform-state-<UNIQUE_ID>"
    region = "ru-central1"
    key    = "terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
```

Backend использует S3-совместимый API Yandex Object Storage.

### Создание статических ключей доступа

```bash
yc iam access-key create --service-account-name <SA_NAME>
```

Вывод содержит:
- `key_id` - AWS_ACCESS_KEY_ID для S3 API
- `secret` - AWS_SECRET_ACCESS_KEY для S3 API

Сохранить оба значения для конфигурации CI/CD.

---

## Настройка GitLab CI/CD

### Структура Pipeline

Файл `.gitlab-ci.yml`:

```yaml
variables:
  TF_ROOT: ${CI_PROJECT_DIR}
  TF_STATE_NAME: default

stages:
  - validate
  - plan
  - apply
  - destroy

.terraform_base:
  image: 
    name: hashicorp/terraform:latest
    entrypoint: [""]
  before_script:
    - export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    - export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    - export YC_TOKEN=${YC_TOKEN}
    - export TF_VAR_cloud_id=${YC_CLOUD_ID}
    - export TF_VAR_folder_id=${YC_FOLDER_ID}
    - export TF_VAR_service_account_key_file="key.json"
    - export TF_VAR_ssh_public_key=${SSH_PUBLIC_KEY}
    - cp ${YC_SERVICE_ACCOUNT_KEY} ${TF_ROOT}/key.json
    - cd ${TF_ROOT}
    - terraform --version
    - terraform init

validate:
  extends: .terraform_base
  stage: validate
  script:
    - terraform validate
    - terraform fmt -check
  only:
    - main
    - merge_requests

plan:
  extends: .terraform_base
  stage: plan
  script:
    - terraform plan -out=plan.tfplan
  artifacts:
    paths:
      - ${TF_ROOT}/plan.tfplan
    expire_in: 1 week
  only:
    - main

apply:
  extends: .terraform_base
  stage: apply
  script:
    - terraform apply -auto-approve
  dependencies:
    - plan
  when: manual
  only:
    - main

destroy:
  extends: .terraform_base
  stage: destroy
  script:
    - terraform destroy -auto-approve
  when: manual
  only:
    - main
```

Параметр `entrypoint: [""]` переопределяет entrypoint Docker образа для работы shell команд.

### Стадии Pipeline

| Стадия | Назначение | Автоматический запуск |
|--------|------------|----------------------|
| validate | Валидация синтаксиса и форматирования | Да |
| plan | Создание плана изменений | Да |
| apply | Применение изменений | Нет (manual) |
| destroy | Удаление инфраструктуры | Нет (manual) |

### Переменные окружения

Префикс `TF_VAR_` автоматически мапится на Terraform переменные:

```yaml
export TF_VAR_cloud_id=${YC_CLOUD_ID}
```

Terraform видит как:

```hcl
var.cloud_id
```

---

## Конфигурация секретов

### Получение данных

```bash
yc config list
```

Сохранить:
- `token` - YC_TOKEN
- `cloud-id` - YC_CLOUD_ID  
- `folder-id` - YC_FOLDER_ID

```bash
cat ~/.ssh/id_ed25519.pub
```

Сохранить публичный SSH ключ для SSH_PUBLIC_KEY.

### Добавление переменных в GitLab

Settings → CI/CD → Variables → Expand → Add variable

| Key | Value | Type | Protected | Masked |
|-----|-------|------|-----------|--------|
| AWS_ACCESS_KEY_ID | `<ACCESS_KEY_FROM_YC>` | Variable | ✓ | ✓ |
| AWS_SECRET_ACCESS_KEY | `<SECRET_KEY_FROM_YC>` | Variable | ✓ | ✓ |
| YC_TOKEN | `<TOKEN_FROM_YC_CONFIG>` | Variable | ✓ | ✓ |
| YC_CLOUD_ID | `<CLOUD_ID>` | Variable | ✓ | - |
| YC_FOLDER_ID | `<FOLDER_ID>` | Variable | ✓ | - |
| YC_SERVICE_ACCOUNT_KEY | `<FULL_JSON_CONTENT>` | File | ✓ | - |
| SSH_PUBLIC_KEY | `<SSH_PUBLIC_KEY>` | Variable | ✓ | - |

**Критические параметры:**
- YC_SERVICE_ACCOUNT_KEY - Type: **File** (не Variable)
- Protected - доступны только для protected branches
- Masked - скрывает значения в логах CI/CD

---

## Публикация в GitLab

### Создание репозитория

GitLab: New project → Create blank project
- Name: `terraform-yc-cicd`
- Visibility: Private
- Не инициализировать README

### Push кода

```bash
git add .
git commit -m "Initial commit: Terraform with GitLab CI/CD"
git remote add origin git@gitlab.com:<USERNAME>/<REPO>.git
git branch -M main
git push -u origin main
```

Pipeline запускается автоматически после push.

---

## Workflow выполнения

### Автоматический запуск

После push в `main`:

1. **validate** - проверка синтаксиса
2. **plan** - генерация плана изменений

Артефакт `plan.tfplan` сохраняется на 1 неделю.

### Ручной запуск apply

Build → Pipelines → выбрать pipeline → нажать Play на `apply`

Apply использует план из стадии plan.

### Ручной запуск destroy

Build → Pipelines → выбрать pipeline → нажать Play на `destroy`

Destroy удаляет все ресурсы управляемые Terraform.

---

## State Locking

### Механизм работы

Remote backend в Yandex Object Storage поддерживает DynamoDB-совместимый locking:

1. Первый `terraform apply` создает lock в S3
2. Второй одновременный `apply` получает ошибку:

```
Error: Error acquiring the state lock

Lock Info:
  ID:        <LOCK_ID>
  Path:      terraform-state-bucket/terraform.tfstate
  Operation: OperationTypeApply
  Who:       gitlab-runner@<RUNNER_ID>
  Version:   1.x.x
  Created:   <TIMESTAMP>
```

3. После завершения первого apply lock освобождается

### Тестирование locking

Запустить два pipeline одновременно:

1. Run pipeline → main
2. Run pipeline → main  
3. Быстро нажать Play на apply в обоих

Результат:
- Первый apply - passed
- Второй apply - failed с ошибкой lock

Защита от race conditions и повреждения state.

---

## Сравнение локального и remote state

| Аспект | Локальный state | Remote state |
|--------|----------------|--------------|
| Хранение | Файл на диске | Object Storage |
| Совместная работа | Невозможна | Поддерживается |
| Locking | Отсутствует | DynamoDB-compatible |
| CI/CD | Требует передачи файла | Автоматический доступ |
| Безопасность | Риск утечки через git | Централизованное хранение |
| Версионирование | Вручную | Автоматическое (S3 versioning) |
| Откат | Ручное восстановление | Через версии S3 |

---

## Troubleshooting

### Error: Failed to get existing workspaces

**Ошибка:**
```
Error: Failed to get existing workspaces: AccessDenied
```

**Причина:** Неправильные AWS_ACCESS_KEY_ID или AWS_SECRET_ACCESS_KEY.

**Решение:**

Проверить переменные в GitLab CI/CD Variables и пересоздать static access key.

### Error: No value for required variable

**Ошибка:**
```
Error: No value for required variable
  on variables.tf line 1:
   1: variable "cloud_id" {
```

**Причина:** Переменная не передана через TF_VAR_.

**Решение:**

Добавить в before_script:

```yaml
- export TF_VAR_cloud_id=${YC_CLOUD_ID}
```

И убедиться что YC_CLOUD_ID задан в GitLab Variables.

### Error: Error locking state

**Ошибка:**
```
Error: Error acquiring the state lock
```

**Причина:** State уже заблокирован другим процессом или осталась "мертвая" блокировка.

**Решение (осторожно):**

Дождаться завершения другого процесса или вручную удалить lock:

```bash
terraform force-unlock <LOCK_ID>
```

### Pipeline fails at terraform init

**Ошибка:**
```
Terraform has no command named "sh"
```

**Причина:** Отсутствует `entrypoint: [""]` в image конфигурации.

**Решение:**

```yaml
image: 
  name: hashicorp/terraform:latest
  entrypoint: [""]
```

### Permission denied: key.json

**Ошибка:**
```
Error: open key.json: permission denied
```

**Причина:** YC_SERVICE_ACCOUNT_KEY неправильно скопирован или тип не File.

**Решение:**

Убедиться что:
- Type: **File** в GitLab Variables
- `cp ${YC_SERVICE_ACCOUNT_KEY} ${TF_ROOT}/key.json` в before_script

---

## Best Practices

**Защита веток**
- Apply/destroy только из protected branches (main)
- Merge requests требуют review
- Protected branches предотвращают случайные изменения

**Версионирование state**
- Включить versioning для S3 bucket
- Позволяет откатывать state при ошибках
- Хранить минимум 30 версий

**Разделение окружений**
- Отдельные buckets для dev/staging/prod
- Разные service accounts с минимальными правами
- Изоляция state между окружениями

**Manual approval для production**
- Apply требует ручного подтверждения
- Destroy требует двойного подтверждения
- Критические изменения проходят review

**Мониторинг Pipeline**
- Настроить уведомления о failed jobs
- Логирование изменений инфраструктуры
- Аудит доступа к CI/CD переменным

**Ротация секретов**
- Регулярная смена static access keys
- Обновление YC_TOKEN при истечении
- Аудит использования service account

**Артефакты и кэш**
- Хранить plan.tfplan как artifact
- Expire artifacts через 1-2 недели
- Не хранить state в artifacts

**Идемпотентность**
- Pipeline должен быть безопасен для повторного запуска
- terraform init/plan/apply идемпотентны
- Избегать scripts с побочными эффектами

---

## Расширенная конфигурация

### Множественные окружения

```yaml
variables:
  TF_ROOT: ${CI_PROJECT_DIR}/environments/${CI_ENVIRONMENT_NAME}

deploy_dev:
  extends: .terraform_base
  stage: apply
  environment:
    name: dev
  only:
    - develop

deploy_prod:
  extends: .terraform_base
  stage: apply
  environment:
    name: production
  only:
    - main
  when: manual
```

### Интеграция с Merge Requests

```yaml
plan_mr:
  extends: .terraform_base
  stage: plan
  script:
    - terraform plan -no-color | tee plan_output.txt
    - echo "Plan output saved"
  artifacts:
    reports:
      terraform: plan_output.txt
  only:
    - merge_requests
```

### Уведомления

```yaml
notify_success:
  stage: .post
  script:
    - echo "Deployment successful"
  only:
    - main
  when: on_success

notify_failure:
  stage: .post
  script:
    - echo "Deployment failed"
  only:
    - main
  when: on_failure
```

---

## Полезные команды

| Команда | Описание |
|---------|----------|
| `yc storage bucket create --name <NAME>` | Создание S3 bucket для state |
| `yc iam access-key create --service-account-name <SA>` | Создание статических ключей S3 |
| `yc iam access-key list --service-account-name <SA>` | Список ключей доступа |
| `yc storage bucket list` | Список buckets в Object Storage |
| `terraform force-unlock <LOCK_ID>` | Принудительное снятие блокировки state |
| `terraform state list` | Список ресурсов в state |
| `terraform show` | Детали текущего state |
| `git push origin main --force-with-lease` | Безопасный force push |
| `terraform workspace list` | Список workspace (для multi-env) |

---

## Проверка работы CI/CD

### Валидация конфигурации

После push проверить:

1. Pipeline → validate stage → passed
2. Логи содержат `Success! The configuration is valid`
3. `terraform fmt -check` не выявил проблем форматирования

### Проверка плана

1. Pipeline → plan stage → passed
2. Артефакт plan.tfplan создан
3. План показывает ожидаемые изменения

### Проверка apply

1. Manual trigger → apply
2. Resources created в логах
3. Outputs отображают результаты

```bash
yc compute instance list
```

Список содержит созданные VM.

### Проверка state locking

1. Запустить два pipeline
2. Trigger apply одновременно
3. Второй получает lock error
4. Первый завершается успешно

### Проверка destroy

1. Manual trigger → destroy
2. Resources destroyed в логах
3. Infrastructure удалена

```bash
yc compute instance list
```

Список пустой или без Terraform ресурсов.
