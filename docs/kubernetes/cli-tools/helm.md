# Helm - Менеджер пакетов Kubernetes

Справочник команд Helm для управления charts и releases в Kubernetes.

## Предварительные требования

- Helm версии 3.x+
- kubectl с доступом к кластеру
- Понимание концепций charts и releases

---

## Repository управление

### Добавление repository

```bash
helm repo add <n> <URL>
helm repo add stable https://charts.helm.sh/stable
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

**С authentication:**

```bash
helm repo add <n> <URL> --username <USER> --password <PASS>
helm repo add private https://charts.example.com --username admin --password <PASSWORD>
```

| Флаг | Описание |
|------|----------|
| `--username` | Username для HTTP basic auth |
| `--password` | Password для HTTP basic auth |
| `--ca-file` | CA certificate file |
| `--cert-file` | Client certificate file |
| `--key-file` | Client key file |
| `--insecure-skip-tls-verify` | Пропустить TLS verification |
| `--pass-credentials` | Передавать credentials всем domains |

### Просмотр repositories

```bash
helm repo list
helm repo ls
```

### Обновление repositories

```bash
helm repo update
helm repo update <REPO_NAME>
```

Обновление локального кэша charts из repositories.

### Удаление repository

```bash
helm repo remove <n>
helm repo rm <n>
```

---

## Chart поиск

### Поиск в repositories

```bash
helm search repo <KEYWORD>
helm search repo nginx
helm search repo database
```

**С версиями:**

```bash
helm search repo <CHART> --versions
helm search repo nginx --versions
```

**С regex:**

```bash
helm search repo <PATTERN> --regexp
```

### Поиск в Artifact Hub

```bash
helm search hub <KEYWORD>
helm search hub prometheus
helm search hub postgres
```

Поиск в https://artifacthub.io.

### Информация о chart

```bash
helm show chart <REPO>/<CHART>
helm show chart bitnami/nginx
```

**Все детали:**

```bash
helm show all <REPO>/<CHART>
helm show all bitnami/postgresql
```

**README:**

```bash
helm show readme <REPO>/<CHART>
```

**Values:**

```bash
helm show values <REPO>/<CHART>
helm show values bitnami/nginx > values.yaml
```

---

## Install - Установка releases

### Базовая установка

```bash
helm install <RELEASE_NAME> <CHART>
helm install nginx bitnami/nginx
helm install postgres bitnami/postgresql
```

**С namespace:**

```bash
helm install <RELEASE_NAME> <CHART> -n <NAMESPACE>
helm install nginx bitnami/nginx -n web --create-namespace
```

| Флаг | Описание |
|------|----------|
| `-n, --namespace` | Namespace для release |
| `--create-namespace` | Создать namespace если не существует |
| `--generate-name` | Автогенерация имени release |
| `--name-template` | Template для имени release |
| `--dry-run` | Тестовый запуск без установки |
| `--wait` | Ожидание готовности всех ресурсов |
| `--timeout` | Таймаут для wait (default 5m) |
| `--atomic` | Откат при ошибке установки |
| `--debug` | Verbose debug output |

### Установка с values

**Из файла:**

```bash
helm install <RELEASE_NAME> <CHART> -f values.yaml
helm install <RELEASE_NAME> <CHART> --values values.yaml
```

**Множественные values файлы:**

```bash
helm install nginx bitnami/nginx -f values-common.yaml -f values-prod.yaml
```

Values применяются в порядке указания (последний перезаписывает предыдущие).

**Inline значения:**

```bash
helm install <RELEASE_NAME> <CHART> --set <KEY>=<VALUE>
helm install nginx bitnami/nginx --set replicaCount=3 --set service.type=LoadBalancer
```

**Вложенные значения:**

```bash
helm install nginx bitnami/nginx --set image.tag=1.21 --set service.ports.http=8080
```

**Array значения:**

```bash
helm install app chart --set 'tolerations[0].key=key1,tolerations[0].value=value1'
```

**String значения с запятыми:**

```bash
helm install app chart --set 'nodeSelector."beta\.kubernetes\.io/instance-type"=m5.large'
```

**Из файла:**

```bash
helm install nginx bitnami/nginx --set-file config=nginx.conf
```

**String values:**

```bash
helm install app chart --set-string nodePort=30080
```

Force string type для значения.

### Установка из локального chart

```bash
helm install <RELEASE_NAME> ./chart-directory
helm install <RELEASE_NAME> chart-package.tgz
helm install <RELEASE_NAME> https://example.com/charts/app-1.0.0.tgz
```

### Генерация имени release

```bash
helm install <CHART> --generate-name
helm install bitnami/nginx --generate-name
```

**С template:**

```bash
helm install <CHART> --name-template "nginx-{{randAlpha 8}}"
```

### Конкретная версия

```bash
helm install <RELEASE_NAME> <CHART> --version <VERSION>
helm install nginx bitnami/nginx --version 15.0.0
```

### Atomic install

```bash
helm install <RELEASE_NAME> <CHART> --atomic --timeout 10m
```

Автоматический откат при ошибке установки.

### Dry run

```bash
helm install <RELEASE_NAME> <CHART> --dry-run --debug
```

Показывает manifests без применения.

---

## Upgrade - Обновление releases

### Базовое обновление

```bash
helm upgrade <RELEASE_NAME> <CHART>
helm upgrade nginx bitnami/nginx
```

**С values:**

```bash
helm upgrade <RELEASE_NAME> <CHART> -f values.yaml
helm upgrade nginx bitnami/nginx --set replicaCount=5
```

| Флаг | Описание |
|------|----------|
| `-f, --values` | Values файл |
| `--set` | Inline значения |
| `--reuse-values` | Использовать существующие values |
| `--reset-values` | Сбросить values к chart defaults |
| `--force` | Принудительное пересоздание ресурсов |
| `--install` | Установить если release не существует |
| `--atomic` | Откат при ошибке |
| `--cleanup-on-fail` | Очистка новых ресурсов при ошибке |
| `--wait` | Ожидание готовности ресурсов |
| `--timeout` | Таймаут для wait |

### Install or Upgrade

```bash
helm upgrade --install <RELEASE_NAME> <CHART>
helm upgrade --install nginx bitnami/nginx -f values.yaml
```

Установка если release не существует, иначе обновление.

### Reuse values

```bash
helm upgrade nginx bitnami/nginx --reuse-values
helm upgrade nginx bitnami/nginx --reuse-values --set newKey=newValue
```

Сохранение предыдущих values с возможностью override.

### Reset values

```bash
helm upgrade nginx bitnami/nginx --reset-values
```

Сброс всех values к chart defaults.

### Force upgrade

```bash
helm upgrade nginx bitnami/nginx --force
```

Принудительное пересоздание ресурсов через delete/recreate.

---

## Rollback - Откат releases

### Откат к предыдущей версии

```bash
helm rollback <RELEASE_NAME>
helm rollback nginx
```

**К конкретной revision:**

```bash
helm rollback <RELEASE_NAME> <REVISION>
helm rollback nginx 3
```

| Флаг | Описание |
|------|----------|
| `--wait` | Ожидание готовности ресурсов |
| `--timeout` | Таймаут для wait |
| `--cleanup-on-fail` | Очистка при ошибке |
| `--force` | Принудительное пересоздание ресурсов |
| `--dry-run` | Тестовый откат |

**Force rollback:**

```bash
helm rollback nginx 2 --force
```

---

## Uninstall - Удаление releases

### Базовое удаление

```bash
helm uninstall <RELEASE_NAME>
helm uninstall nginx
```

**С namespace:**

```bash
helm uninstall <RELEASE_NAME> -n <NAMESPACE>
```

| Флаг | Описание |
|------|----------|
| `--keep-history` | Сохранить release history |
| `--dry-run` | Тестовое удаление |
| `--wait` | Ожидание удаления всех ресурсов |
| `--timeout` | Таймаут для wait |

**Сохранение history:**

```bash
helm uninstall nginx --keep-history
```

Позволяет rollback после uninstall.

---

## List - Просмотр releases

### Список releases

```bash
helm list
helm ls
```

**С namespace:**

```bash
helm list -n <NAMESPACE>
helm list --all-namespaces
helm list -A
```

**Фильтрация:**

```bash
helm list --deployed
helm list --failed
helm list --pending
helm list --superseded
helm list --uninstalled
helm list --all
```

| Статус | Описание |
|--------|----------|
| deployed | Successfully deployed |
| failed | Failed deployment |
| pending | In progress |
| superseded | Заменен новой версией |
| uninstalled | Удален с --keep-history |

**С regex фильтром:**

```bash
helm list --filter '<PATTERN>'
helm list --filter 'nginx.*'
```

**Сортировка:**

```bash
helm list --date
helm list --reverse
```

**Output format:**

```bash
helm list -o json
helm list -o yaml
helm list -o table
```

**С дополнительными колонками:**

```bash
helm list --max 10
helm list --offset 5
```

---

## Status - Статус release

### Проверка статуса

```bash
helm status <RELEASE_NAME>
helm status nginx
```

**С namespace:**

```bash
helm status nginx -n web
```

**Output format:**

```bash
helm status nginx -o json
helm status nginx -o yaml
```

**Конкретная revision:**

```bash
helm status nginx --revision <NUMBER>
```

---

## History - История releases

### Просмотр history

```bash
helm history <RELEASE_NAME>
helm history nginx
```

**С namespace:**

```bash
helm history nginx -n web
```

**Output format:**

```bash
helm history nginx -o json
helm history nginx -o yaml
```

**Ограничение количества:**

```bash
helm history nginx --max 5
```

---

## Get - Информация о release

### Get values

```bash
helm get values <RELEASE_NAME>
helm get values nginx
```

**Все values (включая computed):**

```bash
helm get values nginx --all
```

**Конкретная revision:**

```bash
helm get values nginx --revision 2
```

### Get manifest

```bash
helm get manifest <RELEASE_NAME>
helm get manifest nginx
```

Вывод всех Kubernetes manifests для release.

### Get hooks

```bash
helm get hooks <RELEASE_NAME>
```

Вывод hook manifests.

### Get notes

```bash
helm get notes <RELEASE_NAME>
```

Вывод NOTES.txt из chart.

### Get all

```bash
helm get all <RELEASE_NAME>
```

Вывод values, manifest, hooks, notes.

---

## Template - Рендеринг templates

### Базовый рендеринг

```bash
helm template <RELEASE_NAME> <CHART>
helm template nginx bitnami/nginx
```

**С values:**

```bash
helm template nginx bitnami/nginx -f values.yaml
helm template nginx bitnami/nginx --set replicaCount=3
```

**Output в файл:**

```bash
helm template nginx bitnami/nginx -f values.yaml > manifests.yaml
```

| Флаг | Описание |
|------|----------|
| `-f, --values` | Values файл |
| `--set` | Inline значения |
| `--show-only` | Показать только конкретные templates |
| `--validate` | Валидация manifests через Kubernetes |
| `--skip-tests` | Пропустить test templates |
| `--include-crds` | Включить CRDs |
| `--kube-version` | Kubernetes version для Capabilities |

**Показать конкретный template:**

```bash
helm template nginx bitnami/nginx --show-only templates/deployment.yaml
```

**С валидацией:**

```bash
helm template nginx bitnami/nginx --validate
```

**Debug output:**

```bash
helm template nginx bitnami/nginx --debug
```

---

## Test - Тестирование release

### Запуск tests

```bash
helm test <RELEASE_NAME>
helm test nginx
```

**С namespace:**

```bash
helm test nginx -n web
```

| Флаг | Описание |
|------|----------|
| `--timeout` | Таймаут для tests |
| `--logs` | Вывод logs test pods |

**С логами:**

```bash
helm test nginx --logs
```

---

## Plugin управление

### Установка plugin

```bash
helm plugin install <URL>
helm plugin install https://github.com/databus23/helm-diff
```

**Из локальной директории:**

```bash
helm plugin install /path/to/plugin
```

### Список plugins

```bash
helm plugin list
helm plugin ls
```

### Обновление plugin

```bash
helm plugin update <PLUGIN_NAME>
```

### Удаление plugin

```bash
helm plugin uninstall <PLUGIN_NAME>
```

### Популярные plugins

**helm-diff:**

```bash
helm plugin install https://github.com/databus23/helm-diff
helm diff upgrade nginx bitnami/nginx -f new-values.yaml
```

**helm-secrets:**

```bash
helm plugin install https://github.com/jkroepke/helm-secrets
helm secrets install nginx bitnami/nginx -f secrets.yaml
```

**helm-push:**

```bash
helm plugin install https://github.com/chartmuseum/helm-push
helm push chart.tgz chartmuseum
```

---

## Chart создание

### Создание нового chart

```bash
helm create <CHART_NAME>
helm create mychart
```

Создает структуру директорий:

```
mychart/
  Chart.yaml
  values.yaml
  charts/
  templates/
    deployment.yaml
    service.yaml
    ingress.yaml
    ...
