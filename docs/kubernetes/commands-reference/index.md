# Kubernetes Commands Reference

Справочник основных команд для работы с Kubernetes кластером.

## Предварительные требования

- Установленный kubectl
- Доступ к Kubernetes кластеру
- Настроенный kubeconfig

---

## kubectl - Основной CLI

### Общие параметры

```bash
kubectl [command] [TYPE] [NAME] [flags]
```

| Флаг | Описание |
|------|----------|
| `-n, --namespace` | Указать namespace |
| `--all-namespaces` | Работа со всеми namespace |
| `-o, --output` | Формат вывода (json, yaml, wide, name) |
| `--dry-run=client` | Тестовый запуск без применения |
| `-f, --filename` | Путь к файлу манифеста |
| `--force` | Принудительное выполнение |
| `-l, --selector` | Фильтр по labels |
| `--kubeconfig` | Путь к файлу kubeconfig |

### Управление ресурсами

**Создание и применение:**

```bash
kubectl create -f <file.yaml>
kubectl apply -f <file.yaml>
kubectl replace -f <file.yaml>
kubectl delete -f <file.yaml>
```

| Команда | Описание |
|---------|----------|
| `create` | Создание ресурса из файла |
| `apply` | Применение изменений (создание или обновление) |
| `replace` | Замена существующего ресурса |
| `delete` | Удаление ресурса |

**Основные флаги для create/apply:**

```bash
kubectl apply -f <file.yaml> --dry-run=client
kubectl apply -f <directory> --recursive
kubectl create -f <file.yaml> --save-config
```

| Флаг | Описание |
|------|----------|
| `--dry-run=client` | Проверка без применения |
| `--recursive` | Рекурсивная обработка директории |
| `--save-config` | Сохранение конфигурации в аннотации |
| `--validate` | Валидация манифеста перед применением |

### Просмотр ресурсов

```bash
kubectl get <resource>
kubectl describe <resource> <name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- <command>
```

**Get команды:**

| Команда | Описание |
|---------|----------|
| `get pods` | Список pod в текущем namespace |
| `get pods -A` | Список всех pod в кластере |
| `get pods -o wide` | Расширенная информация (IP, node) |
| `get pods -w` | Мониторинг изменений в реальном времени |
| `get pods --show-labels` | Отображение labels |
| `get all` | Все основные ресурсы namespace |

**Describe:**

```bash
kubectl describe pod <pod-name>
kubectl describe node <node-name>
kubectl describe service <service-name>
```

Детальная информация о ресурсе включая events.

**Logs:**

```bash
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -f --tail=100
```

| Флаг | Описание |
|------|----------|
| `-c` | Указать контейнер в multi-container pod |
| `--previous` | Логи предыдущего экземпляра |
| `-f, --follow` | Stream логов в реальном времени |
| `--tail` | Количество последних строк |
| `--since` | Логи за период (1h, 10m) |

### Работа с Pod

**Exec:**

```bash
kubectl exec <pod-name> -- <command>
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec <pod-name> -c <container> -- <command>
```

Выполнение команд внутри контейнера.

**Port-forward:**

```bash
kubectl port-forward <pod-name> <local-port>:<pod-port>
kubectl port-forward service/<service-name> <local-port>:<service-port>
```

Проброс портов для локального доступа.

**Copy файлов:**

```bash
kubectl cp <pod-name>:/path/to/file /local/path
kubectl cp /local/path <pod-name>:/path/to/file
```

Копирование файлов между pod и локальной системой.

### Масштабирование

```bash
kubectl scale deployment <name> --replicas=<count>
kubectl autoscale deployment <name> --min=<min> --max=<max> --cpu-percent=<percent>
```

Управление количеством реплик.

### Редактирование

```bash
kubectl edit <resource> <name>
kubectl patch <resource> <name> -p '<json-patch>'
kubectl set image deployment/<name> <container>=<image>
```

| Команда | Описание |
|---------|----------|
| `edit` | Открытие ресурса в редакторе |
| `patch` | Частичное обновление через JSON/YAML |
| `set image` | Обновление образа контейнера |

### Labels и Annotations

