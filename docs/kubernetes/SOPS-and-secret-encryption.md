# SOPS шифрование секретов

Безопасное хранение Kubernetes секретов в Git через SOPS (Secrets OPerationS) с интеграцией в CI/CD pipelines и GitOps workflows.

## Предварительные требования

- Kubernetes кластер >= 1.28
- kubectl с настроенным kubeconfig
- GPG >= 2.0 или age для шифрования
- Helm >= 3.19 (для helm-secrets интеграции)

---

## SOPS: назначение и security model

### Проблема plain text секретов в Git

Без SOPS:
```yaml
# secrets.yaml в Git репозитории
database:
  password: SuperSecret123!  # <- Видно всем с доступом к repo
  
git add secrets.yaml
git push  # <- Секрет в истории Git НАВСЕГДА
```

Проблемы:
- Секреты доступны всем с read access к repo
- История Git хранит все версии секретов
- Невозможно отозвать скомпрометированный секрет
- Compliance violations (GDPR, PCI-DSS)

### Решение через SOPS

С SOPS:
```yaml
# secrets.enc.yaml в Git
database:
  password: ENC[AES256_GCM,data:aaEQOwKjcg...]  # <- Зашифровано
  
git add secrets.enc.yaml
git push  # <- Безопасно для хранения в Git
```

SOPS шифрует values, сохраняя keys readable:
- Структура YAML остается видимой
- Values зашифрованы AES256-GCM
- Metadata о ключе шифрования в файле
- Версионирование в Git безопасно

### Security model: что защищает SOPS

**SOPS защищает:**
- ✓ Секреты в Git репозитории
- ✓ Секреты в CI/CD artifacts
- ✓ От случайных коммитов plain text
- ✓ От утечки через backup/logs
- ✓ Audit trail (кто расшифровывал)

**SOPS НЕ защищает:**
- ✗ Секреты в running кластере (plain text в etcd)
- ✗ От admin доступа к Kubernetes
- ✗ От компрометации ключа шифрования
- ✗ От бокового канала атак
- ✗ Runtime secrets в памяти pod

### Workflow: где происходит расшифровка
```
Developer (laptop)
  ├─ secrets.yaml (plain text)
  ├─ sops --encrypt → secrets.enc.yaml
  └─ git push
       ↓
GitHub/GitLab Repository
  └─ secrets.enc.yaml (зашифровано, безопасно)
       ↓
CI/CD Pipeline (GitLab Runner с GPG key)
  ├─ sops --decrypt secrets.enc.yaml
  ├─ kubectl apply -f - (plain text!)
       ↓
Kubernetes Cluster
  └─ Secret в etcd (base64, НЕ шифрование!)
       ↓
Pod
  └─ Видит plain text секрет в ENV/volume
```

**Ключевой момент:** SOPS = безопасность в Git, НЕ в кластере. Расшифровка происходит при deployment, в кластере секреты обычные (base64 encoded).

---

## Установка и настройка SOPS

### Установка SOPS

Скачивание последней версии:
```bash
curl -LO https://github.com/getsops/sops/releases/download/v3.9.3/sops-v3.9.3.linux.amd64
```

Установка:
```bash
sudo mv sops-v3.9.3.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
```

Проверка версии:
```bash
sops --version
```

SOPS поддерживает несколько backend для ключей:
- GPG (GNU Privacy Guard)
- age (modern alternative to GPG)
- AWS KMS
- Azure Key Vault
- GCP KMS
- HashiCorp Vault

### Создание GPG ключа

Генерация ключа без passphrase (для автоматизации):
```bash
gpg --batch --gen-key << EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: K8s Secrets
Name-Email: secrets@k8s.local
Expire-Date: 0
EOF
```

Параметры:
- `%no-protection` - без passphrase для CI/CD
- `RSA 4096` - современный стандарт
- `Expire-Date: 0` - без expiration (или установить срок)

Получение fingerprint:
```bash
gpg --list-keys --keyid-format LONG
```

Вывод:
```
pub   rsa4096/BF0618854B6F12F0 2025-11-22 [SCEA]
      3EDAA53CF48895120F427151BF0618854B6F12F0
uid                 [ultimate] K8s Secrets
```

Fingerprint: `3EDAA53CF48895120F427151BF0618854B6F12F0`

