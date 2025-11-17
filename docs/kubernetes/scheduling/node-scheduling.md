# Node Scheduling в Kubernetes

Механизмы управления размещением подов на нодах кластера: NodeSelector, Node Affinity, Pod Affinity/Anti-Affinity, Taints и Tolerations.

## Предварительные требования

- Kubernetes кластер с минимум 3 нодами
- kubectl версии 1.28+
- Базовое понимание архитектуры Kubernetes

---

## Сравнение механизмов планирования

| Механизм | Тип ограничения | Уровень | Гибкость | Использование |
|----------|----------------|---------|----------|---------------|
| NodeSelector | Жесткое | Нода | Низкая | Простой выбор ноды по метке |
| Node Affinity | Жесткое/Мягкое | Нода | Высокая | Сложные условия выбора ноды |
| Pod Affinity | Жесткое/Мягкое | Под → Нода | Высокая | Размещение рядом с другими подами |
| Pod Anti-Affinity | Жесткое/Мягкое | Под → Нода | Высокая | Размещение отдельно от других подов |
| Taints/Tolerations | Жесткое | Нода | Средняя | Изоляция нод, резервирование |

### Типы правил Affinity

| Тип | Описание | Поведение при невыполнении |
|-----|----------|---------------------------|
| requiredDuringSchedulingIgnoredDuringExecution | Обязательное условие | Под остается Pending |
| preferredDuringSchedulingIgnoredDuringExecution | Предпочтительное условие | Под размещается на любой ноде |

### Taint Effects

| Effect | Описание | Существующие поды |
|--------|----------|-------------------|
| NoSchedule | Новые поды не планируются | Остаются на месте |
| PreferNoSchedule | Избегать планирования (мягкое) | Остаются на месте |
| NoExecute | Новые не планируются + эвикция | Удаляются без toleration |

### Операторы matchExpressions

| Оператор | Описание | Пример |
|----------|----------|--------|
| In | Значение в списке | `disktype In [ssd, nvme]` |
| NotIn | Значение не в списке | `disktype NotIn [hdd]` |
| Exists | Ключ существует | `gpu Exists` |
| DoesNotExist | Ключ отсутствует | `spot DoesNotExist` |
| Gt | Больше (числа) | `cpu Gt 8` |
| Lt | Меньше (числа) | `memory Lt 16` |

### Приоритет применения правил

```
1. Taint на ноде → Проверка Toleration в поде
   ├─ Нет toleration → Нода исключается
   └─ Есть toleration → Продолжить

2. NodeSelector → Строгое соответствие меток
   ├─ Не совпадает → Нода исключается
   └─ Совпадает → Продолжить

3. Node Affinity (required) → Обязательное условие
   ├─ Не выполнено → Нода исключается
   └─ Выполнено → Продолжить

4. Pod Affinity/Anti-Affinity (required) → Топология
   ├─ Не выполнено → Нода исключается
   └─ Выполнено → Продолжить

5. Preferred правила → Подсчет весов
   └─ Выбор ноды с максимальным score

6. Балансировка нагрузки → Финальный выбор
```

### Комбинирование правил

| Сценарий | NodeSelector | Node Affinity | Pod Affinity | Taints | Результат |
|----------|--------------|---------------|--------------|--------|-----------|
| Простое размещение | Да | Нет | Нет | Нет | На ноде с меткой |
| Резервирование нод | Нет | Нет | Нет | Да | Только с toleration |
| High Availability | Нет | Да (preferred) | Anti-Affinity | Нет | Распределение по зонам |
| Latency optimization | Нет | Да (required) | Да (Affinity) | Нет | Рядом с зависимыми подами |
| Production isolation | Нет | Да (required) | Нет | Да | Метка + taint |

---

## NodeSelector

### Добавление метки к ноде

```bash
kubectl label nodes <NODE_NAME> role=backend
```

Проверка меток:

```bash
kubectl get nodes --show-labels | grep role
kubectl get nodes -L role
```

### Манифест пода с NodeSelector

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend-app
  labels:
    app: backend
spec:
  nodeSelector:
    role: backend
  containers:
  - name: nginx
    image: nginx:1.27.2
    ports:
    - containerPort: 80
