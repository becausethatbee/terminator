# Kubernetes RBAC и Network Policies

Полный цикл настройки управления доступом в Kubernetes: Role-based Access Control (RBAC), ServiceAccount, Network Policies для изоляции сетевого трафика.

---

## Предварительные требования

Kubernetes кластер версии 1.19+. Для Network Policies обязателен сетевой плагин (CNI), поддерживающий сетевые политики:

| CNI | Поддержка NetworkPolicy | Тип | Статус |
|-----|------------------------|------|--------|
| Calico | Да | Полнофункциональный | Production-ready |
| Cilium | Да | eBPF-based | Production-ready |
| Weave | Да | Встроенный | Поддерживается |
| Flannel | Нет | Базовый | Не поддерживает |
| Docker Bridge | Нет | По умолчанию | Не поддерживает |

### Установка Calico

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml
```

Проверка установки:

```bash
kubectl get pods -n kube-system | grep calico
```

Вывод должен содержать calico-node и calico-kube-controllers в статусе Running.

Альтернатива — использование Cilium:

```bash
helm repo add cilium https://helm.cilium.io
helm install cilium cilium/cilium --namespace kube-system
```

---

## Задание 1: RBAC для управления доступом

### Создание Role с правами на чтение подов

```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods --namespace=default
```

Создаёт Role с правами на чтение (get, list, watch) подов в namespace default.

Проверка роли:

```bash
kubectl describe role pod-reader -n default
```

Отображает детали роли, включая PolicyRule с разрешёнными операциями и ресурсами.

Вывод содержит PolicyRule с правами get, list, watch на ресурс pods.

### Создание ServiceAccount и RoleBinding

```bash
kubectl create serviceaccount user1 -n default
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=default:user1 --namespace=default
```

Создаёт ServiceAccount user1 и привязывает роль pod-reader к этому аккаунту через RoleBinding.

Проверка привязки:

```bash
kubectl describe rolebinding pod-reader-binding -n default
```

### Валидация прав доступа

Проверка разрешённых операций:

```bash
kubectl auth can-i get pods --as=system:serviceaccount:default:user1 -n default
kubectl auth can-i list pods --as=system:serviceaccount:default:user1 -n default
kubectl auth can-i watch pods --as=system:serviceaccount:default:user1 -n default
```

Проверяет разрешённые операции (get, list, watch) для ServiceAccount user1. Все команды должны вернуть `yes`.

Проверка запрещённых операций:

```bash
kubectl auth can-i create pods --as=system:serviceaccount:default:user1 -n default
kubectl auth can-i delete pods --as=system:serviceaccount:default:user1 -n default
```

Проверяет запрещённые операции (create, delete) для ServiceAccount user1. Обе команды должны вернуть `no`.

### Расширение прав роли

```bash
kubectl delete role pod-reader -n default
kubectl create role pod-reader --verb=get,list,watch --resource=pods,services --namespace=default
```

Удаляет старую роль и создаёт новую версию с расширенными правами: добавляются права на services.

Валидация новых прав:

```bash
kubectl auth can-i get services --as=system:serviceaccount:default:user1 -n default
kubectl auth can-i list services --as=system:serviceaccount:default:user1 -n default
```

Обе команды должны вернуть `yes`.

---

## Задание 2: Работа с ServiceAccount

### Создание ServiceAccount

```bash
kubectl create serviceaccount app-account -n default
```

Создаёт ServiceAccount app-account для приложения в namespace default.

### Создание Role и RoleBinding для работы с ConfigMap

```bash
kubectl create role configmap-manager --verb=create,delete --resource=configmaps --namespace=default
kubectl create rolebinding configmap-manager-binding --role=configmap-manager --serviceaccount=default:app-account --namespace=default
```

Создаёт Role с правами на create и delete ConfigMaps, затем привязывает к ServiceAccount app-account.

Проверка привязки:

```bash
kubectl describe rolebinding configmap-manager-binding -n default
```

### Создание Deployment с использованием ServiceAccount

Создайте файл deployment-app.yaml:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      serviceAccountName: app-account
      containers:
      - name: app
        image: nginx:latest
        command: ["sleep", "3600"]
```