Экспорт приватного ключа (для CI/CD):
```bash
gpg --export-secret-keys --armor 3EDAA53CF48895120F427151BF0618854B6F12F0 > gpg-private-key.asc
```

**Важно:** Хранить приватный ключ в secure storage (Vault, GitLab CI/CD Variables masked).

---

## Шифрование секретов

### Создание файла секретов

Структура проекта:
```bash
mkdir -p ~/sops-demo
cd ~/sops-demo
```

Создание secrets.yaml с plain text данными:
```yaml
database:
  username: admin
  password: SuperSecret123!
  host: postgres.example.com
  port: 5432

api:
  key: sk-1234567890abcdef
  secret: very-secret-token-here

redis:
  password: RedisP@ssw0rd
```

Файл содержит чувствительные данные для БД, API, Redis.

### Шифрование через GPG

Шифрование файла:
```bash
sops --encrypt --pgp 3EDAA53CF48895120F427151BF0618854B6F12F0 secrets.yaml > secrets.enc.yaml
```

Параметры:
- `--encrypt` - режим шифрования
- `--pgp <FINGERPRINT>` - использовать GPG ключ
- `> secrets.enc.yaml` - вывод в новый файл

Просмотр зашифрованного файла:
```bash
cat secrets.enc.yaml
```

Вывод:
```yaml
database:
    username: ENC[AES256_GCM,data:OTwSGlI=,iv:WIn0+I7x...,tag:HIKLrij3...,type:str]
    password: ENC[AES256_GCM,data:aaEQOwKj...,iv:6X4+i+Ne...,tag:Oh5/LxBQ...,type:str]
    host: ENC[AES256_GCM,data:VO0UUfGs...,iv:MuD8mUuM...,tag:nsyqQxQb...,type:str]
    port: ENC[AES256_GCM,data:0iHM0Q==,iv:IT9s4otd...,tag:tJ8ZRk58...,type:int]
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age: []
    lastmodified: "2025-11-22T07:42:27Z"
    mac: ENC[AES256_GCM,data:/HNVr3SK...,iv:Q4M/4uPP...,tag:GXOsh4uL...,type:str]
    pgp:
        - created_at: "2025-11-22T07:42:27Z"
          enc: |-
            -----BEGIN PGP MESSAGE-----
            hQIMA78GGIVLbxLwARAAgVDms5oKjAMqH+DjlY6Vze/IFqd+...
            -----END PGP MESSAGE-----
          fp: 3EDAA53CF48895120F427151BF0618854B6F12F0
    unencrypted_suffix: _unencrypted
    version: 3.9.3
```

SOPS metadata:
- `lastmodified` - timestamp последнего изменения
- `mac` - Message Authentication Code для integrity
- `pgp.enc` - зашифрованный data encryption key
- `fp` - fingerprint использованного GPG ключа

### Расшифровка файла

Расшифровка в stdout:
```bash
sops --decrypt secrets.enc.yaml
```

Вывод показывает исходный plain text. Работает только с приватным GPG ключом.

Расшифровка в файл:
```bash
sops --decrypt secrets.enc.yaml > secrets-decrypted.yaml
```

**Важно:** Не коммитить расшифрованные файлы в Git. Добавить в .gitignore:
```bash
echo "secrets-decrypted.yaml" >> .gitignore
echo "*-decrypted.yaml" >> .gitignore
```

### In-place редактирование

SOPS editor mode:
```bash
sops secrets.enc.yaml
```

SOPS:
1. Расшифровывает файл
2. Открывает в $EDITOR (vim/nano)
3. После сохранения зашифровывает обратно
4. Обновляет metadata (lastmodified, mac)

Workflow:
- Редактируешь как plain text
- Сохраняешь (:wq в vim)
- Файл автоматически зашифровывается

---

## Интеграция с Kubernetes

### Создание Secret из SOPS файла

Kubernetes Secret манифест:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: default
type: Opaque
stringData:
  database-username: admin
  database-password: SuperSecret123!
  database-host: postgres.example.com
  api-key: sk-1234567890abcdef
  api-secret: very-secret-token-here
  redis-password: RedisP@ssw0rd
