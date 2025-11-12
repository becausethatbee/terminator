# kubectl - RBAC и безопасность

Справочник команд для управления Role, ClusterRole, RoleBinding, ClusterRoleBinding, ServiceAccount и аутентификацией.

## Предварительные требования

- kubectl версии 1.28+
- Доступ к Kubernetes кластеру
- Права для создания RBAC ресурсов

---

## Role операции

### Создание Role

**Императивное создание:**

```bash
kubectl create role <n> --verb=<VERBS> --resource=<RESOURCES>
kubectl create role pod-reader --verb=get,list,watch --resource=pods
kubectl create role deployer --verb=get,list,create,update,delete --resource=deployments
```

| Флаг | Описание |
|------|----------|
| `--verb` | Действия (get, list, watch, create, update, patch, delete) |
| `--resource` | Типы ресурсов |
| `--resource-name` | Конкретные имена ресурсов |
| `--namespace` | Namespace для Role (default current) |
| `--dry-run` | Тестовый режим |

**С указанием resource names:**

```bash
kubectl create role config-reader --verb=get --resource=configmaps --resource-name=app-config,db-config
```

**С API groups:**

```bash
kubectl create role deployment-manager --verb=* --resource=deployments.apps
```

**Генерация YAML:**

```bash
kubectl create role pod-reader --verb=get,list --resource=pods --dry-run=client -o yaml > role.yaml
```

### Role манифест

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: default
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

**Множественные правила:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
```

**С resource names:**

```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config", "db-config"]
  verbs: ["get", "update"]
```

**Wildcard permissions:**

```yaml
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

Не рекомендуется для production - дает полные права.

### Просмотр Role

```bash
kubectl get roles
kubectl get role <n>
kubectl describe role <n>
```

**Все Roles в кластере:**

```bash
kubectl get roles -A
```

**Правила Role:**

```bash
kubectl get role <n> -o yaml
kubectl describe role <n> | grep -A 20 "Rules"
```

### Редактирование Role

```bash
kubectl edit role <n>
kubectl patch role <n> -p '{"rules":[{"apiGroups":[""],"resources":["pods"],"verbs":["get","list"]}]}'
```

### Удаление Role

```bash
kubectl delete role <n>
kubectl delete roles -l app=<LABEL>
```

---

## ClusterRole операции

### Создание ClusterRole

**Императивное создание:**

```bash
kubectl create clusterrole <n> --verb=<VERBS> --resource=<RESOURCES>
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrole cluster-admin --verb=* --resource=*
```

**Aggregated ClusterRole:**

```bash
kubectl create clusterrole monitoring --verb=get,list --resource=pods,services --aggregate-to-admin=true
```

**Non-resource URLs:**

```bash
kubectl create clusterrole healthcheck --verb=get --non-resource-url=/healthz,/livez
```

### ClusterRole манифест

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
```

**Для cluster-scoped ресурсов:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
- apiGroups: [""]
  resources: ["nodes", "persistentvolumes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
```

**Aggregation ClusterRole:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring
  labels:
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
rules:
- apiGroups: [""]
  resources: ["services", "endpoints", "pods"]
  verbs: ["get", "list", "watch"]
```

Aggregation labels автоматически добавляют правила к существующим ClusterRoles.

**Non-resource URLs:**

```yaml
rules:
- nonResourceURLs: ["/healthz", "/healthz/*", "/metrics"]
  verbs: ["get"]
```

### Default ClusterRoles

| ClusterRole | Назначение |
|-------------|------------|
| cluster-admin | Полные права в кластере |
| admin | Полные права в namespace |
| edit | Чтение/запись большинства ресурсов в namespace |
| view | Только чтение ресурсов в namespace |
| system:node | Права для kubelet |
| system:kube-scheduler | Права для scheduler |
| system:kube-controller-manager | Права для controller manager |

### Просмотр ClusterRole

```bash
kubectl get clusterroles
kubectl get clusterrole <n>
kubectl describe clusterrole <n>
```

**System ClusterRoles:**

```bash
kubectl get clusterroles | grep system
```

**Custom ClusterRoles:**

```bash
kubectl get clusterroles | grep -v system
```

### Редактирование ClusterRole

```bash
kubectl edit clusterrole <n>
```

Редактирование default ClusterRoles не рекомендуется - изменения могут быть перезаписаны.

### Удаление ClusterRole

```bash
kubectl delete clusterrole <n>
```

---

## RoleBinding операции

### Создание RoleBinding

**Binding к User:**

```bash
kubectl create rolebinding <n> --role=<ROLE> --user=<USER>
kubectl create rolebinding dev-binding --role=developer --user=john
```

**Binding к Group:**

```bash
kubectl create rolebinding <n> --role=<ROLE> --group=<GROUP>
kubectl create rolebinding team-binding --role=developer --group=dev-team
```

**Binding к ServiceAccount:**

```bash
kubectl create rolebinding <n> --role=<ROLE> --serviceaccount=<NAMESPACE>:<SA>
kubectl create rolebinding app-binding --role=pod-reader --serviceaccount=default:app-sa
```

**Binding ClusterRole в namespace:**

```bash
kubectl create rolebinding <n> --clusterrole=<CLUSTERROLE> --user=<USER>
kubectl create rolebinding admin-binding --clusterrole=admin --user=alice -n production
```

| Флаг | Описание |
|------|----------|
| `--role` | Role в том же namespace |
| `--clusterrole` | ClusterRole для использования в namespace |
| `--user` | Username для binding |
| `--group` | Group для binding |
| `--serviceaccount` | ServiceAccount для binding (format: namespace:name) |
| `--namespace` | Namespace для RoleBinding |

**Множественные subjects:**

```bash
kubectl create rolebinding multi-binding --role=viewer --user=alice --user=bob --group=readers
```

### RoleBinding манифест

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer
subjects:
- kind: User
  name: john
  apiGroup: rbac.authorization.k8s.io
```