Развёртывание:

```bash
kubectl apply -f deployment-app.yaml
```

Развёртывает Deployment с ServiceAccount app-account.

Проверка пода:

```bash
kubectl get pods -n default -l app=test-app
```

### Валидация прав ServiceAccount

Права на ConfigMap (разрешено):

```bash
kubectl auth can-i create configmaps --as=system:serviceaccount:default:app-account -n default
kubectl auth can-i delete configmaps --as=system:serviceaccount:default:app-account -n default
```

Обе команды должны вернуть `yes`.

Права на другие ресурсы (запрещено):

```bash
kubectl auth can-i get pods --as=system:serviceaccount:default:app-account -n default
kubectl auth can-i list services --as=system:serviceaccount:default:app-account -n default
```

Обе команды должны вернуть `no`.

### Проверка через Kubernetes API

Вход в контейнер пода:

```bash
POD_NAME=$(kubectl get pods -l app=test-app -n default -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD_NAME -n default -- sh
```

Внутри контейнера проверка доступа к ConfigMap (разрешено):

```bash
curl -s -X POST https://kubernetes.default.svc/api/v1/namespaces/default/configmaps \
  -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
  -H "Content-Type: application/json" \
  -d '{"apiVersion":"v1","kind":"ConfigMap","metadata":{"name":"test-cm"}}' \
  -k | grep -E '"name"|"status"'
```

Вывод должен содержать `"name":"test-cm"`.

Попытка доступа к подам (запрещено):

```bash
curl -s https://kubernetes.default.svc/api/v1/namespaces/default/pods \
  -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
  -k | grep "Forbidden"
```

Вывод должен содержать `Forbidden`.

---

## Задание 3: Network Policies

### Предварительная подготовка

Network Policy требует установленного CNI плагина с поддержкой сетевых политик (см. раздел Предварительные требования).

### Создание подов с labels

Создайте файл pods-netpol.yaml:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: default
  labels:
    app: app
spec:
  containers:
  - name: app
    image: nginx:latest
    command: ["sleep", "3600"]

---
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
  namespace: default
  labels:
    app: db
spec:
  containers:
  - name: db
    image: nginx:latest
    command: ["sleep", "3600"]
