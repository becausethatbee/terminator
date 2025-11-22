# CRD и Kubernetes Operators

Разработка Custom Resource Definitions и операторов для расширения Kubernetes API. Практическая реализация Database CRD с контроллером и production-grade оператором через kopf framework.

## Предварительные требования

- Kubernetes кластер >= 1.28
- kubectl с настроенным kubeconfig
- Python 3.10+ с venv
- SSH доступ к control plane ноде

---

## Custom Resource Definition (CRD)

### Архитектурный паттерн CRD для баз данных

CRD предоставляет высокоуровневую абстракцию, Operator управляет низкоуровневой реализацией:
```
Database CR (spec.version, spec.size)
    ↓
Operator reconciliation loop
    ↓
├─ StatefulSet (database pods)
├─ Service (stable endpoint)
├─ PersistentVolumeClaim (storage)
├─ ConfigMap (database configuration)
├─ Secret (credentials)
├─ CronJob (automated backups)
└─ Update Database.status.phase
```

Production операторы PostgreSQL/MySQL используют эту архитектуру. StatefulSet обеспечивает stable network identity и ordered deployment, Operator добавляет domain-specific логику (failover, backup/restore, replication setup).

### Создание Database CRD

Структура проекта:
```bash
mkdir -p ~/k8s-crd-lab/{manifests,controller}
cd ~/k8s-crd-lab
```

Манифест CRD с валидацией:
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.example.com
spec:
  group: example.com
  names:
    kind: Database
    listKind: DatabaseList
    plural: databases
    singular: database
    shortNames:
    - db
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - version
            - size
            properties:
              version:
                type: string
                description: "Database version"
              size:
                type: string
                description: "Storage size"
                pattern: '^[0-9]+[a-zA-Z]+$'
          status:
            type: object
            properties:
              phase:
                type: string
                description: "Current state of database"
                enum:
                - Creating
                - Running
                - Failed
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Size
      type: string
      jsonPath: .spec.size
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
```

Ключевые элементы:
- `subresources.status` - независимое обновление статуса
- `pattern` для size - валидация формата (10Gi, 5Gi)
- `enum` для phase - ограничение допустимых значений
- `additionalPrinterColumns` - вывод в kubectl get

Регистрация CRD:
```bash
kubectl apply -f manifests/database-crd.yaml
kubectl get crd databases.example.com
```

Проверка API:
```bash
kubectl api-resources | grep database
```

### Создание экземпляра Database

Манифест Database объекта:
```yaml
apiVersion: example.com/v1
kind: Database
metadata:
  name: postgres-prod
  namespace: default
spec:
  version: "15.3"
  size: "5Gi"
```

Применение:
```bash
kubectl apply -f manifests/database-instance.yaml
kubectl get databases
```

Вывод показывает пустое PHASE - контроллер еще не обновил статус.

---

## Python контроллер

### Установка зависимостей

Создание изолированного окружения:
```bash
python3 -m venv ~/controller-venv
source ~/controller-venv/bin/activate
pip install kubernetes
```

### Реализация контроллера

Контроллер с watch и status update:
```python
#!/usr/bin/env python3
import time
from kubernetes import client, config, watch

GROUP = "example.com"
VERSION = "v1"
PLURAL = "databases"

def update_status(api, name, namespace, phase):
    """Update Database status.phase"""
    body = {
        "status": {
            "phase": phase
        }
    }
    try:
        api.patch_namespaced_custom_object_status(
            group=GROUP,
            version=VERSION,
            namespace=namespace,
            plural=PLURAL,
            name=name,
            body=body
        )
        print(f"Updated {namespace}/{name} status to {phase}")
    except Exception as e:
        print(f"Error updating status: {e}")

def main():
    config.load_kube_config()
    api = client.CustomObjectsApi()
    
    print(f"Starting Database controller, watching {GROUP}/{VERSION}/{PLURAL}")
    
    w = watch.Watch()
    for event in w.stream(api.list_cluster_custom_object, 
                          group=GROUP, version=VERSION, plural=PLURAL):
        obj = event['object']
        event_type = event['type']
        name = obj['metadata']['name']
        namespace = obj['metadata']['namespace']
        
        if event_type == "ADDED":
            status = obj.get('status', {})
            current_phase = status.get('phase', '')
            
            if not current_phase:
                print(f"New Database detected: {namespace}/{name}")
                print(f"Waiting 10 seconds before marking as Running...")
                time.sleep(10)
                update_status(api, name, namespace, "Running")

if __name__ == '__main__':
    main()
