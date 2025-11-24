# SAST-сканирование инфраструктурного кода

Настройка  автоматизированного security scanning для Infrastructure as Code с использованием tfsec, ansible-lint и GitLab SAST templates.

## Предварительные требования

- GitLab project с Terraform и/или Ansible кодом
- Настроенный GitLab Runner с Docker executor
- Структура проекта:
  - `terraform/` - Terraform конфигурации
  - `ansible/` - Ansible playbooks и roles

---

## Обзор SAST инструментов

### Инструменты для IaC

| Инструмент | Назначение | Языки/Frameworks |
|------------|------------|------------------|
| tfsec | Security scanner для Terraform | HCL, JSON |
| checkov | Policy-as-code validation | Terraform, CloudFormation, K8s, ARM, Helm |
| ansible-lint | Best practices для Ansible | YAML playbooks |
| GitLab SAST | Универсальный security scanner | Multiple languages |
| yamllint | YAML syntax validation | YAML |

### Категории проверок

**tfsec:**
- Unencrypted storage
- Public network exposure
- Missing access controls
- Hardcoded credentials
- Insecure protocols
- Missing logging/monitoring

**ansible-lint:**
- Deprecated syntax
- Security anti-patterns
- Code style violations
- Missing idempotency
- Unhandled errors

---

## Конфигурация CI/CD pipeline

### Базовая структура
```yaml
include:
  - template: Security/SAST.gitlab-ci.yml

stages:
  - validate
  - sast

variables:
  SAST_EXCLUDED_PATHS: "kubespray/,vendor/"
```

### Terraform security scanning
```yaml
tfsec:
  stage: sast
  image:
    name: aquasec/tfsec:latest
    entrypoint: [""]
  tags:
    - infra
  script:
    - echo "===== TFSEC SECURITY SCAN ====="
    - /usr/bin/tfsec terraform/ || true
    - /usr/bin/tfsec terraform/ --format json --out tfsec-report.json
  artifacts:
    reports:
      sast: tfsec-report.json
    paths:
      - tfsec-report.json
    expire_in: 1 week
  allow_failure: true
```

**Параметры tfsec:**

| Флаг | Назначение |
|------|------------|
| `--format json` | Structured output для GitLab Security Dashboard |
| `--minimum-severity HIGH` | Фильтрация по severity level |
| `--exclude-downloaded-modules` | Игнорирование внешних модулей |
| `--soft-fail` | Warning вместо failure |

### Ansible best practices scanning
```yaml
ansible-lint:
  stage: sast
  image: python:3.9
  tags:
    - infra
  before_script:
    - pip install ansible-lint
  script:
    - ansible-lint ansible/ -v || true
  artifacts:
    paths:
      - .ansible-lint.log
    expire_in: 1 week
  allow_failure: true
```

**ansible-lint опции:**
```yaml
script:
  - ansible-lint ansible/ 
      --exclude ansible/inventory/ 
      --skip-list yaml[line-length] 
      -v
```

| Опция | Назначение |
|-------|------------|
| `--exclude` | Исключение директорий |
| `--skip-list` | Игнорирование специфичных правил |
| `-v` | Verbose output |
| `--nocolor` | Отключение ANSI colors для логов |

### GitLab SAST template
```yaml
include:
  - template: Security/SAST.gitlab-ci.yml

variables:
  SAST_EXCLUDED_PATHS: "kubespray/,vendor/,*.tfstate"
  SAST_DEFAULT_ANALYZERS: "semgrep"
```

GitLab SAST автоматически определяет языки в репозитории и запускает соответствующие analyzers:
- Semgrep для Python, Go, JavaScript
- Bandit для Python
- Security Code Scan для .NET

---

## Расширенная конфигурация

### Checkov multi-cloud scanning
```yaml
checkov:
  stage: sast
  image: bridgecrew/checkov:latest
  tags:
    - infra
  script:
    - checkov -d terraform/ 
        --framework terraform 
        --output json 
        --output-file checkov-report.json
        --soft-fail
  artifacts:
    reports:
      sast: checkov-report.json
    paths:
      - checkov-report.json
    expire_in: 1 week
  allow_failure: true
```