```

Развёртывание:

```bash
kubectl apply -f pods-netpol.yaml
```

Создаёт два пода: app-pod и db-pod с соответствующими labels.

Проверка:

```bash
kubectl get pods -n default -L app
```

Отображает созданные поды с их labels в колонке APP.

### Создание Network Policy для Ingress

Создайте файл network-policy-db.yaml:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-ingress-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: app
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: app
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

Применение политики:

```bash
kubectl apply -f network-policy-db.yaml
```

Применяет Network Policy к подам с label app=db.

Проверка:

```bash
kubectl describe networkpolicy db-ingress-policy -n default
```

Отображает детали политики: разрешённые входящие и исходящие соединения.

### Валидация доступа

```bash
DB_POD_IP=$(kubectl get pod db-pod -n default -o jsonpath='{.status.podIP}')
echo "DB Pod IP: $DB_POD_IP"
```

Получает IP адрес пода db-pod и сохраняет в переменную для использования в тестах доступа.

Тест доступа из app-pod (разрешено):

```bash
kubectl exec -it app-pod -n default -- sh -c "curl -v http://$DB_POD_IP 2>&1 | head -10"
```

Устанавливает соединение из app-pod к db-pod для проверки разрешённого трафика.

Результат: соединение устанавливается (Connection refused вызван тем, что контейнер в режиме sleep).

Тест доступа из другого пода без label (запрещено):

```bash
kubectl run test-pod --image=nginx:latest -n default -- sleep 3600
kubectl exec -it test-pod -n default -- sh -c "timeout 5 curl -v http://$DB_POD_IP 2>&1 || echo 'Blocked or timeout'"
```

Создаёт под без требуемого label и пытается подключиться к db-pod. Network Policy должна заблокировать соединение.

---

## Задание 4: ClusterRole и ClusterRoleBinding

### Создание ClusterRole для просмотра подов

```bash
kubectl create clusterrole pod-viewer --verb=get,list,watch --resource=pods
```

Создаёт ClusterRole с правами на чтение подов во всех namespaces.

Проверка:

```bash
kubectl describe clusterrole pod-viewer
```

### Создание ServiceAccount и ClusterRoleBinding

```bash
kubectl create serviceaccount admin-user -n default
kubectl create clusterrolebinding pod-viewer-binding --clusterrole=pod-viewer --serviceaccount=default:admin-user
```

Создаёт ServiceAccount и привязывает ClusterRole pod-viewer для доступа ко всему кластеру.

Проверка:

```bash
kubectl describe clusterrolebinding pod-viewer-binding
```

### Валидация доступа ко всем namespace

```bash
kubectl auth can-i list pods --as=system:serviceaccount:default:admin-user
kubectl auth can-i list pods --as=system:serviceaccount:default:admin-user -n kube-system
```

Проверяет доступ admin-user к подам в default и kube-system namespaces. Обе команды должны вернуть `yes` (доступ ко всему кластеру).

### Ограничение прав до одного namespace

```bash
kubectl delete clusterrolebinding pod-viewer-binding
```

Удаляет привязку ClusterRole для подготовки к созданию Role с ограниченными правами.

Создание namespace и Role:

```bash
kubectl create namespace development
kubectl create role pod-viewer --verb=get,list,watch --resource=pods -n development
```

Создаёт namespace development и Role с правами на чтение подов только в этом namespace.

Создание RoleBinding в namespace development:

```bash
kubectl create rolebinding pod-viewer-binding --role=pod-viewer --serviceaccount=default:admin-user -n development
```

Валидация прав:

```bash
kubectl auth can-i list pods --as=system:serviceaccount:default:admin-user -n development
kubectl auth can-i list pods --as=system:serviceaccount:default:admin-user -n default
```

Первая команда должна вернуть `yes`, вторая — `no`.

---

## Задание 5: Полный цикл настройки безопасности

### Архитектура приложения

Трёхуровневое приложение с минимально необходимыми правами для каждого уровня:

| Компонент | ServiceAccount | Права | Сетевой доступ |
|-----------|----------------|-------|----------------|
| Frontend | frontend-sa | Нет | К backend |
| Backend | backend-sa | ConfigMap | К database |
| Database | database-sa | Нет | Входящий от backend |

### Создание ServiceAccounts

```bash
kubectl create serviceaccount frontend-sa -n default
kubectl create serviceaccount backend-sa -n default
kubectl create serviceaccount database-sa -n default
```

Создаёт три ServiceAccounts для каждого компонента приложения.

### Создание Roles

```bash
kubectl create role backend-role --verb=get,list --resource=configmaps -n default
```

Создаёт Role backend-role с правами get и list на ConfigMaps.

Роли для frontend и database (пустые). Создайте файл roles-task5.yaml:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: frontend-role
  namespace: default
rules: []

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: database-role
  namespace: default
rules: []
```

Применение:

```bash
kubectl apply -f roles-task5.yaml
```

Создаёт две пустые роли (без прав) для frontend и database компонентов.

### Создание RoleBindings

```bash
kubectl create rolebinding frontend-binding --role=frontend-role --serviceaccount=default:frontend-sa -n default
kubectl create rolebinding backend-binding --role=backend-role --serviceaccount=default:backend-sa -n default
kubectl create rolebinding database-binding --role=database-role --serviceaccount=default:database-sa -n default
```

Привязывает каждую роль к соответствующему ServiceAccount.

### Развёртывание приложения

Создайте файл app-deployment-task5.yaml:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod
  namespace: default
  labels:
    app: frontend
spec:
  serviceAccountName: frontend-sa
  containers:
  - name: frontend
    image: nginx:latest
    command: ["sleep", "3600"]

---
apiVersion: v1
kind: Pod
metadata:
  name: backend-pod
  namespace: default
  labels:
    app: backend
spec:
  serviceAccountName: backend-sa
  containers:
  - name: backend
    image: nginx:latest
    command: ["sleep", "3600"]