```

Контроллер реализует reconciliation loop pattern:
- Watch API для Database объектов
- Обработка ADDED событий
- Delay 10 секунд (симуляция provisioning)
- Update status через status subresource

Запуск контроллера:
```bash
chmod +x controller/database_controller.py
python3 controller/database_controller.py
```

Проверка результата:
```bash
kubectl get databases
kubectl get database postgres-prod -o yaml | grep -A 5 "^status:"
```

Status.phase обновляется на Running через 10 секунд после создания объекта.

### Тестирование множественных объектов

Создание нескольких Database экземпляров:
```yaml
apiVersion: example.com/v1
kind: Database
metadata:
  name: mysql-dev
  namespace: default
spec:
  version: "8.0"
  size: "3Gi"
---
apiVersion: example.com/v1
kind: Database
metadata:
  name: postgres-stage
  namespace: default
spec:
  version: "14.2"
  size: "7Gi"
```

Применение и проверка:
```bash
kubectl apply -f manifests/database-instances.yaml
kubectl get databases
```

Контроллер обрабатывает каждый объект независимо, все переходят в Running.

---

## Kubernetes Operator через kopf

### Установка kopf framework
```bash
source ~/controller-venv/bin/activate
pip install kopf
```

kopf (Kubernetes Operator Pythonic Framework) предоставляет:
- Декларативное API через decorators
- Автоматическую обработку events
- Встроенные retries и error handling
- Finalizers для cleanup logic

### Реализация Operator

Operator с create/delete handlers:
```python
#!/usr/bin/env python3
import kopf
from kubernetes import client, config

config.load_kube_config()
v1 = client.CoreV1Api()

@kopf.on.create('example.com', 'v1', 'databases')
def create_fn(spec, name, namespace, logger, **kwargs):
    """Create Pod when Database object is created"""
    logger.info(f"Creating Pod for Database {namespace}/{name}")
    
    version = spec.get('version', 'latest')
    size = spec.get('size', '1Gi')
    
    pod = client.V1Pod(
        metadata=client.V1ObjectMeta(
            name=f"{name}-pod",
            namespace=namespace,
            labels={
                "app": "database",
                "database-name": name
            }
        ),
        spec=client.V1PodSpec(
            containers=[
                client.V1Container(
                    name="database",
                    image=f"postgres:{version}" if "postgres" in name else f"mysql:{version}",
                    env=[
                        client.V1EnvVar(name="POSTGRES_PASSWORD", value="example") if "postgres" in name 
                        else client.V1EnvVar(name="MYSQL_ROOT_PASSWORD", value="example"),
                    ],
                    resources=client.V1ResourceRequirements(
                        requests={"memory": "256Mi", "cpu": "100m"},
                        limits={"memory": "512Mi", "cpu": "500m"}
                    )
                )
            ],
            restart_policy="Always"
        )
    )
    
    try:
        v1.create_namespaced_pod(namespace=namespace, body=pod)
        logger.info(f"Pod {name}-pod created successfully")
        return {'pod-name': f"{name}-pod"}
    except Exception as e:
        logger.error(f"Failed to create Pod: {e}")
        raise

@kopf.on.delete('example.com', 'v1', 'databases')
def delete_fn(spec, name, namespace, logger, **kwargs):
    """Delete Pod when Database object is deleted"""
    pod_name = f"{name}-pod"
    logger.info(f"Deleting Pod {namespace}/{pod_name}")
    
    try:
        v1.delete_namespaced_pod(
            name=pod_name,
            namespace=namespace,
            body=client.V1DeleteOptions()
        )
        logger.info(f"Pod {pod_name} deleted successfully")
    except client.exceptions.ApiException as e:
        if e.status == 404:
            logger.info(f"Pod {pod_name} not found, nothing to delete")
        else:
            logger.error(f"Failed to delete Pod: {e}")
            raise
```

Operator автоматически:
- Создает Pod при создании Database
- Удаляет Pod при удалении Database
- Добавляет finalizers для гарантии cleanup
- Обрабатывает ошибки и retries

### Запуск и тестирование Operator

Запуск operator:
```bash
chmod +x controller/database_operator.py
kopf run controller/database_operator.py --verbose
```

Создание Database объекта:
```yaml
apiVersion: example.com/v1
kind: Database
metadata:
  name: postgres-test
  namespace: default
spec:
  version: "15.3"
  size: "2Gi"