```bash
kubectl label pods <pod-name> <key>=<value>
kubectl label pods <pod-name> <key>-
kubectl annotate pods <pod-name> <key>=<value>
```

Управление метаданными ресурсов.

### Rollout управление

```bash
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout restart deployment/<name>
```

| Команда | Описание |
|---------|----------|
| `status` | Статус развертывания |
| `history` | История ревизий |
| `undo` | Откат к предыдущей версии |
| `restart` | Перезапуск deployment |

**Управление ревизиями:**

```bash
kubectl rollout undo deployment/<name> --to-revision=<number>
kubectl rollout history deployment/<name> --revision=<number>
```

### ConfigMap и Secret

**ConfigMap:**

```bash
kubectl create configmap <name> --from-file=<path>
kubectl create configmap <name> --from-literal=<key>=<value>
kubectl get configmap <name> -o yaml
```

**Secret:**

```bash
kubectl create secret generic <name> --from-file=<path>
kubectl create secret generic <name> --from-literal=<key>=<value>
kubectl create secret docker-registry <name> --docker-server=<server> --docker-username=<user> --docker-password=<pass>
```

| Тип Secret | Назначение |
|------------|------------|
| `generic` | Произвольные данные |
| `tls` | TLS сертификаты |
| `docker-registry` | Credentials для registry |

### Service и Networking

```bash
kubectl expose deployment <name> --port=<port> --target-port=<target> --type=<type>
kubectl get endpoints
kubectl get ingress
```

| Service Type | Описание |
|--------------|----------|
| `ClusterIP` | Внутренний IP кластера |
| `NodePort` | Порт на каждой node |
| `LoadBalancer` | Внешний LoadBalancer |
| `ExternalName` | DNS CNAME запись |

### Тестирование и отладка

```bash
kubectl run <name> --image=<image> --rm -it -- <command>
kubectl debug <pod-name> -it --image=<debug-image>
kubectl top nodes
kubectl top pods
```

| Команда | Описание |
|---------|----------|
| `run --rm -it` | Запуск временного pod |
| `debug` | Запуск debug контейнера |
| `top` | Потребление CPU/RAM |

### Контекст и конфигурация

```bash
kubectl config get-contexts
kubectl config use-context <context-name>
kubectl config set-context --current --namespace=<namespace>
kubectl config view
```

Управление kubeconfig и контекстами.

### API Resources

```bash
kubectl api-resources
kubectl api-versions
kubectl explain <resource>
kubectl explain <resource>.<field>
```

| Команда | Описание |
|---------|----------|
| `api-resources` | Список доступных типов ресурсов |
| `api-versions` | Список версий API |
| `explain` | Документация по полям ресурса |

---

## kubeadm - Управление кластером

### Инициализация кластера

```bash
kubeadm init --pod-network-cidr=<cidr>
kubeadm init --control-plane-endpoint=<endpoint>
kubeadm init --upload-certs
```

| Флаг | Описание |
|------|----------|
| `--pod-network-cidr` | CIDR для pod network |
| `--control-plane-endpoint` | Endpoint для HA кластера |
| `--apiserver-advertise-address` | IP для API server |
| `--upload-certs` | Загрузка сертификатов в кластер |

### Присоединение нод

```bash
kubeadm join <endpoint> --token <token> --discovery-token-ca-cert-hash <hash>
kubeadm join <endpoint> --token <token> --control-plane --certificate-key <key>
```

Первая команда для worker, вторая для control-plane node.

### Управление токенами

```bash
kubeadm token create
kubeadm token list
kubeadm token delete <token>
kubeadm token create --print-join-command
```

Генерация и управление токенами для присоединения нод.

### Обновление кластера

```bash
kubeadm upgrade plan
kubeadm upgrade apply <version>
kubeadm upgrade node
```

Обновление компонентов control plane.

### Сброс кластера

```bash
kubeadm reset
kubeadm reset --cleanup-tmp-dir
```

Удаление конфигурации кластера с ноды.

### Управление сертификатами

```bash
kubeadm certs check-expiration
kubeadm certs renew all
kubeadm certs renew apiserver
```

Проверка и обновление сертификатов.

---

## kubelet - Управление нодой

### Системные команды