**Binding к ServiceAccount:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: default
```

**Binding к Group:**

```yaml
subjects:
- kind: Group
  name: dev-team
  apiGroup: rbac.authorization.k8s.io
```

**Binding ClusterRole:**

```yaml
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
```

### Просмотр RoleBinding

```bash
kubectl get rolebindings
kubectl get rolebinding <n>
kubectl describe rolebinding <n>
```

**Все RoleBindings в кластере:**

```bash
kubectl get rolebindings -A
```

**Subjects для RoleBinding:**

```bash
kubectl get rolebinding <n> -o jsonpath='{.subjects[*].name}'
```

### Удаление RoleBinding

```bash
kubectl delete rolebinding <n>
kubectl delete rolebindings -l app=<LABEL>
```

---

## ClusterRoleBinding операции

### Создание ClusterRoleBinding

**Binding к User:**

```bash
kubectl create clusterrolebinding <n> --clusterrole=<CLUSTERROLE> --user=<USER>
kubectl create clusterrolebinding admin-binding --clusterrole=cluster-admin --user=admin
```

**Binding к Group:**

```bash
kubectl create clusterrolebinding <n> --clusterrole=<CLUSTERROLE> --group=<GROUP>
kubectl create clusterrolebinding ops-binding --clusterrole=cluster-admin --group=ops-team
```

**Binding к ServiceAccount:**

```bash
kubectl create clusterrolebinding <n> --clusterrole=<CLUSTERROLE> --serviceaccount=<NAMESPACE>:<SA>
kubectl create clusterrolebinding monitoring-binding --clusterrole=view --serviceaccount=monitoring:prometheus
```

### ClusterRoleBinding манифест

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: User
  name: admin
  apiGroup: rbac.authorization.k8s.io
```

**Множественные subjects:**

```yaml
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
- kind: User
  name: bob
  apiGroup: rbac.authorization.k8s.io
- kind: Group
  name: ops-team
  apiGroup: rbac.authorization.k8s.io
```

### Просмотр ClusterRoleBinding

```bash
kubectl get clusterrolebindings
kubectl get clusterrolebinding <n>
kubectl describe clusterrolebinding <n>
```

**System ClusterRoleBindings:**

```bash
kubectl get clusterrolebindings | grep system
```

### Удаление ClusterRoleBinding

```bash
kubectl delete clusterrolebinding <n>
```

---

## ServiceAccount операции

### Создание ServiceAccount

```bash
kubectl create serviceaccount <n>
kubectl create sa <n>
```

**С image pull secrets:**

```bash
kubectl create sa app-sa
kubectl patch sa app-sa -p '{"imagePullSecrets":[{"name":"regcred"}]}'
```

### ServiceAccount манифест

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
imagePullSecrets:
- name: regcred
automountServiceAccountToken: true
```

### Просмотр ServiceAccount

```bash
kubectl get serviceaccounts
kubectl get sa
kubectl get sa <n>
kubectl describe sa <n>
```

**Secrets для ServiceAccount:**

```bash
kubectl get sa <n> -o jsonpath='{.secrets[*].name}'
```

### ServiceAccount token (1.24+)

**Создание token:**

```bash
kubectl create token <SA_NAME>
kubectl create token <SA_NAME> --duration=1h
kubectl create token <SA_NAME> --duration=24h
```

| Флаг | Описание |
|------|----------|
| `--duration` | Время жизни token (default 1h) |
| `--audience` | Intended audience для token |
| `--bound-object-kind` | Тип объекта для binding |
| `--bound-object-name` | Имя объекта для binding |

**Token с bound pod:**

```bash
kubectl create token app-sa --bound-object-kind=Pod --bound-object-name=app-pod
```

### Legacy ServiceAccount token (до 1.24)

**Secret для ServiceAccount:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-sa-token
  annotations:
    kubernetes.io/service-account.name: app-sa
type: kubernetes.io/service-account-token
```