```

Применение и проверка:
```bash
kubectl apply -f /tmp/test-db.yaml
kubectl get pods
kubectl get database postgres-test
```

Operator создает Pod postgres-test-pod. Проверка lifecycle:
```bash
kubectl delete database postgres-test
kubectl get pods
```

Pod автоматически удаляется вместе с Database объектом.

### Тестирование множественных объектов

Создание трех Database экземпляров:
```yaml
apiVersion: example.com/v1
kind: Database
metadata:
  name: postgres-prod
spec:
  version: "15.3"
  size: "5Gi"
---
apiVersion: example.com/v1
kind: Database
metadata:
  name: mysql-dev
spec:
  version: "8.0"
  size: "3Gi"
---
apiVersion: example.com/v1
kind: Database
metadata:
  name: postgres-stage
spec:
  version: "14.2"
  size: "4Gi"
```

Применение:
```bash
kubectl apply -f /tmp/multiple-databases.yaml
kubectl get databases
kubectl get pods
```

Operator создает три соответствующих Pod. Pods распределяются по worker нодам через scheduler.

---

## Каталоги готовых операторов

### OperatorHub.io

Главный каталог операторов CNCF/Red Hat. Production-ready операторы:

**Database операторы:**
- PostgreSQL Operator (Zalando, Crunchy Data)
- MySQL Operator (Oracle, Percona, Vitess)
- MongoDB Operator
- Redis Operator
- CockroachDB Operator

**Infrastructure операторы:**
- prometheus-operator (monitoring stack)
- rook-operator (Ceph distributed storage)
- cert-manager (TLS certificates automation)
- istio-operator (service mesh)
- argocd-operator (GitOps deployments)

URL: https://operatorhub.io

### Artifact Hub

Unified каталог для Helm charts и Kubernetes operators. Поддерживает фильтрацию по:
- Operator SDK type
- Lifecycle capabilities (Basic Install, Seamless Upgrades, Full Lifecycle)
- Repository источник

URL: https://artifacthub.io

### GitHub Awesome Operators

Кураторский список операторов с категоризацией:
- Application operators
- Database operators
- Monitoring operators
- Networking operators
- Storage operators

URL: https://github.com/operator-framework/awesome-operators



## Troubleshooting


### CRD validation errors

**Симптомы:**
- kubectl apply возвращает validation error
- Объект не создается

**Ошибка:**
```
error: error validating "database.yaml": error validating data: 
ValidationError(Database.spec.size): invalid type for com.example.v1.Database.spec.size: 
got "string", expected "integer"
```

**Причина:** Несоответствие типа данных в spec и schema openAPIV3Schema.

**Решение:**

Проверка CRD schema:
```bash
kubectl get crd databases.example.com -o yaml | grep -A 20 "openAPIV3Schema"
```

Корректировка типа в CRD или манифесте объекта.

**Проверка:**
```bash
kubectl apply -f manifests/database-instance.yaml --dry-run=client
```

### Controller не обновляет status

**Симптомы:**
- Database создан, но PHASE остается пустым
- Контроллер работает без ошибок

**Причина:** Отсутствует subresources.status в CRD спецификации.

**Решение:**

Проверка CRD:
```bash
kubectl get crd databases.example.com -o jsonpath='{.spec.versions[0].subresources}'
```

Должно вернуть `{"status":{}}`. Если пусто - добавить в CRD:
```yaml
spec:
  versions:
  - name: v1
    subresources:
      status: {}
```

Обновление CRD:
```bash
kubectl apply -f manifests/database-crd.yaml
```

**Проверка:**
```bash
kubectl get database postgres-prod -o yaml | grep -A 3 "^status:"
```

### Operator Pod creation failed

**Симптомы:**
- Operator логи показывают успех
- Pod не создается или stuck в Pending

**Ошибка:**
```
0/8 nodes are available: 8 Insufficient memory
```

**Причина:** Недостаточно ресурсов на worker нодах для requests.

**Решение:**

Проверка доступных ресурсов:
```bash
kubectl describe nodes | grep -A 5 "Allocated resources"
```

Уменьшение requests в operator коде:
```python
resources=client.V1ResourceRequirements(
    requests={"memory": "128Mi", "cpu": "50m"},
    limits={"memory": "256Mi", "cpu": "200m"}
)
```

**Проверка:**
```bash
kubectl get pods -o wide
```

### kopf finalizer blocking deletion

**Симптомы:**
- kubectl delete database зависает
- Объект остается в Terminating

**Причина:** kopf добавляет finalizer, но delete handler завершился с ошибкой.

**Решение:**

Проверка finalizers:
```bash
kubectl get database <NAME> -o jsonpath='{.metadata.finalizers}'
```

Принудительное удаление finalizer:
```bash
kubectl patch database <NAME> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

