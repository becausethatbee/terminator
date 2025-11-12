# kubectl - Сетевые ресурсы

Справочник команд для управления Service, Ingress, NetworkPolicy, Endpoints и сетевой конфигурацией.

## Предварительные требования

- kubectl версии 1.28+
- Доступ к Kubernetes кластеру
- CNI plugin для NetworkPolicy (Calico, Cilium, Weave)

---

## Service операции

### Создание Service

**ClusterIP Service:**

```bash
kubectl create service clusterip <n> --tcp=<PORT>:<TARGET_PORT>
kubectl create service clusterip web --tcp=80:8080
```

**NodePort Service:**

```bash
kubectl create service nodeport <n> --tcp=<PORT>:<TARGET_PORT> --node-port=<NODE_PORT>
kubectl create service nodeport web --tcp=80:8080 --node-port=30080
```

**LoadBalancer Service:**

```bash
kubectl create service loadbalancer <n> --tcp=<PORT>:<TARGET_PORT>
kubectl create service loadbalancer web --tcp=80:8080
```

**ExternalName Service:**

```bash
kubectl create service externalname <n> --external-name=<EXTERNAL_DNS>
kubectl create service externalname db --external-name=db.example.com
```

### Expose - Создание Service для ресурса

**Expose Deployment:**

```bash
kubectl expose deployment <n> --port=<PORT> --target-port=<TARGET_PORT>
kubectl expose deployment nginx --port=80 --target-port=8080
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl expose deployment nginx --port=80 --type=LoadBalancer
```

| Флаг | Описание |
|------|----------|
| `--port` | Service port |
| `--target-port` | Container port (default = port) |
| `--type` | Service type (ClusterIP/NodePort/LoadBalancer) |
| `--protocol` | Protocol (TCP/UDP/SCTP) |
| `--name` | Имя Service (default = имя ресурса) |
| `--selector` | Label selector |
| `--external-ip` | External IP адреса |
| `--load-balancer-ip` | IP для LoadBalancer |
| `--session-affinity` | Session affinity (ClientIP/None) |
| `--cluster-ip` | ClusterIP адрес (или None для headless) |

**Expose Pod:**

```bash
kubectl expose pod <POD_NAME> --port=<PORT> --name=<SERVICE_NAME>
kubectl expose pod nginx --port=80 --name=nginx-service
```

**Expose ReplicaSet:**

```bash
kubectl expose rs <n> --port=<PORT>
```

**Headless Service:**

```bash
kubectl expose deployment <n> --port=<PORT> --cluster-ip=None
```

### Просмотр Service

```bash
kubectl get services
kubectl get svc
kubectl get svc <n>
kubectl describe svc <n>
```

**С дополнительной информацией:**

```bash
kubectl get svc -o wide
kubectl get svc --show-labels
```

**External IP для LoadBalancer:**

```bash
kubectl get svc <n> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
kubectl get svc <n> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**NodePort:**

```bash
kubectl get svc <n> -o jsonpath='{.spec.ports[0].nodePort}'
```

**ClusterIP:**

```bash
kubectl get svc <n> -o jsonpath='{.spec.clusterIP}'
```

### Типы Service

| Тип | Описание | Использование |
|-----|----------|---------------|
| ClusterIP | Внутренний IP в кластере | Внутренняя коммуникация между сервисами |
| NodePort | Порт на каждой node | Доступ извне через NodeIP:NodePort |
| LoadBalancer | Внешний LoadBalancer | Продакшн доступ извне через облачный LB |
| ExternalName | DNS CNAME запись | Proxy к внешнему сервису |

### Service селекторы

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: nginx
    tier: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
```

Service направляет трафик на pods с matching labels.

### Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-headless
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
  - port: 80
```

Headless service не имеет ClusterIP, DNS возвращает IP pods напрямую.

### Session Affinity

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```

Session affinity направляет запросы от одного клиента к одному pod.

### Удаление Service

```bash
kubectl delete service <n>
kubectl delete svc <n>
kubectl delete svc -l app=<LABEL>
```

---

## Endpoints операции

### Просмотр Endpoints

```bash
kubectl get endpoints
kubectl get ep
kubectl get ep <SERVICE_NAME>
kubectl describe ep <SERVICE_NAME>
```

Endpoints содержат IP адреса pods, на которые направляет Service.

**IP адреса endpoints:**

```bash
kubectl get ep <SERVICE_NAME> -o jsonpath='{.subsets[*].addresses[*].ip}'
```