---
apiVersion: v1
kind: Pod
metadata:
  name: database-pod
  namespace: default
  labels:
    app: database
spec:
  serviceAccountName: database-sa
  containers:
  - name: database
    image: nginx:latest
    command: ["sleep", "3600"]
```

Развёртывание:

```bash
kubectl apply -f app-deployment-task5.yaml
```

Создаёт три пода с назначенными ServiceAccounts.

Проверка:

```bash
kubectl get pods -n default -L app
```

### Создание Network Policies

Политики для разрешения доступа frontend→backend, backend→database, блокировки остального трафика.

Создайте файл netpol-task5.yaml:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

Применение:

```bash
kubectl apply -f netpol-task5.yaml
```

Применяет три Network Policies для изоляции трафика между компонентами.

### Валидация конфигурации

```bash
FRONTEND_IP=$(kubectl get pod frontend-pod -n default -o jsonpath='{.status.podIP}')
BACKEND_IP=$(kubectl get pod backend-pod -n default -o jsonpath='{.status.podIP}')
DATABASE_IP=$(kubectl get pod database-pod -n default -o jsonpath='{.status.podIP}')
```

Получает IP адреса всех трёх компонентов для использования в тестах подключения.

Тест доступа frontend → backend (разрешено):

```bash
kubectl exec -it frontend-pod -n default -- sh -c "curl -v http://$BACKEND_IP 2>&1 | head -5"
```

Проверяет разрешённое соединение между frontend и backend компонентами.

Тест доступа frontend → database (запрещено):

```bash
kubectl exec -it frontend-pod -n default -- sh -c "timeout 5 curl -v http://$DATABASE_IP 2>&1 || echo 'Blocked'"
```

Проверяет что frontend НЕ имеет доступа к database компоненту. Network Policy должна блокировать это соединение.

Тест доступа backend → database (разрешено):

```bash
kubectl exec -it backend-pod -n default -- sh -c "curl -v http://$DATABASE_IP 2>&1 | head -5"
```

Проверяет разрешённое соединение между backend и database компонентами.

Тест доступа неизвестного пода к database (запрещено):

```bash
kubectl run unknown-pod --image=nginx:latest -n default -- sleep 3600
kubectl exec -it unknown-pod -n default -- sh -c "timeout 5 curl -v http://$DATABASE_IP 2>&1 || echo 'Blocked'"
```

Создаёт под без требуемого label и пытается подключиться к database. Network Policy должна заблокировать это соединение.

---

## Troubleshooting

### Network Policy не работает

**Проверка установки CNI:**

```bash
kubectl get pods -n kube-system -l k8s-app=calico-node
```

Если нет podов, значит Calico не установлен. Установить через `kubectl apply` как описано в разделе Предварительные требования.

**Проверка на допуск трафика:**

Системные сервисы (DNS) требуют явного разрешения исходящего трафика в Network Policy. Добавить в политику:

```yaml
egress:
- to:
  - namespaceSelector: {}
  ports:
  - protocol: TCP
    port: 53
  - protocol: UDP
    port: 53
```

### ServiceAccount не имеет прав

**Проверка привязки роли:**

```bash
kubectl get rolebindings -A | grep <service-account-name>
```

**Проверка прав через auth can-i:**

```bash
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<sa-name> -n <namespace>
```

Если возвращает `no`, значит роль не привязана или не имеет необходимых разрешений.

### Токен ServiceAccount неверный

**Получение токена:**

```bash
kubectl get secret $(kubectl get secret -n default | grep <sa-name> | awk '{print $1}') -n default -o jsonpath='{.data.token}' | base64 -d
```

**Использование токена в API запросе:**

```bash
NAMESPACE=default
SA_TOKEN=$(kubectl get secret -n $NAMESPACE $(kubectl get secret -n $NAMESPACE | grep <sa-name> | awk '{print $1}') -o jsonpath='{.data.token}' | base64 -d)
curl -s https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/pods \
  -H "Authorization: Bearer $SA_TOKEN" \
  -k