**Проверка:**
```bash
kubectl get databases
```

Объект должен быть удален.

### Multiple controllers conflict

**Симптомы:**
- Status.phase мигает между значениями
- Логи показывают concurrent updates

**Причина:** Два контроллера одновременно обновляют один объект.

**Решение:**

Проверка запущенных контроллеров:
```bash
ps aux | grep database_controller
ps aux | grep kopf
```

Остановка лишних процессов:
```bash
pkill -f database_controller
```

Использование leader election для production:
```python
@kopf.on.startup()
def configure(settings: kopf.OperatorSettings, **_):
    settings.peering.name = "database-operator"
    settings.peering.mandatory = True
```

---

## Best Practices

**CRD Design:**
- Использовать semver для версий API (v1, v1alpha1, v1beta1)
- Определять required поля в schema
- Добавлять validation patterns для критичных значений
- Использовать enum для ограниченных наборов значений
- Включать additionalPrinterColumns для удобства kubectl get

**Controller Development:**
- Реализовать идемпотентность reconciliation loop
- Использовать exponential backoff для retries
- Добавлять structured logging с context
- Обрабатывать partial failures
- Использовать client-go workqueue для scalability

**Operator Patterns:**
- Использовать finalizers для guaranteed cleanup
- Implement status conditions для detailed state
- Добавлять events для observability
- Использовать owner references для garbage collection
- Версионировать operator совместно с CRD

**Testing:**
- Unit тесты для business logic
- Integration тесты с envtest
- E2E тесты на real кластере
- Chaos testing для resilience
- Performance тесты для scalability

**Security:**
- Минимальные RBAC права
- Не хранить credentials в code
- Использовать ServiceAccount tokens
- Валидировать user input
- Audit logging для sensitive operations

---

## Полезные команды

### CRD Management
```bash
# Список всех CRD
kubectl get crd

# Детальная информация о CRD
kubectl describe crd databases.example.com

# Schema CRD
kubectl get crd databases.example.com -o yaml

# Удаление CRD (удаляет все объекты!)
kubectl delete crd databases.example.com

# Версии API
kubectl api-resources | grep database
```

### Custom Resources
```bash
# Создание объекта
kubectl apply -f database.yaml

# Список объектов
kubectl get databases
kubectl get db

# Детальная информация
kubectl describe database postgres-prod

# YAML представление
kubectl get database postgres-prod -o yaml

# Извлечение spec
kubectl get database postgres-prod -o jsonpath='{.spec}'

# Watch изменений
kubectl get databases -w

# Удаление объекта
kubectl delete database postgres-prod
```

### Debugging
```bash
# События связанные с объектом
kubectl get events --field-selector involvedObject.name=postgres-prod

# Логи контроллера
kubectl logs -f <CONTROLLER_POD>

# Проверка RBAC
kubectl auth can-i create databases.example.com

# API server логи для CRD
kubectl logs -n kube-system kube-apiserver-<NODE>
```

---

## Архитектура решения
```
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes API Server                                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐         ┌────────────────┐                │
│  │ Built-in     │         │ Custom         │                │
│  │ Resources    │         │ Resources      │                │
│  │              │         │                │                │
│  │ - Pod        │         │ - Database     │                │
│  │ - Service    │         │   (CRD)        │                │
│  │ - Deployment │         │                │                │
│  └──────────────┘         └────────────────┘                │
│                                   │                         │
└───────────────────────────────────┼─────────────────────────┘
                                    │
                                    │ Watch
                                    │
                      ┌─────────────▼──────────────┐
                      │ Operator / Controller      │
                      ├────────────────────────────┤
                      │                            │
                      │ Reconciliation Loop:       │
                      │ 1. Watch Database objects  │
                      │ 2. Compare desired state   │
                      │ 3. Create/Update resources │
                      │ 4. Update status           │
                      │                            │
                      └─────────────┬──────────────┘
                                    │
                      ┌─────────────▼──────────────┐
                      │ Managed Resources          │
                      ├────────────────────────────┤
                      │                            │
                      │ - StatefulSet              │
                      │ - Service                  │
                      │ - PersistentVolumeClaim    │
                      │ - ConfigMap                │
                      │ - Secret                   │
                      │                            │
                      └────────────────────────────┘
```

CRD расширяет Kubernetes API новыми типами ресурсов. Operator реализует domain-specific логику управления этими ресурсами через reconciliation loop. Managed resources создаются и управляются оператором для достижения desired state, определенного в CRD спецификации.