**Количество endpoints:**

```bash
kubectl get ep <SERVICE_NAME> -o jsonpath='{.subsets[*].addresses}' | jq 'length'
```

### Проверка Service-Pod связи

```bash
kubectl get pods -l <SELECTOR> -o wide
kubectl get ep <SERVICE_NAME>
```

Проверка что selector Service совпадает с labels pods.

### Ручные Endpoints

**Service без selector:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  ports:
  - port: 3306
```

**Endpoints ресурс:**

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db
subsets:
- addresses:
  - ip: 192.168.1.100
  ports:
  - port: 3306
```

Ручные endpoints для внешних сервисов.

---

## Ingress операции

### Создание Ingress

**Императивное создание:**

```bash
kubectl create ingress <n> --rule="<HOST>/<PATH>=<SERVICE>:<PORT>"
kubectl create ingress web --rule="example.com/=web:80"
kubectl create ingress api --rule="api.example.com/v1=api:8080"
```

**Множественные правила:**

```bash
kubectl create ingress multi --rule="app1.example.com/=svc1:80" --rule="app2.example.com/=svc2:80"
```

**Генерация YAML:**

```bash
kubectl create ingress web --rule="example.com/=web:80" --dry-run=client -o yaml > ingress.yaml
```

### Ingress манифест

**Базовый Ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

**Path types:**

| PathType | Поведение |
|----------|-----------|
| Exact | Точное совпадение path |
| Prefix | Префикс path |
| ImplementationSpecific | Зависит от Ingress Controller |

**Множественные hosts:**

```yaml
spec:
  rules:
  - host: app1.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
  - host: app2.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
```

**Множественные paths для одного host:**

```yaml
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api
            port:
              number: 8080
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

**Default backend:**

```yaml
spec:
  defaultBackend:
    service:
      name: default-backend
      port:
        number: 80
  rules:
  - host: example.com
    # ...
```

### TLS для Ingress

```yaml
spec:
  tls:
  - hosts:
    - example.com
    - www.example.com
    secretName: tls-secret
  rules:
  - host: example.com
    # ...
```

**Создание TLS secret:**

```bash
kubectl create secret tls tls-secret --cert=tls.crt --key=tls.key
```

### Ingress annotations

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
```

Annotations зависят от Ingress Controller (Nginx, Traefik, HAProxy).

**Nginx Ingress annotations:**

| Annotation | Назначение |
|------------|------------|
| `nginx.ingress.kubernetes.io/rewrite-target` | Rewrite path перед проксированием |
| `nginx.ingress.kubernetes.io/ssl-redirect` | Редирект HTTP на HTTPS |
| `nginx.ingress.kubernetes.io/force-ssl-redirect` | Принудительный SSL редирект |
| `nginx.ingress.kubernetes.io/backend-protocol` | Backend protocol (HTTP/HTTPS/GRPC) |
| `nginx.ingress.kubernetes.io/rate-limit` | Rate limiting |
| `nginx.ingress.kubernetes.io/auth-type` | Тип аутентификации |
| `nginx.ingress.kubernetes.io/whitelist-source-range` | IP whitelist |

### Просмотр Ingress

```bash
kubectl get ingress
kubectl get ing
kubectl get ing <n>
kubectl describe ing <n>
```

**External IP:**

```bash
kubectl get ing <n> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Все hosts и paths:**

```bash
kubectl get ing <n> -o jsonpath='{.spec.rules[*].host}'
```

### IngressClass

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
```

```bash
kubectl get ingressclass
kubectl get ingressclass <n>
```

**Использование IngressClass:**

```yaml
spec:
  ingressClassName: nginx
  rules:
  # ...
```

### Удаление Ingress

```bash
kubectl delete ingress <n>
kubectl delete ing <n>
```

---

## NetworkPolicy операции

### Создание NetworkPolicy

NetworkPolicy создается декларативно через манифест.

**Default deny all ingress:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: <NAMESPACE>
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Default deny all egress:**

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

**Allow ingress от specific pods:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Allow ingress от specific namespace:**

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        env: production
  ports:
  - protocol: TCP
    port: 80
```

**Allow ingress от IP блока:**

```yaml
ingress:
- from:
  - ipBlock:
      cidr: 10.0.0.0/16
      except:
      - 10.0.1.0/24
  ports:
  - protocol: TCP
    port: 80