```

---

## Best Practices

**Минимально необходимые права**

Создавать роли только с требуемыми глаголами и ресурсами. Использование подстановочных символов (`*`) в production запрещено.

Неправильный подход — глобальные права:

```yaml
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

Правильный подход — явное указание ресурсов:

```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
```

Принцип наименьших привилегий (Principle of Least Privilege) гарантирует что ServiceAccount имеет только необходимый доступ.

**Network Policy по умолчанию deny**

Применять явное разрешение трафика вместо блокировок. Начинать с политики, отрицающей весь входящий трафик:

```yaml
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Потом добавлять разрешения для конкретных сервисов.

**Использование namespace для изоляции**

Разделять приложения по namespace для облегчения применения политик:

```bash
kubectl create namespace production
kubectl create namespace development
```

Network Policies могут действовать на уровне namespace или пересекать их через namespaceSelector.

**Мониторинг доступа**

Логировать попытки доступа через аудит Kubernetes:

```bash
kubectl logs -n kube-system -l component=kube-apiserver | grep audit
```

**Регулярная ревизия прав**

Проверять неиспользуемые роли и привязки:

```bash
kubectl get roles -A
kubectl get rolebindings -A
kubectl get clusterroles
kubectl get clusterrolebindings
```

---

## Полезные команды

### RBAC — просмотр и анализ

Получение всех ролей в namespace:

```bash
kubectl get roles -n <namespace>
```

Получение всех привязок ролей:

```bash
kubectl get rolebindings -n <namespace>
```

Просмотр детальной информации о роли:

```bash
kubectl describe role <role-name> -n <namespace>
```

Просмотр всех ClusterRoles:

```bash
kubectl get clusterroles
```

Проверка прав конкретного ServiceAccount:

```bash
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<sa-name> -n <namespace>
```

Получение прав ServiceAccount (список разрешённых операций):

```bash
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<sa-name> -n <namespace>
```

### Network Policy — просмотр и валидация

Получение всех Network Policies:

```bash
kubectl get networkpolicies -A
```

Просмотр детальной информации:

```bash
kubectl describe networkpolicy <policy-name> -n <namespace>
```

Вывод YAML политики для редактирования:

```bash
kubectl get networkpolicy <policy-name> -n <namespace> -o yaml
```

### ServiceAccount — работа с токенами

Получение списка ServiceAccounts:

```bash
kubectl get serviceaccounts -n <namespace>
```

Получение токена ServiceAccount:

```bash
kubectl get secret -n <namespace> $(kubectl get secret -n <namespace> | grep <sa-name> | awk '{print $1}') -o jsonpath='{.data.token}' | base64 -d
```

Использование токена в kubectl:

```bash
kubectl --token=<token> --server=https://<api-server>:6443 --insecure-skip-tls-verify get pods
```

### Отладка сетевого доступа

Проверка доступности сервиса из пода:

```bash
kubectl exec -it <pod-name> -n <namespace> -- sh -c "curl -v http://<target-pod-ip>:<port>"
```

Просмотр правил Calico (если установлен):

```bash
kubectl get globalnetworkpolicies
kubectl describe globalnetworkpolicy <policy-name>
```

Проверка логов Calico пода:

```bash
kubectl logs -n kube-system -l k8s-app=calico-node --tail=50
```

---

## RBAC плагины и инструменты

### rakkess — матрица доступа в TUI

Интерактивное отображение прав текущего пользователя и ServiceAccounts.

**Установка:**

```bash
go install github.com/corneliusweig/rakkess@latest
```

**Использование:**

```bash
rakkess
```

Выводит матрицу прав для всех ресурсов в текущем context. Навигация стрелками, Enter для деталей.

Просмотр прав конкретного ServiceAccount:

```bash
rakkess --sa <namespace>:<service-account-name>
```

Пример:

```bash
rakkess --sa default:app-account
```

**Возможности:**

- Быстрая визуализация всех прав пользователя
- Просмотр доступа к ресурсам по namespace
- Отображение глаголов (get, list, create, delete)
- Цветовая индикация (зелёный — разрешено, красный — запрещено)

### kubectl-rbac (rbac-view) — веб-интерфейс

Визуализация структуры RBAC через веб-интерфейс.

**Установка через krew:**

```bash
kubectl krew install rbac-view
```

**Использование:**

```bash
kubectl rbac-view
```

По умолчанию открывает веб-интерфейс на http://localhost:8800.

**Возможности:**

- Граф связей между ролями и ServiceAccounts
- Поиск по ролям и привязкам
- Визуализация ClusterRoles и Roles
- Экспорт в различные форматы

### kubectl auth — встроенная утилита

Встроенная команда для проверки прав без плагинов.

**Проверка конкретного глагола:**

```bash
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<sa-name> -n <namespace>
```

**Список всех прав:**

```bash
kubectl auth can-i --list --as=system:serviceaccount:<namespace>:<sa-name> -n <namespace>
```

Выводит полный список разрешённых операций для ServiceAccount.

**Проверка от своего имени:**

```bash
kubectl auth can-i get pods
```

### kubectx + kubeconfig — переключение context

Для управления несколькими кластерами и пользователями.

**Установка kubectx:**

```bash
git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubectx-ns /usr/local/bin/kubectx-ns
```

**Просмотр текущего context:**

```bash
kubectx
```

**Переключение context:**

```bash
kubectx <context-name>
```

**Работа с namespace (через kubectx-ns):**

```bash
kubectx-ns <namespace-name>
```

### Анализ RBAC через запросы к API

Прямой запрос к API Kubernetes для получения информации о ролях.

**Получение всех ролей в JSON:**

```bash
kubectl get roles -A -o json | jq '.items[] | {name: .metadata.name, namespace: .metadata.namespace, rules: .rules}'
```

**Получение ролей с фильтром по ресурсам:**

```bash
kubectl get roles -A -o json | jq '.items[] | select(.rules[]?.resources[]? | contains("pods")) | {name: .metadata.name, namespace: .metadata.namespace}'
```

**Получение всех привязок конкретного ServiceAccount:**

```bash
SA_NAME="app-account"
NAMESPACE="default"
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq --arg sa "$SA_NAME" --arg ns "$NAMESPACE" \
  '.items[] | select(.subjects[]? | select(.name == $sa and .namespace == $ns)) | {kind: .kind, name: .metadata.name, role: .roleRef.name}'