```

NodeSelector требует точного совпадения меток. Под не будет размещен если метка отсутствует на всех нодах.

### Проверка размещения

```bash
kubectl get pod backend-app -o wide
```

### Удаление метки

```bash
kubectl label nodes <NODE_NAME> role-
```

---

## Node Affinity

### Типы Node Affinity

**requiredDuringSchedulingIgnoredDuringExecution**
- Под не запустится если условие не выполнено
- Для критичных требований

**preferredDuringSchedulingIgnoredDuringExecution**
- Под запустится на любой доступной ноде
- Для оптимизации размещения

### Добавление меток

```bash
kubectl label nodes <NODE_1> disktype=ssd
kubectl label nodes <NODE_2> disktype=hdd
```

### Манифест с Required Affinity

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-ssd-required
  labels:
    app: storage-app
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
  containers:
  - name: nginx
    image: nginx:1.27.2
    ports:
    - containerPort: 80
```

Под запустится только на нодах с `disktype=ssd`.

### Манифест с Preferred Affinity

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-hdd-preferred
  labels:
    app: storage-app
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - hdd
  containers:
  - name: nginx
    image: nginx:1.27.2
    ports:
    - containerPort: 80
```

Параметр `weight` определяет приоритет при выборе ноды (1-100).

### Комбинирование Required и Preferred

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: env
            operator: In
            values:
            - production
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```

Под обязательно размещается на production нодах, предпочтительно на тех с SSD.

---

## Pod Affinity и Anti-Affinity

### Pod Affinity

Размещает поды на нодах где уже запущены определенные поды.

### Deployment для backend

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: nginx
        image: nginx:1.27.2
        ports:
        - containerPort: 80
```

### Deployment с Affinity и Anti-Affinity

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - backend
            topologyKey: kubernetes.io/hostname
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - frontend
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:1.27.2
        ports:
        - containerPort: 80
```

Pod Affinity размещает frontend поды на нодах где есть backend поды. Pod Anti-Affinity изолирует frontend поды друг от друга.

### Параметр topologyKey

| topologyKey | Уровень | Использование |
|-------------|---------|---------------|
| kubernetes.io/hostname | Нода | Размещение на той же ноде |
| topology.kubernetes.io/zone | Зона доступности | Размещение в той же зоне |
| topology.kubernetes.io/region | Регион | Размещение в том же регионе |

### Проверка размещения

```bash
kubectl get pods -l app=backend -o wide
kubectl get pods -l app=frontend -o wide
```

---

## Taints и Tolerations

### Механизм работы

Taint на ноде отталкивает поды без соответствующей toleration. Toleration в поде позволяет игнорировать taint.

### Добавление taint к ноде

```bash
kubectl taint nodes <NODE_NAME> key=value:NoSchedule
```

Формат: `key=value:effect`

### Проверка taints

```bash
kubectl describe node <NODE_NAME> | grep -A 3 Taints
```

### Манифест пода без toleration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-no-toleration
spec:
  containers:
  - name: nginx
    image: nginx:1.27.2
    ports:
    - containerPort: 80
```

Под не может разместиться на ноде с taint.

### Манифест пода с toleration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-toleration
spec:
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
  containers:
  - name: nginx
    image: nginx:1.27.2
    ports:
    - containerPort: 80
```

Toleration должна совпадать с taint по key, value, effect.

### Оператор Equal

```yaml
tolerations:
- key: "key"
  operator: "Equal"
  value: "value"
  effect: "NoSchedule"
```

Требует точного совпадения key, value, effect.

### Оператор Exists

```yaml
tolerations:
- key: "key"
  operator: "Exists"
  effect: "NoSchedule"
```

Игнорирует value, проверяет только key и effect.

### Удаление taint

```bash
kubectl taint nodes <NODE_NAME> key=value:NoSchedule-
```

---

## Комбинированное использование

### Настройка production ноды

```bash
kubectl label nodes <NODE_NAME> env=production
kubectl taint nodes <NODE_NAME> dedicated=prod:NoSchedule
```

### Под для production

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-production
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: env
            operator: In
            values:
            - production
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "prod"
    effect: "NoSchedule"
  containers:
  - name: nginx
    image: nginx:1.27.2
    ports:
    - containerPort: 80
```

Node Affinity требует ноду с `env=production`, toleration позволяет игнорировать taint.

### Use Cases

**GPU ноды:**

```yaml
labels: hardware=gpu
taints: gpu=true:NoSchedule

tolerations:
- key: gpu
  operator: Equal
  value: "true"
  effect: NoSchedule