```

**Allow egress к specific сервисам:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-db-egress
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

**Allow egress для DNS:**

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
```

**Комбинация Ingress и Egress:**

```yaml
spec:
  podSelector:
    matchLabels:
      app: web
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
```

### Просмотр NetworkPolicy

```bash
kubectl get networkpolicies
kubectl get netpol
kubectl get netpol <n>
kubectl describe netpol <n>
```

**Все NetworkPolicy в кластере:**

```bash
kubectl get netpol -A
```

### Selector синтаксис

**PodSelector:**

```yaml
podSelector:
  matchLabels:
    app: web
    tier: frontend
```

**MatchExpressions:**

```yaml
podSelector:
  matchExpressions:
  - key: app
    operator: In
    values:
    - web
    - api
```

**NamespaceSelector:**

```yaml
namespaceSelector:
  matchLabels:
    env: production
```

**Комбинация pod и namespace selector:**

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        env: production
    podSelector:
      matchLabels:
        app: frontend
```

### Удаление NetworkPolicy

```bash
kubectl delete networkpolicy <n>
kubectl delete netpol <n>
```

### NetworkPolicy best practices

**Принцип least privilege:**

Начать с deny-all и добавлять только необходимые правила:

```yaml
# 1. Deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

```yaml
# 2. Allow specific
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
```

**Egress DNS всегда нужен:**

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
```

---

## DNS и Service Discovery

### DNS записи для Service

**ClusterIP Service:**

```
<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local
```

Пример: `web.default.svc.cluster.local`

**В том же namespace:**

```
<SERVICE_NAME>
```

**Headless Service:**

```
<POD_NAME>.<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local
```

### Проверка DNS resolution

```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <SERVICE_NAME>
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <SERVICE_NAME>.<NAMESPACE>.svc.cluster.local
```

**Dig запрос:**

```bash
kubectl run -it --rm debug --image=tutum/dnsutils --restart=Never -- dig <SERVICE_NAME>
```

### CoreDNS конфигурация

```bash
kubectl get configmap coredns -n kube-system
kubectl describe configmap coredns -n kube-system
```

**Логи CoreDNS:**

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
```

---

## Port Forwarding

### Port forward к ресурсам

**К Pod:**

```bash
kubectl port-forward <POD_NAME> <LOCAL_PORT>:<POD_PORT>
kubectl port-forward nginx-pod 8080:80
```

**К Service:**

```bash
kubectl port-forward service/<SERVICE_NAME> <LOCAL_PORT>:<SERVICE_PORT>
kubectl port-forward svc/web 8080:80
```

**К Deployment:**

```bash
kubectl port-forward deployment/<DEPLOYMENT_NAME> <LOCAL_PORT>:<POD_PORT>
kubectl port-forward deploy/nginx 8080:80
```

**С указанием bind адреса:**

```bash
kubectl port-forward <POD_NAME> 8080:80 --address=0.0.0.0
kubectl port-forward <POD_NAME> 8080:80 --address=127.0.0.1,192.168.1.100
```

**Множественные порты:**

```bash
kubectl port-forward <POD_NAME> 8080:80 8443:443
```

| Флаг | Описание |
|------|----------|
| `--address` | IP адреса для bind (default localhost) |
| `--pod-running-timeout` | Таймаут ожидания running pod |

---

## Proxy

### API Server proxy

```bash
kubectl proxy
kubectl proxy --port=8080
kubectl proxy --address='0.0.0.0' --accept-hosts='.*'
```

Запуск локального proxy к Kubernetes API.

**Доступ к Service через proxy:**

```
http://localhost:8001/api/v1/namespaces/<NAMESPACE>/services/<SERVICE_NAME>/proxy/
```

**Доступ к Pod через proxy:**

```
http://localhost:8001/api/v1/namespaces/<NAMESPACE>/pods/<POD_NAME>/proxy/
```

| Флаг | Описание |
|------|----------|
| `--port` | Порт proxy (default 8001) |
| `--address` | Bind адрес (default 127.0.0.1) |
| `--accept-hosts` | Regex для разрешенных Host headers |
| `--accept-paths` | Regex для разрешенных paths |
| `--api-prefix` | API prefix (default /) |
| `--disable-filter` | Отключение request/path filtering |
| `--www` | Статические файлы для serving |
| `--www-prefix` | Prefix для static content |

---

## Network debugging

### Connectivity тестирование

**Curl от временного pod:**