```

**Проверка всех ServiceAccounts с правами на определённый ресурс:**

```bash
RESOURCE="configmaps"
kubectl get roles -A -o json | \
  jq --arg res "$RESOURCE" '.items[] | select(.rules[]?.resources[]? | contains($res)) | {name: .metadata.name, namespace: .metadata.namespace}'
```

### Сравнение прав между ServiceAccounts

Скрипт для сравнения разрешений двух ServiceAccounts:

```bash
SA1="user1"
SA2="app-account"
NAMESPACE="default"

echo "=== Права $SA1 ==="
kubectl auth can-i --list --as=system:serviceaccount:$NAMESPACE:$SA1 -n $NAMESPACE | head -10

echo -e "\n=== Права $SA2 ==="
kubectl auth can-i --list --as=system:serviceaccount:$NAMESPACE:$SA2 -n $NAMESPACE | head -10
```

### Аудит изменений RBAC

Просмотр истории изменений ролей через kubectl:

```bash
kubectl get event -n <namespace> --sort-by='.lastTimestamp' | grep -i role
```

Получение всех операций с ролями:

```bash
kubectl get audit.k8s.io -A 2>/dev/null || echo "Audit API не включен"
```

### Рекомендуемый workflow

Для production окружения:

1. **Регулярная проверка прав через rakkess:**
   ```bash
   rakkess --sa production:api-service
   ```

2. **Визуализация через rbac-view:**
   ```bash
   kubectl rbac-view
   ```

3. **Валидация через kubectl auth:**
   ```bash
   kubectl auth can-i create pods --as=system:serviceaccount:production:api-service -n production
   ```

4. **Анализ через jq для сложных запросов:**
   ```bash
   kubectl get roles -A -o json | jq 'фильтр'
   ```

5. **Резервная копия RBAC конфигурации:**
   ```bash
   kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A -o yaml > rbac-backup.yaml
   ```