**Checkov frameworks:**
- `terraform` - Terraform/OpenTofu
- `cloudformation` - AWS CloudFormation
- `kubernetes` - K8s manifests
- `helm` - Helm charts
- `dockerfile` - Dockerfiles

### Terraform validation
```yaml
terraform-validate:
  stage: validate
  image: hashicorp/terraform:1.6
  tags:
    - infra
  script:
    - cd terraform/
    - terraform init -backend=false
    - terraform validate
    - terraform fmt -check -recursive
```

### YAML linting
```yaml
yamllint:
  stage: validate
  image: cytopia/yamllint:latest
  tags:
    - infra
  script:
    - yamllint ansible/ -f parsable
  allow_failure: true
```

`.yamllint` конфигурация:
```yaml
extends: default

rules:
  line-length:
    max: 120
  indentation:
    spaces: 2
  comments:
    min-spaces-from-content: 1
```

---

## Интерпретация результатов

### tfsec severity levels

| Level | Значение | Action |
|-------|----------|--------|
| CRITICAL | Немедленное исправление | Block merge |
| HIGH | Исправить до production | Review required |
| MEDIUM | Запланировать fix | Advisory |
| LOW | Best practice | Informational |


### Типовые находки tfsec

**Unencrypted disk:**
```
Rule: yandex-compute-disk-encryption
Severity: HIGH
Resource: yandex_compute_disk.data
```

Исправление:
```hcl
resource "yandex_compute_disk" "data" {
  name = "data-disk"
  type = "network-ssd"
  size = 100

  # Включение encryption at rest
  disk_encryption_key {
    kms_key_id = yandex_kms_symmetric_key.disk_key.id
  }
}

resource "yandex_kms_symmetric_key" "disk_key" {
  name              = "disk-encryption-key"
  default_algorithm = "AES_256"
}
```

**Public network exposure:**
```
Rule: yandex-vpc-no-public-ingress
Severity: CRITICAL
Resource: yandex_vpc_security_group_rule.ssh
```

Исправление:
```hcl
resource "yandex_vpc_security_group_rule" "ssh" {
  security_group_binding = yandex_vpc_security_group.main.id
  direction              = "ingress"
  protocol               = "TCP"
  port                   = 22
  v4_cidr_blocks         = ["10.10.0.0/16"]  # Не ["0.0.0.0/0"]
}
```

**Object Storage без encryption:**
```
Rule: yandex-storage-bucket-encryption
Severity: HIGH
Resource: yandex_storage_bucket.data
```

Исправление:
```hcl
resource "yandex_storage_bucket" "data" {
  bucket = "my-secure-bucket"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.bucket_key.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
```

**Compute instance с public IP:**
```
Rule: yandex-compute-no-public-ip
Severity: MEDIUM
Resource: yandex_compute_instance.web
```

Исправление:
```hcl
resource "yandex_compute_instance" "web" {
  name = "web-server"

  network_interface {
    subnet_id = yandex_vpc_subnet.private.id
    # Удалить nat = true
    # Доступ через bastion/NAT gateway
  }
}

# Bastion для доступа
resource "yandex_compute_instance" "bastion" {
  name = "bastion"

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true  # Только bastion имеет public IP
  }
}
```

---

## Интеграция с GitLab Security Dashboard

### Security Reports в Merge Requests

Конфигурация artifacts:
```yaml
tfsec:
  artifacts:
    reports:
      sast: tfsec-report.json
```

GitLab автоматически:
- Парсит SAST reports
- Отображает vulnerabilities в MR
- Показывает diff между branches
- Блокирует merge при CRITICAL issues (опционально)

### Политики для Merge Request approval

Project Settings → Merge Requests → Merge request approvals

Правила:
- Require approval на MR с HIGH/CRITICAL vulnerabilities
- Designate security team как approvers
- Prevent merge until approval

---

## Troubleshooting

### tfsec: entrypoint conflicts