```bash
kubectl run curl --image=curlimages/curl -it --rm --restart=Never -- curl http://<SERVICE_NAME>
kubectl run curl --image=curlimages/curl -it --rm -- curl http://<SERVICE_NAME>.<NAMESPACE>.svc.cluster.local
```

**Wget тест:**

```bash
kubectl run wget --image=busybox -it --rm -- wget -O- http://<SERVICE_NAME>
```

**Telnet проверка порта:**

```bash
kubectl run telnet --image=busybox -it --rm -- telnet <SERVICE_NAME> <PORT>
```

**Netcat тест:**

```bash
kubectl run netcat --image=busybox -it --rm -- nc -zv <SERVICE_NAME> <PORT>
```

### DNS troubleshooting

**NSLookup:**

```bash
kubectl run nslookup --image=busybox -it --rm -- nslookup <SERVICE_NAME>
kubectl run nslookup --image=busybox -it --rm -- nslookup kubernetes.default
```

**Dig:**

```bash
kubectl run dig --image=tutum/dnsutils -it --rm -- dig <SERVICE_NAME>
kubectl run dig --image=tutum/dnsutils -it --rm -- dig +short <SERVICE_NAME>
```

**Host:**

```bash
kubectl run host --image=tutum/dnsutils -it --rm -- host <SERVICE_NAME>
```

### Network policy тестирование

**Проверка connectivity после применения NetworkPolicy:**

```bash
kubectl run test --image=busybox -it --rm -l app=test -- wget -O- --timeout=2 http://<TARGET_SERVICE>
```

Если NetworkPolicy блокирует трафик, команда завершится timeout.

### Packet capture

**TCPDump в pod:**

```bash
kubectl exec <POD_NAME> -- tcpdump -i any -w /tmp/capture.pcap
kubectl cp <POD_NAME>:/tmp/capture.pcap ./capture.pcap
```

**С фильтрами:**

```bash
kubectl exec <POD_NAME> -- tcpdump -i any port 80
kubectl exec <POD_NAME> -- tcpdump -i any host 10.0.0.1
```

---

## Service Mesh

### Istio команды

**Inject Istio sidecar:**

```bash
kubectl label namespace <NAMESPACE> istio-injection=enabled
```

**Manual injection:**

```bash
istioctl kube-inject -f deployment.yaml | kubectl apply -f -
```

**Проверка Istio proxy:**

```bash
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}'
```

Istio добавляет `istio-proxy` container.

### Linkerd команды

**Inject Linkerd:**

```bash
kubectl get deployment <n> -o yaml | linkerd inject - | kubectl apply -f -
```

**Проверка Linkerd proxy:**

```bash
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].name}'
```

Linkerd добавляет `linkerd-proxy` container.

---

## Troubleshooting

### Service не доступен

**Проверка endpoints:**

```bash
kubectl get svc <SERVICE_NAME>
kubectl get ep <SERVICE_NAME>
```

Если endpoints пустые - проблема с selector.

**Проверка selector:**

```bash
kubectl get svc <SERVICE_NAME> -o jsonpath='{.spec.selector}'
kubectl get pods -l <SELECTOR>
```

**Проверка портов:**

```bash
kubectl get svc <SERVICE_NAME> -o jsonpath='{.spec.ports}'
kubectl describe svc <SERVICE_NAME>
```

### Ingress не работает

**Проверка Ingress Controller:**

```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

**Проверка Ingress ресурса:**

```bash
kubectl describe ing <INGRESS_NAME>
kubectl get ing <INGRESS_NAME> -o yaml
```

**Проверка backend service:**

```bash
kubectl get svc <SERVICE_NAME>
kubectl get ep <SERVICE_NAME>
```

### NetworkPolicy блокирует трафик

**Проверка существующих policies:**

```bash
kubectl get netpol -A
kubectl describe netpol <n>
```

**Временное удаление для теста:**

```bash
kubectl delete netpol <n>
```

**Проверка logs CNI plugin:**

```bash
kubectl logs -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system -l app=cilium
```

### DNS не резолвится

**Проверка CoreDNS:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Тест DNS от pod:**

```bash
kubectl exec <POD_NAME> -- nslookup kubernetes.default
kubectl exec <POD_NAME> -- cat /etc/resolv.conf
```

**Проверка Service для CoreDNS:**

```bash
kubectl get svc -n kube-system kube-dns
kubectl get ep -n kube-system kube-dns
```