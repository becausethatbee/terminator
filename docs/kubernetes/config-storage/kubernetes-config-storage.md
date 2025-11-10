# Kubernetes: ConfigMap, Secret, Volumes и хранилище

Документ описывает работу с конфигурацией приложений и системами хранения данных в Kubernetes: ConfigMap для конфигурации, Secret для конфиденциальных данных, типы Volumes для обмена данными, PersistentVolume/PersistentVolumeClaim для постоянного хранилища и StorageClass для динамического выделения ресурсов.

## Предварительные требования

- Kubernetes кластер (Minikube)
- kubectl CLI
- Базовые знания YAML манифестов

---

## Обзор компонентов

| Компонент | Назначение | Тип данных | Способ подключения | Особенности |
|-----------|------------|------------|-------------------|-------------|
| ConfigMap | Хранение конфигурационных данных в формате ключ-значение | Конфигурация | Переменные окружения, файлы, аргументы командной строки | Не предназначен для секретной информации, данные в открытом виде |
| Secret | Безопасное хранение чувствительных данных (пароли, токены, ключи) | Чувствительные данные | Переменные окружения, файлы, аргументы командной строки | Шифруются в etcd, значения хранятся в Base64 |
| Volumes | Совместное использование данных между контейнерами в одном поде | Временные или локальные данные | volumeMounts в контейнере | Содержимое Volumes исчезает после удаления пода (для emptyDir) или зависит от типа хранилища |
| Persistent Volume (PV) | Ресурс хранилища, предоставляемый кластером, для хранения данных | Постоянные данные | PVC подключает PV к подам | Создается администратором; определяет объем и параметры хранилища |
| Persistent Volume Claim (PVC) | Запрос пользователя на использование PV | Постоянные данные | Используется в разделе volumes в поде | Упрощает работу с PV; позволяет запросить нужный объем и параметры доступа |
| StorageClass | Шаблон для динамического выделения PV с заданными параметрами | Постоянные данные | Автоматически создается на основе PVC | Позволяет автоматизировать создание PV, особенно полезен в облачных средах |

---

## ConfigMap

### Создание ConfigMap

ConfigMap хранит конфигурационные данные в виде пар ключ-значение.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_NAME: "MyWebApp"
  APP_PORT: "8080"
```

Применение манифеста:

```bash
kubectl apply -f app-config.yaml
kubectl get configmap app-config
```

### Использование через переменные окружения

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app-container
    image: busybox
    command: ['sh', '-c', 'echo "App Name: $APP_NAME" && echo "App Port: $APP_PORT" && sleep 3600']
    env:
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_NAME
    - name: APP_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_PORT
```

Контейнер получает значения APP_NAME и APP_PORT из ConfigMap как переменные окружения.

Проверка:

```bash
kubectl apply -f pod-with-config.yaml
kubectl logs app-pod
```

### Монтирование как Volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-config-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do cat /config/APP_NAME; cat /config/APP_PORT; sleep 10; done']
    volumeMounts:
    - name: config-volume
      mountPath: /config
  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

Каждый ключ ConfigMap становится файлом в директории /config. Изменения ConfigMap автоматически отражаются в контейнере.

Обновление ConfigMap:

```bash
kubectl patch configmap app-config -p '{"data":{"APP_NAME":"UpdatedWebApp","APP_PORT":"9090"}}'
```

Изменения применяются без перезапуска пода в течение 30-60 секунд.

---

## Secret

### Создание Secret

Secret хранит конфиденциальные данные в кодировке base64.

```bash
kubectl create secret generic db-secret \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=secretpass123
```

Проверка:

```bash
kubectl get secret db-secret
```

### Использование через переменные окружения

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
spec:
  containers:
  - name: db-container
    image: busybox
    command: ['sh', '-c', 'echo "DB User: $DB_USER" && sleep 3600']
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: DB_USER
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: DB_PASSWORD
```

Проверка:

```bash
kubectl apply -f pod-with-secret.yaml
kubectl logs db-pod
```

### Монтирование как Volume

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-secret-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'while true; do cat /secret/DB_USER; cat /secret/DB_PASSWORD; sleep 10; done']
    volumeMounts:
    - name: secret-volume
      mountPath: /secret
  volumes:
  - name: secret-volume
    secret:
      secretName: db-secret
```

Обновление Secret:

```bash
kubectl delete secret db-secret
kubectl create secret generic db-secret \
  --from-literal=DB_USER=superadmin \
  --from-literal=DB_PASSWORD=newsecretpass456
```

Изменения применяются автоматически без перезапуска пода.

---

## Volumes

### emptyDir

Временное хранилище, существующее в течение жизненного цикла пода. Используется для обмена данными между контейнерами.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do echo "$(date): Data from writer" >> /data/shared.log; sleep 5; done']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: reader
    image: busybox
    command: ['sh', '-c', 'while true; do cat /data/shared.log 2>/dev/null; sleep 10; done']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  volumes:
  - name: shared-data
    emptyDir: {}
```

Оба контейнера монтируют один Volume на /data. Writer записывает данные, Reader их читает.

Проверка:

```bash
kubectl apply -f pod-with-volume.yaml
kubectl logs shared-volume-pod -c reader
```

**Особенности emptyDir:**
- Создается при создании пода
- Удаляется при удалении пода
- Не сохраняется между перезапусками
- Размещается на диске ноды

---

## PersistentVolume и PersistentVolumeClaim

### Архитектура

| Компонент | Описание | Создается |
|-----------|----------|-----------|
| PersistentVolume (PV) | Ресурс хранения в кластере | Администратором или динамически |
| PersistentVolumeClaim (PVC) | Запрос на хранилище от пода | Пользователем |
| StorageClass | Описывает типы хранилища | Администратором |

### Создание PersistentVolume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/k8s-pv-data
```

Применение:

```bash
kubectl apply -f pv.yaml
kubectl get pv
```

### Режимы доступа

| Режим | Описание |
|-------|----------|
| ReadWriteOnce (RWO) | Монтируется для чтения/записи одной нодой |
| ReadOnlyMany (ROX) | Монтируется только для чтения множеством нод |
| ReadWriteMany (RWX) | Монтируется для чтения/записи множеством нод |

### Создание PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

Kubernetes автоматически связывает PVC с подходящим PV.

Применение:

```bash
kubectl apply -f pvc.yaml
kubectl get pvc
```

### Использование PVC в поде

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Persistent data: $(date)" > /data/persistent.txt && cat /data/persistent.txt && sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: task-pvc
```

Под монтирует PVC на /data. Данные сохраняются на PV независимо от жизненного цикла пода.

Проверка:

```bash
kubectl apply -f pod-with-pvc.yaml
kubectl logs pvc-pod
```

---

## StorageClass

### Динамическое выделение хранилища

StorageClass автоматически создает PV при запросе PVC.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: k8s.io/minikube-hostpath
parameters:
  type: pd-ssd
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

Параметры StorageClass:

| Параметр | Значение | Описание |
|----------|----------|----------|
| provisioner | k8s.io/minikube-hostpath | Плагин создания PV |
| reclaimPolicy | Delete | Политика удаления PV при удалении PVC |
| volumeBindingMode | Immediate | Немедленное создание PV при создании PVC |

Применение:

```bash
kubectl apply -f storageclass.yaml
kubectl get storageclass
```

### Создание PVC с StorageClass

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fast-pvc
spec:
  storageClassName: fast-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

PV создается автоматически через provisioner.

Применение:

```bash
kubectl apply -f pvc-with-sc.yaml
kubectl get pvc fast-pvc
kubectl get pv
```

### Использование в поде

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fast-storage-pod
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Fast storage data: $(date)" > /data/fast.txt && sleep 3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: fast-pvc
```

---

## Политики удаления PersistentVolume

### ReclaimPolicy

| Политика | Поведение при удалении PVC |
|----------|----------------------------|
| Retain | PV остается Available, требуется ручная очистка |
| Delete | PV автоматически удаляется вместе с данными |
| Recycle | PV очищается и становится доступен для повторного использования (deprecated) |

### Проверка политики удаления

Запись данных:

```bash
kubectl exec pvc-pod -- sh -c "echo 'Test data' > /data/test-file.txt"
```

Получение имени PV:

```bash
kubectl get pvc task-pvc -o yaml | grep volumeName
```

Удаление PVC:

```bash
kubectl delete pod pvc-pod
kubectl delete pvc task-pvc
kubectl get pv
```

**Результат:**
- PV с политикой Delete удаляется вместе с PVC
- PV с политикой Retain остается в статусе Released