```bash
kubectl apply -f sa-token-secret.yaml
```

**Получение token:**

```bash
kubectl get secret app-sa-token -o jsonpath='{.data.token}' | base64 -d
```

### Использование ServiceAccount в Pod

```yaml
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: true
  containers:
  - name: app
    image: app:v1
```

**Отключение автомонтирования:**

```yaml
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
```

**Путь к token в pod:**

```
/var/run/secrets/kubernetes.io/serviceaccount/token
```

### Удаление ServiceAccount

```bash
kubectl delete sa <n>
```

---

## Проверка разрешений

### Can-I проверки

**Проверка для текущего пользователя:**

```bash
kubectl auth can-i <VERB> <RESOURCE>
kubectl auth can-i create pods
kubectl auth can-i delete deployments
kubectl auth can-i get nodes
kubectl auth can-i list secrets -n kube-system
```

**Проверка для конкретного пользователя:**

```bash
kubectl auth can-i <VERB> <RESOURCE> --as=<USER>
kubectl auth can-i create pods --as=john
kubectl auth can-i delete deployments --as=alice
```

**Проверка для ServiceAccount:**

```bash
kubectl auth can-i <VERB> <RESOURCE> --as=system:serviceaccount:<NAMESPACE>:<SA_NAME>
kubectl auth can-i list secrets --as=system:serviceaccount:default:app-sa
```

**Проверка для Group:**

```bash
kubectl auth can-i <VERB> <RESOURCE> --as=user --as-group=<GROUP>
kubectl auth can-i create deployments --as=john --as-group=dev-team
```

**В определенном namespace:**

```bash
kubectl auth can-i create pods -n production
kubectl auth can-i delete services --all-namespaces
```

**Список всех разрешений:**

```bash
kubectl auth can-i --list
kubectl auth can-i --list --as=john
kubectl auth can-i --list -n production
```

**Проверка для конкретного ресурса:**

```bash
kubectl auth can-i get pods/nginx
kubectl auth can-i delete deployment/app
```

**С subresource:**

```bash
kubectl auth can-i get pods/log
kubectl auth can-i get deployments/status
kubectl auth can-i update deployments/scale
```

### Who Am I

```bash
kubectl auth whoami
kubectl auth whoami -o yaml
kubectl auth whoami -o json
```

Вывод включает: username, uid, groups, extra attributes.

---

## RBAC анализ

### Проверка прав пользователя

**Все RoleBindings для user:**

```bash
kubectl get rolebindings -A -o json | jq '.items[] | select(.subjects[]? | .kind=="User" and .name=="<USER>") | {namespace:.metadata.namespace, name:.metadata.name, role:.roleRef.name}'
```

**Все ClusterRoleBindings для user:**

```bash
kubectl get clusterrolebindings -o json | jq '.items[] | select(.subjects[]? | .kind=="User" and .name=="<USER>") | {name:.metadata.name, role:.roleRef.name}'
```

### Проверка прав ServiceAccount

**RoleBindings для ServiceAccount:**

```bash
kubectl get rolebindings -A -o json | jq '.items[] | select(.subjects[]? | .kind=="ServiceAccount" and .name=="<SA>") | {namespace:.metadata.namespace, name:.metadata.name, role:.roleRef.name}'
```

**ClusterRoleBindings для ServiceAccount:**

```bash
kubectl get clusterrolebindings -o json | jq '.items[] | select(.subjects[]? | .kind=="ServiceAccount" and .name=="<SA>") | {name:.metadata.name, role:.roleRef.name}'
```

### Audit RBAC

**Все ClusterRoleBindings к cluster-admin:**

```bash
kubectl get clusterrolebindings -o json | jq '.items[] | select(.roleRef.name=="cluster-admin") | {name:.metadata.name, subjects:.subjects}'
```

**Wildcard permissions:**

```bash
kubectl get roles,clusterroles -A -o json | jq '.items[] | select(.rules[]? | .verbs[]? == "*" or .resources[]? == "*") | {kind:.kind, name:.metadata.name, namespace:.metadata.namespace}'
```

---

## Pod Security Standards

### PodSecurityPolicy (deprecated в 1.25)

PSP заменен на Pod Security Admission.

### Pod Security Admission

**Namespace labels для enforcement:**