```

Шифрование манифеста:
```bash
sops --encrypt --pgp 3EDAA53CF48895120F427151BF0618854B6F12F0 k8s-secret.yaml > k8s-secret.enc.yaml
```

Развертывание в кластер:
```bash
sops --decrypt k8s-secret.enc.yaml | kubectl apply -f -
```

Pipeline: расшифровка → kubectl → Secret в кластере.

Проверка созданного Secret:
```bash
kubectl get secret app-secrets
kubectl describe secret app-secrets
```

Проверка расшифрованных данных:
```bash
kubectl get secret app-secrets -o jsonpath='{.data.database-password}' | base64 -d
```

Вывод: `SuperSecret123!` - секрет корректно сохранен.

---

## Helm-secrets интеграция

### Установка helm-secrets plugin
```bash
helm plugin install https://github.com/jkroepke/helm-secrets
```

helm-secrets добавляет команду `helm secrets` для автоматической расшифровки SOPS values при install/upgrade.

Проверка установки:
```bash
helm plugin list
```

### Использование зашифрованных values

Создание values файла:
```yaml
database:
  password: production-secret-password

api:
  token: prod-api-token-12345
```

Шифрование для Helm:
```bash
sops --encrypt --pgp 3EDAA53CF48895120F427151BF0618854B6F12F0 helm-secrets.yaml > helm-secrets.enc.yaml
```

Template с расшифровкой:
```bash
helm secrets template test-release ./mychart -f helm-secrets.enc.yaml
```

helm-secrets автоматически:
1. Распознает .enc.yaml
2. Расшифровывает через SOPS
3. Передает plain values в Helm
4. Удаляет временный расшифрованный файл

Install с зашифрованными values:
```bash
helm secrets install myrelease ./mychart -f helm-secrets.enc.yaml
```

Upgrade:
```bash
helm secrets upgrade myrelease ./mychart -f helm-secrets.enc.yaml
```

---

## SOPS интеграция: варианты deployment

### Вариант 1: CI/CD Pipeline (GitLab)

GitLab CI/CD с SOPS:
```yaml
# .gitlab-ci.yml
variables:
  KUBE_NAMESPACE: production

stages:
  - deploy

deploy:
  stage: deploy
  image: 
    name: alpine/k8s:1.28.0
    entrypoint: [""]
  before_script:
    # Импорт GPG приватного ключа из CI/CD variable
    - echo "$GPG_PRIVATE_KEY" | gpg --import
    - curl -LO https://github.com/getsops/sops/releases/download/v3.9.3/sops-v3.9.3.linux.amd64
    - chmod +x sops-v3.9.3.linux.amd64
    - mv sops-v3.9.3.linux.amd64 /usr/local/bin/sops
  script:
    # Расшифровка и применение секретов
    - sops -d k8s/secrets.enc.yaml | kubectl apply -f -
    
    # Или с Helm
    - helm plugin install https://github.com/jkroepke/helm-secrets
    - helm secrets upgrade --install myapp ./chart -f values.enc.yaml -n $KUBE_NAMESPACE
  only:
    - main
```

Настройка GPG_PRIVATE_KEY variable:
1. GitLab → Settings → CI/CD → Variables
2. Add variable: `GPG_PRIVATE_KEY`
3. Value: содержимое `gpg-private-key.asc`
4. Type: File (для больших ключей) или Variable
5. Flags: Masked, Protected

### Вариант 2: ArgoCD с SOPS plugin

ArgoCD поддерживает автоматическую расшифровку SOPS через plugin.

Установка SOPS plugin в ArgoCD:
```yaml
# argocd-repo-server deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-repo-server
spec:
  template:
    spec:
      volumes:
      - name: custom-tools
        emptyDir: {}
      - name: sops-gpg
        secret:
          secretName: sops-gpg-key
      
      initContainers:
      - name: install-sops
        image: alpine:latest
        command:
        - sh
        - -c
        - |
          wget -O /custom-tools/sops https://github.com/getsops/sops/releases/download/v3.9.3/sops-v3.9.3.linux.amd64
          chmod +x /custom-tools/sops
        volumeMounts:
        - name: custom-tools
          mountPath: /custom-tools
      
      containers:
      - name: argocd-repo-server
        volumeMounts:
        - name: custom-tools
          mountPath: /usr/local/bin/sops
          subPath: sops
        - name: sops-gpg
          mountPath: /home/argocd/.gnupg
```

ConfigMap для SOPS support:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # Enable Helm with SOPS
  helm.valuesFileSchemes: >-
    secrets+gpg-import,
    secrets+age-import,
    secrets+gpg-import-kubernetes,
    secrets
```

