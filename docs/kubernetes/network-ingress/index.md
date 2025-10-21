# Kubernetes Ingress: маршрутизация, health checks, HTTPS и A/B-тестирование

Конфигурация Ingress Controller для маршрутизации HTTP/HTTPS трафика, настройки health checks и реализации canary deployments.

## Предварительные требования

- Kubernetes кластер (Minikube)
- kubectl CLI
- Ingress Controller (nginx-ingress)
- OpenSSL для генерации сертификатов
- Права на создание ресурсов в namespace default
- Доступ к /etc/hosts

---

## Архитектура решения

```
┌──────────────────────────────────────────────────────────────┐
│                         Client                               │
│                   (Browser / curl)                           │
└─────────────────────────┬────────────────────────────────────┘
                          │
                          │ HTTP/HTTPS Request
                          │ Host: frontend.local / backend.local / myapp.local
                          │
                          ▼
┌──────────────────────────────────────────────────────────────┐
│                   Ingress Controller                         │
│                    (nginx-ingress)                           │
│                   IP: 192.168.49.2                           │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐      │
│  │    TLS      │  │    Path     │  │     Canary       │      │
│  │ Termination │  │   Routing   │  │  (Weight-based)  │      │
│  │ HTTPS→HTTP  │  │ Host-based  │  │                  │      │
│  └─────────────┘  └─────────────┘  └──────────────────┘      │
└─────┬──────────────┬─────────────────┬───────────────────────┘
      │              │                 │
      │              │                 │
  ┌───▼────┐     ┌───▼────┐        ┌───▼────┐
  │Service │     │Service │        │Service │
  │frontend│     │backend │        │ app-v1 │ (80%)
  │        │     │        │        │        │
  └───┬────┘     └───┬────┘        └───┬────┘
      │              │                 │
  ┌───▼────┐     ┌───▼────┐        ┌───▼────┐
  │  Pod   │     │  Pod   │        │  Pod   │
  │frontend│     │backend │        │   v1   │
  │  x2    │     │  x2    │        │   x2   │
  └────────┘     └────────┘        └────────┘
                                       │
                                   ┌───▼────┐
                                   │Service │
                                   │ app-v2 │ (20%)
                                   │        │
                                   └───┬────┘
                                       │
                                   ┌───▼────┐
                                   │  Pod   │
                                   │   v2   │
                                   │   x2   │
                                   └────────┘
```

---

## Часть 1: Маршрутизация HTTP-запросов

### Активация Ingress Controller

```bash
minikube addons enable ingress
```

Проверка статуса:

```bash
kubectl get pods -n ingress-nginx
```

### Создание приложений

Создание deployment для frontend и backend:

```bash
kubectl create deployment frontend --image=nginx:alpine --replicas=2
kubectl create deployment backend --image=nginx:alpine --replicas=2
```

Настройка контента:

```bash
kubectl exec -it deployment/frontend -- sh -c 'echo "Frontend" > /usr/share/nginx/html/index.html'
kubectl exec -it deployment/backend -- sh -c 'echo "Backend" > /usr/share/nginx/html/index.html'
```

### Создание Services

```bash
kubectl expose deployment frontend --port=80 --target-port=80 --name=frontend
kubectl expose deployment backend --port=80 --target-port=80 --name=backend
```

### Конфигурация Ingress

Манифест `ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: frontend.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
  - host: backend.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 80
```

Применение конфигурации:

```bash
kubectl apply -f ingress.yaml
```

### DNS конфигурация

Получение IP Ingress Controller:

```bash
kubectl get ingress app-ingress
```

Добавление записей в /etc/hosts:

```bash
echo "<INGRESS_IP> frontend.local backend.local" | sudo tee -a /etc/hosts
```

### Валидация

```bash
curl http://frontend.local
curl http://backend.local
```

Ожидаемый результат:
- `frontend.local` возвращает "Frontend"
- `backend.local` возвращает "Backend"

---

## Часть 2: Health Checks

### Механизм работы

Kubernetes использует два типа проверок:
- **readinessProbe**: определяет готовность пода принимать трафик
- **livenessProbe**: определяет работоспособность приложения

### Создание Deployment с Health Checks

Манифест `nginx-health.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-health
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-health
  template:
    metadata:
      labels:
        app: nginx-health
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
```

Применение:

```bash
kubectl apply -f nginx-health.yaml
kubectl expose deployment nginx-health --port=80 --target-port=80 --name=nginx-health
```

### Параметры проверок

| Параметр | readinessProbe | livenessProbe |
|----------|----------------|---------------|
| path | / | / |
| port | 80 | 80 |
| initialDelaySeconds | 5 | 10 |
| periodSeconds | 5 | 10 |
| failureThreshold | 3 | 3 |

### Проверка Endpoints

```bash
kubectl get endpoints nginx-health
```

Service включает только поды со статусом Ready.

### Симуляция падения приложения

Остановка nginx в поде:

```bash
kubectl exec <POD_NAME> -- nginx -s stop
```

Kubernetes обнаруживает падение через livenessProbe и перезапускает контейнер.

Проверка событий:

```bash
kubectl describe pod <POD_NAME> | grep -A 20 "Events:"
```

### Тестирование неработающей конфигурации

Изменение пути readinessProbe на несуществующий:

```yaml
readinessProbe:
  httpGet:
    path: /healthz
    port: 80
```

Результат:
- Новые поды не проходят readinessProbe (HTTP 404)
- Поды не добавляются в endpoints
- Service продолжает использовать старые работающие поды
- Rolling update блокируется

Проверка:

```bash
kubectl get pods -l app=nginx-health
kubectl get endpoints nginx-health
```

---

## Часть 3: HTTPS

### Генерация сертификата

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=frontend.local/O=frontend.local"
```

### Создание Secret

```bash
kubectl create secret tls frontend-tls --cert=tls.crt --key=tls.key
```

Проверка:

```bash
kubectl get secret frontend-tls
kubectl describe secret frontend-tls
```

### Конфигурация Ingress с TLS

Манифест `ingress-tls.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - frontend.local
    secretName: frontend-tls
  rules:
  - host: frontend.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
  - host: backend.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 80
```

Применение:

```bash
kubectl apply -f ingress-tls.yaml
```

### Проверка TLS конфигурации

```bash
kubectl get ingress app-ingress
```

Ingress должен показывать PORTS: 80, 443.

Валидация:

```bash
curl -k https://frontend.local
curl -vk https://frontend.local 2>&1 | grep -A 5 "SSL connection"
```

### Поведение HTTP трафика

nginx-ingress автоматически редиректит HTTP на HTTPS (308 Permanent Redirect) при наличии TLS конфигурации.

---

## Часть 4: A/B-тестирование (Canary Deployments)

### Архитектура Canary

Canary deployment использует аннотации nginx-ingress для весового распределения трафика между версиями.

### Создание версий приложения

Версия v1:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      version: v1
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app-v1
spec:
  selector:
    app: myapp
    version: v1
  ports:
  - port: 80
    targetPort: 80
```

Версия v2:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      version: v2
  template:
    metadata:
      labels:
        app: myapp
        version: v2
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app-v2
spec:
  selector:
    app: myapp
    version: v2
  ports:
  - port: 80
    targetPort: 80
```

Применение:

```bash
kubectl apply -f app-v1.yaml
kubectl apply -f app-v2.yaml
```

Настройка контента:

```bash
kubectl exec deployment/app-v1 -- sh -c 'echo "Welcome to v1" > /usr/share/nginx/html/index.html'
kubectl exec deployment/app-v2 -- sh -c 'echo "Welcome to v2" > /usr/share/nginx/html/index.html'
```

### Конфигурация Canary Ingress

Манифест `ingress-canary.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-main
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-v1
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "20"
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-v2
            port:
              number: 80