```

**Spot instances:**

```yaml
taints: node.kubernetes.io/spot:NoSchedule

tolerations:
- key: node.kubernetes.io/spot
  operator: Exists
  effect: NoSchedule
```

**Зоны доступности:**

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: topology.kubernetes.io/zone
          operator: In
          values:
          - <ZONE_1>
          - <ZONE_2>
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: myapp
      topologyKey: topology.kubernetes.io/zone
```

---

## Troubleshooting

### Под в статусе Pending

**Диагностика:**

```bash
kubectl describe pod <POD_NAME>
kubectl get events --sort-by='.lastTimestamp'
```

**Причины:**
- NodeSelector не находит ноду с меткой
- Required Node Affinity не выполнено
- Taint на всех подходящих нодах
- Pod Anti-Affinity конфликтует с размещением

### Ошибка: 0/3 nodes are available

Сообщение указывает на причину отказа:

```
0/3 nodes are available: 1 node(s) had untolerated taint, 
2 node(s) didn't match Pod's node affinity/selector
```

**Проверка:**

```bash
kubectl get nodes --show-labels
kubectl describe nodes | grep -A 3 Taints
```

### Под не эвиктится при NoExecute

Если под остается на ноде после добавления taint с effect NoExecute, проверьте toleration:

```bash
kubectl get pod <POD_NAME> -o yaml | grep -A 5 tolerations
```

### Pod Affinity не работает

**Причины:**
- Целевой под еще не запущен
- Неправильный labelSelector
- Неправильный topologyKey

**Проверка:**

```bash
kubectl get pods -l <LABEL> -o wide
kubectl describe pod <POD_NAME> | grep -A 10 Affinity
```

---

## Best Practices

### NodeSelector vs Node Affinity

NodeSelector для простых случаев:

```yaml
nodeSelector:
  disktype: ssd
```

Node Affinity для сложной логики:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: disktype
          operator: In
          values:
          - ssd
          - nvme
```

### Required для критичных требований

- Compliance требования
- Лицензионные ограничения
- Аппаратные зависимости

### Preferred для оптимизации

- Снижение latency
- Балансировка по зонам
- Оптимизация costs

### Taints для резервирования

Резервирование нод для специфических workloads:

```bash
kubectl taint nodes <NODE_NAME> workload=database:NoSchedule
```

### Pod Anti-Affinity для HA

Распределение реплик по нодам:

```yaml
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchLabels:
        app: myapp
    topologyKey: kubernetes.io/hostname
```

Распределение по зонам доступности:

```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchLabels:
          app: myapp
      topologyKey: topology.kubernetes.io/zone
```

### Weight в Preferred правилах

Разные веса для приоритизации:

```yaml
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 100
  preference:
    matchExpressions:
    - key: disktype
      operator: In
      values:
      - ssd
- weight: 50
  preference:
    matchExpressions:
    - key: zone
      operator: In
      values:
      - <ZONE_1>
```

### Ограничение ресурсов

Комбинируйте scheduling с resource requests/limits:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node.kubernetes.io/instance-type
            operator: In
            values:
            - m5.2xlarge
  containers:
  - name: app
    resources:
      requests:
        memory: "4Gi"
        cpu: "2000m"
      limits:
        memory: "8Gi"
        cpu: "4000m"
```

---

## Полезные команды

### Управление метками

```bash
kubectl label nodes <NODE_NAME> key=value
kubectl label nodes <NODE_NAME> key-
kubectl get nodes --show-labels
kubectl get nodes -L key1,key2
```

### Управление taints

```bash
kubectl taint nodes <NODE_NAME> key=value:NoSchedule
kubectl taint nodes <NODE_NAME> key=value:NoSchedule-
kubectl describe node <NODE_NAME> | grep Taints
```

### Проверка размещения подов

```bash
kubectl get pods -o wide
kubectl get pods -l app=myapp -o wide
kubectl describe pod <POD_NAME>
```

### Фильтрация нод

```bash
kubectl get nodes -l disktype=ssd
kubectl get nodes -l '!disktype'
kubectl get nodes --selector='env=production,disktype=ssd'
```

### События и отладка

```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl describe pod <POD_NAME> | grep -A 10 Events
kubectl logs <POD_NAME>
```

### Информация о scheduler

```bash
kubectl get events -n kube-system --field-selector involvedObject.name=kube-scheduler
kubectl logs -n kube-system -l component=kube-scheduler
```