Создание GPG Secret:
```bash
kubectl create secret generic sops-gpg-key \
  -n argocd \
  --from-file=private.key=gpg-private-key.asc
```

Application манифест:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  source:
    repoURL: https://github.com/org/repo
    path: charts/myapp
    helm:
      valueFiles:
        - secrets://values.enc.yaml  # <- ArgoCD расшифрует автоматически
```

ArgoCD workflow:
```
Git Repo (values.enc.yaml) 
    → ArgoCD Repo Server (sops -d) 
    → Helm Template 
    → K8s Apply
```

### Вариант 3: Flux CD с SOPS

Flux имеет встроенную поддержку SOPS.

Создание GPG Secret для Flux:
```bash
gpg --export-secret-keys --armor 3EDAA53CF48895120F427151BF0618854B6F12F0 | \
kubectl create secret generic sops-gpg \
  --namespace=flux-system \
  --from-file=sops.asc=/dev/stdin
```

Kustomization с SOPS decryption:
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: flux-system
spec:
  interval: 10m
  path: ./clusters/production
  sourceRef:
    kind: GitRepository
    name: fleet-infra
  # SOPS decryption configuration
  decryption:
    provider: sops
    secretRef:
      name: sops-gpg
```

Flux автоматически:
1. Обнаруживает .sops.yaml metadata в файлах
2. Расшифровывает через указанный GPG key
3. Применяет plain manifests в кластер
4. Синхронизирует изменения из Git

HelmRelease с SOPS values:
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: myapp
spec:
  chart:
    spec:
      chart: ./charts/myapp
  # Values будут расшифрованы Flux
  valuesFrom:
  - kind: Secret
    name: myapp-secrets  # <- SOPS-encrypted values
```

### Вариант 4: Manual deployment script

Скрипт для ручного deployment:
```bash
#!/bin/bash
# deploy.sh

set -euo pipefail

NAMESPACE="${1:-default}"
ENV="${2:-production}"

echo "Deploying to namespace: $NAMESPACE, environment: $ENV"