```bash
systemctl status kubelet
systemctl restart kubelet
systemctl enable kubelet
journalctl -u kubelet -f
```

Управление systemd сервисом kubelet.

### Конфигурация

```bash
kubelet --config=<config-file>
kubelet --node-ip=<ip>
kubelet --register-node=false
```

| Параметр | Описание |
|----------|----------|
| `--config` | Путь к конфигурационному файлу |
| `--node-ip` | IP адрес ноды |
| `--register-node` | Автоматическая регистрация в кластере |
| `--kubeconfig` | Путь к kubeconfig |

### Проверка статуса

```bash
systemctl is-active kubelet
systemctl is-enabled kubelet
```

---

## kubectl plugins

### Krew - менеджер плагинов

```bash
kubectl krew install <plugin>
kubectl krew list
kubectl krew update
kubectl krew upgrade
```

Установка и управление kubectl плагинами.

### Популярные плагины

```bash
kubectl ctx
kubectl ns
kubectl node-shell <node-name>
kubectl view-secret <secret-name>
```

| Плагин | Назначение |
|--------|------------|
| `ctx` | Переключение контекстов |
| `ns` | Переключение namespace |
| `node-shell` | Shell доступ к node |
| `view-secret` | Декодирование secret |

---

## RBAC управление

### Role и RoleBinding

```bash
kubectl create role <name> --verb=<verbs> --resource=<resources>
kubectl create rolebinding <name> --role=<role> --user=<user>
kubectl create rolebinding <name> --role=<role> --serviceaccount=<namespace>:<sa>
```

Создание ролей на уровне namespace.

### ClusterRole и ClusterRoleBinding

```bash
kubectl create clusterrole <name> --verb=<verbs> --resource=<resources>
kubectl create clusterrolebinding <name> --clusterrole=<role> --user=<user>
```

Создание ролей на уровне кластера.

### Проверка прав

```bash
kubectl auth can-i <verb> <resource>
kubectl auth can-i create pods --as=<user>
kubectl auth can-i --list
```

Проверка разрешений для текущего или указанного пользователя.

---

## Network Policies

```bash
kubectl get networkpolicies
kubectl describe networkpolicy <name>
kubectl delete networkpolicy <name>
```

Управление сетевыми политиками требует CNI plugin с поддержкой NetworkPolicy (Calico, Cilium).

---

## Persistence

### PersistentVolume и PersistentVolumeClaim

```bash
kubectl get pv
kubectl get pvc
kubectl describe pv <name>
kubectl describe pvc <name>
```

Управление постоянным хранилищем.

### StorageClass

```bash
kubectl get storageclass
kubectl describe storageclass <name>
kubectl patch storageclass <name> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## Troubleshooting команды

### Диагностика

```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning
kubectl cluster-info
kubectl cluster-info dump
```

Сбор диагностической информации.

### Состояние компонентов

```bash
kubectl get componentstatuses
kubectl get nodes -o wide
kubectl describe node <node-name>
```

Проверка состояния компонентов кластера.

### Resource Quota

```bash
kubectl get resourcequota
kubectl describe resourcequota <name>
kubectl top nodes
kubectl top pods -A
```

Мониторинг потребления ресурсов.

---

## Best Practices

**Использование dry-run:**

```bash
kubectl create deployment <name> --image=<image> --dry-run=client -o yaml > deployment.yaml
```

Генерация манифестов перед применением.

**Использование labels:**

```bash
kubectl get pods -l app=<name>
kubectl delete pods -l app=<name>
```

Фильтрация ресурсов по labels для batch операций.

**Использование --watch:**

```bash
kubectl get pods -w
kubectl get events -w
```

Мониторинг изменений в реальном времени.

**Namespace isolation:**

```bash
kubectl config set-context --current --namespace=<namespace>
```

Установка namespace по умолчанию для текущего контекста.

**Экспорт манифестов:**

```bash
kubectl get <resource> <name> -o yaml --export > backup.yaml
```

Сохранение конфигурации ресурсов.

---

## Полезные алиасы

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get services'
alias kd='kubectl describe'
alias kdel='kubectl delete'
alias kl='kubectl logs'
alias kex='kubectl exec -it'
```

Сокращение часто используемых команд.