```

Применение:

```bash
kubectl apply -f ingress-canary.yaml
```

DNS конфигурация:

```bash
echo "<INGRESS_IP> myapp.local" | sudo tee -a /etc/hosts
```

### Аннотации Canary

| Аннотация | Значение | Описание |
|-----------|----------|----------|
| nginx.ingress.kubernetes.io/canary | "true" | Активация canary mode |
| nginx.ingress.kubernetes.io/canary-weight | "20" | Процент трафика на canary (0-100) |

### Тестирование распределения

Проверка распределения 80/20:

```bash
for i in {1..100}; do curl -s http://myapp.local; done | sort | uniq -c
```

Ожидаемый результат:
- 80 запросов к v1
- 20 запросов к v2

### Изменение распределения

Изменение на 50/50:

```bash
kubectl patch ingress app-canary -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"50"}}}'
```

Проверка:

```bash
for i in {1..100}; do curl -s http://myapp.local; done | sort | uniq -c
```

Результат:
- 50 запросов к v1
- 50 запросов к v2

### Стратегии Canary Deployment

| Weight | Назначение |
|--------|------------|
| 10% | Начальное тестирование новой версии |
| 20-30% | Расширенная валидация |
| 50% | A/B тестирование |
| 100% | Полный переход на новую версию |

---

## Troubleshooting

### Ingress не получает ADDRESS

**Проблема:**
```
kubectl get ingress
ADDRESS пустой
```

**Решение:**
```bash
kubectl get pods -n ingress-nginx
```

Дождаться статуса Running для ingress-nginx-controller.

### Поды не проходят readinessProbe

**Ошибка:**
```
Readiness probe failed: HTTP probe failed with statuscode: 404
```

**Причина:** Некорректный путь в readinessProbe.

**Решение:**
Проверить путь и порт в манифесте:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
```

### TLS сертификат не работает

**Ошибка:**
```
curl: (60) SSL certificate problem: self signed certificate
```

**Решение:**
Использовать флаг `-k` для игнорирования проверки самоподписанного сертификата:

```bash
curl -k https://frontend.local
```

### Canary не распределяет трафик

**Проблема:** Весь трафик идет только на основную версию.

**Решение:**
Проверить аннотации:

```bash
kubectl describe ingress app-canary | grep canary
```

Убедиться что:
- `nginx.ingress.kubernetes.io/canary: "true"`
- `nginx.ingress.kubernetes.io/canary-weight` установлен корректно

### Контент не обновляется в подах

**Проблема:** После записи в index.html контент остается дефолтным.

**Решение:**
Обновить контент во всех подах явно:

```bash
for pod in $(kubectl get pods -l app=<APP_NAME> -o name); do
  kubectl exec $pod -- sh -c 'echo "<CONTENT>" > /usr/share/nginx/html/index.html'
done
```

---

## Best Practices

**Health Checks:**
- Использовать readinessProbe для всех production deployments
- Устанавливать initialDelaySeconds > времени старта приложения
- periodSeconds должен быть достаточным для обнаружения проблем без перегрузки

**TLS:**
- Использовать cert-manager для автоматического управления сертификатами
- Не коммитить приватные ключи в репозиторий
- Обновлять сертификаты до истечения срока действия

**Canary Deployments:**
- Начинать с малого процента (5-10%)
- Мониторить метрики перед увеличением трафика
- Использовать автоматизированные rollback при ошибках
- Документировать критерии успеха canary release

**Ingress:**
- Использовать отдельные Ingress для разных окружений
- Настраивать rate limiting для защиты от DDoS
- Включать CORS headers при необходимости
- Использовать аннотации для точной настройки поведения

**Мониторинг:**
- Отслеживать метрики ingress-nginx-controller
- Логировать все 5xx ошибки
- Настроить алерты на падение health checks
- Мониторить распределение трафика в canary deployments

---

## Полезные команды

**Ingress:**
```bash
# Список всех Ingress
kubectl get ingress -A

# Детальная информация
kubectl describe ingress <NAME>

# Логи Ingress Controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

**Health Checks:**
```bash
# Проверка статуса подов
kubectl get pods -l app=<APP_NAME>

# Просмотр событий пода
kubectl describe pod <POD_NAME>

# Проверка endpoints
kubectl get endpoints <SERVICE_NAME>
```

**TLS:**
```bash
# Список secrets
kubectl get secrets

# Детали TLS secret
kubectl describe secret <SECRET_NAME>

# Проверка сертификата
openssl x509 -in tls.crt -text -noout
```

**Canary:**
```bash
# Обновление canary weight
kubectl patch ingress <NAME> -p '{"metadata":{"annotations":{"nginx.ingress.kubernetes.io/canary-weight":"<VALUE>"}}}'

# Проверка аннотаций
kubectl get ingress <NAME> -o jsonpath='{.metadata.annotations}'
```

**Отладка:**
```bash
# Exec в под
kubectl exec -it <POD_NAME> -- sh

# Просмотр логов пода
kubectl logs <POD_NAME>

# Форвардинг портов
kubectl port-forward svc/<SERVICE_NAME> 8080:80
```