**Симптомы:**
```
Error: unknown shorthand flag: 'c' in -c
```

**Причина:** GitLab runner script execution конфликтует с Docker image entrypoint.

**Решение:**
```yaml
image:
  name: aquasec/tfsec:latest
  entrypoint: [""]

script:
  - /usr/bin/tfsec terraform/
```

### ansible-lint: module not found

**Симптомы:**
```
WARNING: Couldn't parse task at ansible/playbooks/main.yml:10
```

**Причина:** Отсутствие Ansible collections или неправильный requirements.

**Решение:**
```yaml
before_script:
  - pip install ansible-lint ansible
  - ansible-galaxy collection install -r requirements.yml
```

`requirements.yml`:
```yaml
collections:
  - name: community.general
    version: ">=5.0.0"
  - name: ansible.posix
```

### False positives filtering

**tfsec ignore:**

В коде через комментарии:
```hcl
#tfsec:ignore:aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "logs" {
  # Justified: logs bucket, encrypted at application level
  bucket = "app-logs"
}
```

В конфигурации:
```yaml
script:
  - tfsec terraform/ 
      --exclude-downloaded-modules
      --config-file tfsec.yml
```

`tfsec.yml`:
```yaml
severity_overrides:
  aws-s3-enable-versioning: LOW
  
exclude:
  - aws-ec2-no-public-ingress-sgr
```

**ansible-lint skip:**
```yaml
- name: Intentional command use
  command: /usr/bin/custom-script.sh
  tags:
    - skip_ansible_lint
```

`.ansible-lint`:
```yaml
skip_list:
  - yaml[line-length]
  - name[casing]

exclude_paths:
  - vendor/
  - .github/
```

---

## Best Practices

**CI/CD integration:**
- Запуск SAST на каждый push в feature branch
- Mandatory checks для merge в master
- Separate stage для security чтобы не блокировать быстрые проверки
- `allow_failure: true` на начальных этапах внедрения

**Remediation workflow:**
- Приоритизация по severity (CRITICAL → HIGH → MEDIUM → LOW)
- Security team review для CRITICAL/HIGH
- Создание issues для tracking
- Документирование false positives

**Configuration management:**
- Version control для конфигураций scanners
- Shared configs через includes
- Environment-specific rules
- Regular updates инструментов

**Reporting:**
- Экспорт reports в artifacts для анализа
- Integration с Security Dashboard
- Notifications в Slack/email для CRITICAL
- Metrics tracking (vulnerabilities over time)

**Continuous improvement:**
- Regular review ignore rules
- Добавление custom checks
- Team training на типовых проблемах
- Automated remediation где возможно

---

## Полезные команды

### Локальный запуск scanners
```bash
# tfsec
docker run --rm -v $(pwd):/src aquasec/tfsec:latest /src/terraform

# checkov
docker run --rm -v $(pwd):/tf bridgecrew/checkov -d /tf/terraform

# ansible-lint
docker run --rm -v $(pwd):/data cytopia/ansible-lint:latest ansible-lint /data/ansible

# trivy для IaC
docker run --rm -v $(pwd):/workspace aquasec/trivy config /workspace/terraform
```

### GitLab API для Security Reports
```bash
# Получить security report для MR
curl --header "PRIVATE-TOKEN: <TOKEN>" \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/merge_requests/<MR_IID>/security_reports"

# Список vulnerabilities в проекте
curl --header "PRIVATE-TOKEN: <TOKEN>" \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/vulnerabilities"

# Создать issue для vulnerability
curl --request POST --header "PRIVATE-TOKEN: <TOKEN>" \
  --data "title=Security Issue&description=Fix vulnerability" \
  "https://gitlab.com/api/v4/projects/<PROJECT_ID>/issues"
```

### Debugging scanner issues
```bash
# Проверка tfsec версии и rules
docker run --rm aquasec/tfsec:latest --version
docker run --rm aquasec/tfsec:latest --list-rules

# ansible-lint verbose
ansible-lint ansible/ -vvv

# checkov list checks
checkov --list
```