```

### Packaging chart

```bash
helm package <CHART_DIR>
helm package ./mychart
```

**С версией:**

```bash
helm package ./mychart --version 1.0.0
```

**С dependency update:**

```bash
helm package ./mychart --dependency-update
```

### Lint chart

```bash
helm lint <CHART_DIR>
helm lint ./mychart
```

**Strict mode:**

```bash
helm lint ./mychart --strict
```

**С values:**

```bash
helm lint ./mychart -f values.yaml
```

---

## Dependency управление

### Добавление dependencies

**В Chart.yaml:**

```yaml
dependencies:
- name: postgresql
  version: 12.x.x
  repository: https://charts.bitnami.com/bitnami
- name: redis
  version: 17.x.x
  repository: https://charts.bitnami.com/bitnami
  condition: redis.enabled
```

### Обновление dependencies

```bash
helm dependency update <CHART_DIR>
helm dependency update ./mychart
```

Загрузка dependencies в `charts/` директорию.

**Build dependencies:**

```bash
helm dependency build <CHART_DIR>
```

Rebuild charts/ из Chart.lock.

### Список dependencies

```bash
helm dependency list <CHART_DIR>
```

---

## Registry операции (OCI)

### Login к registry

```bash
helm registry login <REGISTRY>
helm registry login registry.example.com --username admin
```

### Logout из registry

```bash
helm registry logout <REGISTRY>
```

### Push chart в OCI registry

```bash
helm push <CHART_PACKAGE> oci://<REGISTRY>/<PATH>
helm push mychart-1.0.0.tgz oci://registry.example.com/charts
```

### Pull chart из OCI registry

```bash
helm pull oci://<REGISTRY>/<PATH>/<CHART>
helm pull oci://registry.example.com/charts/mychart --version 1.0.0
```

### Install из OCI registry

```bash
helm install <RELEASE_NAME> oci://<REGISTRY>/<PATH>/<CHART>
helm install nginx oci://registry.example.com/charts/nginx --version 1.0.0
```

---

## Environment переменные

### HELM_HOME

```bash
export HELM_HOME=/custom/path
```

Deprecated в Helm 3, использовать XDG directories.

### XDG directories

```bash
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
```

Helm 3 использует:
- Config: `$XDG_CONFIG_HOME/helm`
- Cache: `$XDG_CACHE_HOME/helm`
- Data: `$XDG_DATA_HOME/helm`

### KUBECONFIG

```bash
export KUBECONFIG=/path/to/kubeconfig
```

### HELM_NAMESPACE

```bash
export HELM_NAMESPACE=production
```

Default namespace для Helm операций.

### HELM_DRIVER

```bash
export HELM_DRIVER=secret
export HELM_DRIVER=configmap
export HELM_DRIVER=memory
```

Backend для хранения release information.

---

## Completion

### Bash completion

```bash
helm completion bash > /etc/bash_completion.d/helm
source /etc/bash_completion.d/helm
```

### Zsh completion

```bash
helm completion zsh > "${fpath[1]}/_helm"
```

### Fish completion

```bash
helm completion fish > ~/.config/fish/completions/helm.fish
```

---

## Troubleshooting

### Debug mode

```bash
helm install nginx bitnami/nginx --debug --dry-run
helm upgrade nginx bitnami/nginx --debug
```

### Verbose output

```bash
helm list -v 9
```

Verbosity levels: 0-9 (9 максимальный).

### Проверка values

```bash
helm get values nginx --all
helm template nginx bitnami/nginx -f values.yaml --debug
```

### Release проблемы

**Застрявший release:**

```bash
helm list --pending
helm rollback nginx
```

**Failed release:**

```bash
helm list --failed
helm uninstall nginx
```

### Repository проблемы

**Обновление кэша:**

```bash
helm repo update
```

**Принудительное обновление:**

```bash
helm repo remove <REPO>
helm repo add <REPO> <URL>
helm repo update
```

### Template проблемы

**Валидация syntax:**

```bash
helm lint ./mychart
helm template nginx ./mychart --validate
```

**Debug template rendering:**

```bash
helm template nginx ./mychart --debug > /tmp/manifests.yaml
```

---

## Best Practices

**Использование версий:**

```bash
helm install nginx bitnami/nginx --version 15.0.0
```

Фиксация версии chart для воспроизводимости.

**Values файлы для окружений:**

```
values-dev.yaml
values-staging.yaml
values-prod.yaml
```

**Atomic upgrades:**

```bash
helm upgrade nginx bitnami/nginx --atomic --timeout 10m
```

**Dry run перед применением:**

```bash
helm upgrade nginx bitnami/nginx -f values.yaml --dry-run --debug
```

**Backup перед upgrade:**

```bash
helm get values nginx -o yaml > values-backup.yaml
helm get manifest nginx > manifest-backup.yaml
```

**История ограничений:**

```yaml
# Chart.yaml
annotations:
  "helm.sh/max-history": "5"
```