---

## Troubleshooting

### ConfigMap не обновляется в поде

**Проблема:**
Изменения ConfigMap не применяются в контейнере при использовании переменных окружения.

**Причина:**
Переменные окружения устанавливаются при запуске контейнера и не обновляются динамически.

**Решение:**
Использовать монтирование ConfigMap как Volume вместо переменных окружения.

### PVC в статусе Pending

**Проблема:**
```
NAME       STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
task-pvc   Pending                                      standard
```

**Причина:**
Нет доступного PV с подходящими параметрами или отсутствует StorageClass.

**Решение:**
```bash
kubectl describe pvc task-pvc
kubectl get storageclass
kubectl get pv
```

Создать PV с соответствующими параметрами или использовать StorageClass для динамического создания.

### Permission denied при записи в Volume

**Проблема:**
```
sh: can't create /data/file.txt: Permission denied
```

**Причина:**
Несоответствие прав доступа между контейнером и Volume.

**Решение:**
Добавить securityContext в спецификацию контейнера:

```yaml
spec:
  containers:
  - name: app
    securityContext:
      runAsUser: 1000
      fsGroup: 1000
```

### Secret не декодируется

**Проблема:**
Значения Secret отображаются в base64 при чтении файлов.

**Причина:**
При монтировании Secret как Volume, Kubernetes автоматически декодирует значения.

**Решение:**
Проверить что Secret смонтирован корректно. Значения должны быть декодированы автоматически.

---

## Best Practices

**Выбор между переменными окружения и Volume:**
- Переменные окружения для статической конфигурации
- Volume для конфигурации, требующей динамического обновления

**Использование StorageClass:**
- Создавать StorageClass для разных типов хранилища (SSD, HDD)
- Использовать параметр default для автоматического выбора StorageClass

**Политики удаления:**
- Retain для production данных требующих ручного контроля
- Delete для temporary данных и development окружения

**Размер хранилища:**
- PVC может запрашивать меньше чем предоставляет PV
- PVC не может запросить больше чем capacity PV
- Использовать StorageClass для гибкого выделения

**Безопасность Secret:**
- Не использовать Secret в командах (отображаются в истории)
- Монтировать Secret как Volume вместо переменных окружения для чувствительных данных
- Использовать RBAC для ограничения доступа к Secret

**Именование:**
- Использовать описательные имена для ConfigMap и Secret
- Включать версию или окружение в имя при необходимости
- Избегать generic имен типа "config" или "secret"

---

## Полезные команды

### ConfigMap

```bash
# Создание из литералов
kubectl create configmap app-config --from-literal=KEY=VALUE

# Создание из файла
kubectl create configmap app-config --from-file=config.properties

# Просмотр содержимого
kubectl get configmap app-config -o yaml

# Обновление значения
kubectl patch configmap app-config -p '{"data":{"KEY":"NEW_VALUE"}}'

# Удаление
kubectl delete configmap app-config
```

### Secret

```bash
# Создание из литералов
kubectl create secret generic db-secret --from-literal=USER=admin

# Создание из файла
kubectl create secret generic db-secret --from-file=credentials.txt

# Просмотр (base64 закодировано)
kubectl get secret db-secret -o yaml

# Декодирование значения
kubectl get secret db-secret -o jsonpath='{.data.USER}' | base64 -d

# Удаление
kubectl delete secret db-secret
```

### PersistentVolume и PVC

```bash
# Список PV
kubectl get pv

# Список PVC
kubectl get pvc

# Детальная информация PVC
kubectl describe pvc task-pvc

# Удаление PVC
kubectl delete pvc task-pvc

# Принудительное удаление PV
kubectl delete pv task-pv --grace-period=0 --force
```

### StorageClass

```bash
# Список StorageClass
kubectl get storageclass

# Установка default StorageClass
kubectl patch storageclass standard -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Детальная информация
kubectl describe storageclass fast-storage
```

### Отладка Volume

```bash
# Проверка монтирования в поде
kubectl exec pod-name -- df -h

# Просмотр файлов в Volume
kubectl exec pod-name -- ls -la /mount/path

# Запись данных для тестирования
kubectl exec pod-name -- sh -c "echo test > /mount/path/file.txt"

# События пода (ошибки монтирования)
kubectl describe pod pod-name
```