# Расшифровка и применение секретов
for file in k8s/secrets/${ENV}/*.enc.yaml; do
    echo "Processing $file..."
    sops -d "$file" | kubectl apply -n "$NAMESPACE" -f -
done

# Helm deployment с зашифрованными values
helm secrets upgrade --install myapp ./charts/myapp \
    -f charts/myapp/values.yaml \
    -f charts/myapp/values-${ENV}.enc.yaml \
    -n "$NAMESPACE"

echo "Deployment complete"
```

Использование:
```bash
chmod +x deploy.sh
./deploy.sh production production
```

---

## Сравнение подходов интеграции

| Метод | Расшифровка где | GPG key где | GitOps friendly | Complexity |
|-------|-----------------|-------------|-----------------|------------|
| CI/CD Pipeline | GitLab Runner | CI/CD Variables | Средне | Низкая |
| ArgoCD + SOPS | ArgoCD Controller | K8s Secret (argocd NS) | ✓ Да | Средняя |
| Flux + SOPS | Flux Controller | K8s Secret (flux-system NS) | ✓ Да | Средняя |
| Manual script | Admin laptop | ~/.gnupg/ | ✗ Нет | Низкая |
| Sealed Secrets | Controller | K8s (cluster-scoped) | ✓ Да | Средняя |

### Best Practice для GitOps

ArgoCD или Flux с SOPS plugin:
```
Developer
  ↓
secrets.enc.yaml → Git push
  ↓
ArgoCD/Flux (с SOPS support)
  ├─ Детект .sops.yaml metadata
  ├─ Расшифровка с GPG key из K8s Secret
  ├─ Apply plain Secret в кластер
  └─ Git = source of truth
```

Преимущества:
- ✓ Секреты зашифрованы в Git
- ✓ GitOps workflow без компромиссов
- ✓ Автоматическая sync при изменениях
- ✓ GPG key изолирован в кластере
- ✓ Audit trail через Git history

---

## Troubleshooting

### GPG key not found

**Симптомы:**
- `sops --encrypt` возвращает "no key found"
- Fingerprint не распознается

**Ошибка:**
```
Error: no matching keys found for fingerprint
```

**Причина:** GPG ключ не импортирован или fingerprint неверный.

**Решение:**

Проверка доступных ключей:
```bash
gpg --list-keys
```

Импорт ключа (если нужен):
```bash
gpg --import gpg-private-key.asc
```

Получение правильного fingerprint:
```bash
gpg --list-keys --keyid-format LONG | grep -A 1 "K8s Secrets"
```

**Проверка:**
```bash
sops --encrypt --pgp <FINGERPRINT> test.yaml
```

### Failed to decrypt: MAC mismatch

**Симптомы:**
- `sops --decrypt` возвращает MAC error
- Файл поврежден

**Ошибка:**
```
Error: MAC mismatch. File has been tampered with
```

**Причина:** Файл изменен вручную после шифрования или поврежден при передаче.

**Решение:**

SOPS использует MAC (Message Authentication Code) для integrity check. Если MAC не совпадает - файл изменялся.

Восстановление из Git:
```bash
git checkout secrets.enc.yaml
```

Пересоздание из источника:
```bash
sops --encrypt --pgp <FINGERPRINT> secrets.yaml > secrets.enc.yaml
```

**Проверка:**
```bash
sops --decrypt secrets.enc.yaml
```

### CI/CD: GPG import failed

**Симптомы:**
- Pipeline падает на импорте GPG ключа
- "Invalid key" error

**Ошибка:**
```
gpg: no valid OpenPGP data found
```

**Причина:** Некорректный формат GPG ключа в CI/CD variable или encoding проблемы.

**Решение:**

Проверка экспорта ключа:
```bash
gpg --export-secret-keys --armor <FINGERPRINT> > key.asc
cat key.asc
```

Должно начинаться с `-----BEGIN PGP PRIVATE KEY BLOCK-----`.

В GitLab CI/CD:
1. Variable type: File (для больших ключей)
2. Или base64 encode для Variable type:
```bash
gpg --export-secret-keys --armor <FINGERPRINT> | base64 -w 0
```

В pipeline:
```yaml
before_script:
  - echo "$GPG_PRIVATE_KEY_BASE64" | base64 -d | gpg --import
```

**Проверка:**
```bash
gpg --list-secret-keys
```

### Helm-secrets: plugin not found

**Симптомы:**
- `helm secrets` возвращает unknown command
- Plugin не установлен

**Ошибка:**
```
Error: unknown command "secrets" for "helm"
```

**Причина:** helm-secrets plugin не установлен.

**Решение:**
```bash
helm plugin install https://github.com/jkroepke/helm-secrets
```

Проверка установки:
```bash
helm plugin list
```

Должно показать helm-secrets в списке.

**Проверка:**
```bash
helm secrets --help
```

### ArgoCD: SOPS decryption not working

**Симптомы:**
- ArgoCD применяет зашифрованные values как есть
- Pods получают encrypted data

**Причина:** SOPS plugin не настроен или GPG Secret отсутствует.

**Решение:**

Проверка argocd-cm ConfigMap:
```bash
kubectl get cm argocd-cm -n argocd -o yaml | grep valuesFileSchemes
```

Должно содержать `secrets+gpg-import`.

Проверка GPG Secret:
```bash
kubectl get secret -n argocd sops-gpg-key
kubectl get secret -n argocd sops-gpg-key -o jsonpath='{.data.private\.key}' | base64 -d | gpg --import
```

Перезапуск argocd-repo-server:
```bash
kubectl rollout restart deployment -n argocd argocd-repo-server
```

**Проверка:**

Проверка логов repo-server:
```bash
kubectl logs -n argocd deployment/argocd-repo-server | grep -i sops
```

---

## Best Practices

**Key Management:**
- Использовать отдельные GPG ключи для разных environments
- Ротация ключей каждые 6-12 месяцев
- Backup приватных ключей в secure storage (Vault)
- Использовать passphrase для production ключей
- Документировать key distribution process

**File Organization:**
- Разделять секреты по environments (secrets-prod.enc.yaml, secrets-staging.enc.yaml)
- Использовать .sops.yaml для project-level конфигурации
- Группировать related секреты в одном файле
- Добавлять *-decrypted.yaml в .gitignore
- Версионировать .enc.yaml файлы в Git

**CI/CD Integration:**
- Хранить GPG ключи в masked CI/CD variables
- Использовать minimal scope для deployment keys
- Audit логировать все расшифровки
- Rotate CI/CD GPG keys регулярно
- Тестировать encryption/decryption в pre-commit hooks

**GitOps Patterns:**
- Предпочитать ArgoCD/Flux с SOPS plugin для production
- Использовать separate namespaces для GPG Secrets
- Restrict access к GPG Secrets через RBAC
- Monitor SOPS decryption errors через alerts
- Implement disaster recovery для ключей

**Security:**
- Никогда не коммитить plain text секреты
- Никогда не коммитить GPG приватные ключи
- Использовать .gitignore для защиты
- Audit access к GPG ключам
- Implement break-glass procedure для emergency

---

## Полезные команды

### SOPS Operations
```bash
# Шифрование файла
sops --encrypt --pgp <FINGERPRINT> secrets.yaml > secrets.enc.yaml

# Расшифровка в stdout
sops --decrypt secrets.enc.yaml

# Расшифровка в файл
sops --decrypt secrets.enc.yaml > secrets-plain.yaml

# In-place редактирование
sops secrets.enc.yaml

# Пересоздание с новым ключом
sops --rotate -i secrets.enc.yaml

# Извлечение конкретного значения
sops --decrypt --extract '["database"]["password"]' secrets.enc.yaml
```

### GPG Management
```bash
# Генерация ключа
gpg --gen-key

# Список ключей
gpg --list-keys
gpg --list-secret-keys

# Экспорт публичного ключа
gpg --export --armor <FINGERPRINT> > public.asc

# Экспорт приватного ключа
gpg --export-secret-keys --armor <FINGERPRINT> > private.asc

# Импорт ключа
gpg --import key.asc

# Удаление ключа
gpg --delete-secret-keys <FINGERPRINT>
gpg --delete-keys <FINGERPRINT>

# Trust level
gpg --edit-key <FINGERPRINT>
# в interactive mode: trust -> 5 -> y -> quit
```

### Kubernetes Secrets
```bash
# Создание из SOPS файла
sops -d secrets.enc.yaml | kubectl apply -f -

# Проверка Secret
kubectl get secret <NAME>
kubectl describe secret <NAME>

# Извлечение значения
kubectl get secret <NAME> -o jsonpath='{.data.password}' | base64 -d

# Удаление Secret
kubectl delete secret <NAME>
```

### Helm-secrets
```bash
# Template с расшифровкой
helm secrets template <RELEASE> <CHART> -f values.enc.yaml

# Install
helm secrets install <RELEASE> <CHART> -f values.enc.yaml

# Upgrade
helm secrets upgrade <RELEASE> <CHART> -f values.enc.yaml

# Diff перед применением
helm secrets diff upgrade <RELEASE> <CHART> -f values.enc.yaml
```

---

## SOPS configuration file (.sops.yaml)

Project-level конфигурация для автоматизации:
```yaml
# .sops.yaml в корне репозитория
creation_rules:
  # Production секреты
  - path_regex: secrets/production/.*\.yaml$
    pgp: '3EDAA53CF48895120F427151BF0618854B6F12F0'
    
  # Staging секреты
  - path_regex: secrets/staging/.*\.yaml$
    pgp: 'ANOTHER_FINGERPRINT_FOR_STAGING'
    
  # AWS KMS для production
  - path_regex: secrets/aws/.*\.yaml$
    kms: 'arn:aws:kms:us-east-1:123456789:key/abc-def'
    
  # Age ключи для development
  - path_regex: secrets/dev/.*\.yaml$
    age: 'age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
```

С .sops.yaml команды упрощаются:
```bash
# Автоматически использует правильный ключ по path
sops --encrypt secrets/production/database.yaml > secrets/production/database.enc.yaml
```

---

## Альтернативы SOPS

**Sealed Secrets:**
- Controller в кластере для расшифровки
- Asymmetric encryption (cluster public key)
- Автоматическая расшифровка при apply
- Tight integration с Kubernetes

**External Secrets Operator:**
- Синхронизация из external sources (Vault, AWS Secrets Manager)
- Не требует шифрования файлов
- Runtime sync секретов
- Support множественных backends

**Vault:**
- Centralized secret management
- Dynamic secrets generation
- Fine-grained access control
- Audit logging

Выбор зависит от:
- Existing infrastructure (cloud provider KMS, Vault)
- Security requirements (encryption at rest, transit, runtime)
- Team skills (GPG знание, Vault expertise)
- Compliance (audit requirements, key rotation)