```bash
kubectl label namespace <n> pod-security.kubernetes.io/enforce=<LEVEL>
kubectl label namespace production pod-security.kubernetes.io/enforce=restricted
kubectl label namespace dev pod-security.kubernetes.io/enforce=baseline
```

**Security levels:**

| Level | Описание |
|-------|----------|
| privileged | Без ограничений |
| baseline | Минимальные ограничения |
| restricted | Строгие ограничения |

**Все enforcement modes:**

```bash
kubectl label namespace <n> \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

**Проверка namespace labels:**

```bash
kubectl get namespace <n> --show-labels
kubectl get namespace <n> -o jsonpath='{.metadata.labels}'
```

---

## Security Context

### Pod Security Context

```yaml
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    fsGroupChangePolicy: "OnRootMismatch"
    seccompProfile:
      type: RuntimeDefault
```

**SELinux:**

```yaml
securityContext:
  seLinuxOptions:
    level: "s0:c123,c456"
```

**Sysctls:**

```yaml
securityContext:
  sysctls:
  - name: net.ipv4.ip_forward
    value: "1"
```

### Container Security Context

```yaml
spec:
  containers:
  - name: app
    securityContext:
      runAsUser: 1000
      runAsNonRoot: true
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE
```

**Privileged container:**

```yaml
securityContext:
  privileged: true
```

Не рекомендуется для production.

### Capabilities

```yaml
securityContext:
  capabilities:
    drop:
    - ALL
    add:
    - NET_BIND_SERVICE
    - CHOWN
    - SETUID
    - SETGID
```

**Список capabilities:**

| Capability | Назначение |
|------------|------------|
| NET_BIND_SERVICE | Bind к портам < 1024 |
| CHOWN | Изменение владельца файлов |
| SETUID | Изменение UID |
| SETGID | Изменение GID |
| NET_ADMIN | Network администрирование |
| SYS_ADMIN | Системное администрирование |

---

## Certificate управление

### CSR операции

**Создание CSR:**

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: john-csr
spec:
  request: <BASE64_CSR>
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
```

**Генерация private key и CSR:**

```bash
openssl genrsa -out john.key 2048
openssl req -new -key john.key -out john.csr -subj "/CN=john/O=dev-team"
```

**Base64 encoding CSR:**

```bash
cat john.csr | base64 | tr -d '\n'
```

### Просмотр CSR

```bash
kubectl get certificatesigningrequests
kubectl get csr
kubectl get csr <n>
kubectl describe csr <n>
```

### Approve/Deny CSR

**Approve:**

```bash
kubectl certificate approve <n>
```

**Deny:**

```bash
kubectl certificate deny <n>
```

**Получение сертификата:**

```bash
kubectl get csr <n> -o jsonpath='{.status.certificate}' | base64 -d > john.crt
```

### Создание kubeconfig с сертификатом

```bash
kubectl config set-credentials john --client-certificate=john.crt --client-key=john.key
kubectl config set-context john-context --cluster=<CLUSTER> --user=john
```

---

## Network Policies для безопасности

### Default deny policies

**Deny all ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Deny all egress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

**Deny all traffic:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

---

## Secrets управление

### Encryption at rest

**Проверка encryption configuration:**

```bash
kubectl get secrets -A -o json | jq '.items[0].data | keys'
```

Если данные в Base64 - encryption at rest не включен.

### External secrets

**Использование External Secrets Operator:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secret
  data:
  - secretKey: password
    remoteRef:
      key: secret/data/app
      property: password
```

---

## Troubleshooting

### Forbidden ошибки

**Проверка текущего пользователя:**

```bash
kubectl auth whoami
```

**Проверка разрешений:**

```bash
kubectl auth can-i <VERB> <RESOURCE>
kubectl auth can-i --list
```

**Проверка RoleBindings:**

```bash
kubectl get rolebindings,clusterrolebindings -A -o wide
```

### ServiceAccount не работает

**Проверка существования SA:**

```bash
kubectl get sa <SA_NAME>
```

**Проверка RoleBindings для SA:**

```bash
kubectl get rolebindings -A -o json | jq '.items[] | select(.subjects[]? | .kind=="ServiceAccount" and .name=="<SA>")'
```

**Проверка token в pod:**

```bash
kubectl exec <POD_NAME> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

### RBAC тестирование

**Тест от имени пользователя:**

```bash
kubectl get pods --as=john
kubectl get deployments --as=alice -n production
```

**Тест от имени ServiceAccount:**

```bash
kubectl get pods --as=system:serviceaccount:default:app-sa
```

**Логи API server для audit:**

```bash
kubectl logs -n kube-system <API_SERVER_POD> | grep -i forbidden
```