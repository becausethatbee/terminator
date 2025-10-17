# Kubernetes QoS Classes и управление ресурсами

Управление ресурсами контейнеров через requests/limits и механизм QoS классов для приоритизации подов при нехватке ресурсов на узле.

## Предварительные требования

- Kubernetes кластер (v1.20+)
- kubectl CLI
- Права на создание подов в namespace
- metrics-server для мониторинга ресурсов

---

## QoS классы

Kubernetes автоматически назначает один из трёх QoS классов каждому поду на основе конфигурации resources.

### QoS Guaranteed

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-guaranteed-pod
spec:
  containers:
  - name: nginx-container
    image: nginx:latest
    resources:
      requests:
        memory: "500Mi"
        cpu: "500m"
      limits:
        memory: "500Mi"
        cpu: "500m"
```

Класс Guaranteed назначается когда requests = limits для всех контейнеров. Обеспечивает максимальный приоритет - поды не вытесняются до превышения собственных limits.

### QoS Burstable

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-burstable-pod
spec:
  containers:
  - name: nginx-stable
    image: nginx:stable
    resources:
      requests:
        memory: "300Mi"
        cpu: "200m"
      limits:
        memory: "600Mi"
        cpu: "500m"
  - name: busybox-sleep
    image: busybox
    command: ["sleep", "3600"]
    resources:
      requests:
        memory: "100Mi"
        cpu: "50m"
      limits:
        memory: "200Mi"
        cpu: "150m"
```

Класс Burstable назначается когда requests < limits. Контейнеры могут использовать ресурсы сверх requests до limits, но имеют средний приоритет при нехватке ресурсов.

### QoS BestEffort

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-besteffort-pod
spec:
  containers:
  - name: busybox-sleep
    image: busybox
    command: ["sleep", "3600"]
```

Класс BestEffort назначается при отсутствии секции resources. Самый низкий приоритет - первые кандидаты на завершение при нехватке ресурсов на узле.

### Валидация QoS класса

```bash
kubectl get pod <pod-name> -o jsonpath='{.status.qosClass}'
```

Значение qosClass автоматически устанавливается в метаданных пода после создания.

---

## Механизм распределения ресурсов

### Requests и scheduler

Scheduler использует requests для принятия решения о размещении пода на узле. Под размещается только если суммарные requests всех подов не превышают allocatable ресурсы узла.

```bash
kubectl describe node <node-name> | grep -A 5 "Allocatable:"
kubectl describe node <node-name> | grep -A 20 "Allocated resources:"
```

Пример вывода:

```
Allocatable:
  cpu:                2
  memory:             3977088Ki

Allocated resources:
  Resource           Requests      Limits
  --------           --------      ------
  cpu                2 (100%)      1850m (92%)
  memory             1670Mi (42%)  2170Mi (55%)
```

Если requests превышают allocatable, под остаётся в статусе Pending.

### Манифест для тестирования

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod1-high-requests
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "300Mi"
        cpu: "300m"
      limits:
        memory: "500Mi"
        cpu: "500m"
---
apiVersion: v1
kind: Pod
metadata:
  name: pod2-low-requests
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "200Mi"
        cpu: "200m"
```

### Нагрузочное тестирование

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: stress-pod1
spec:
  containers:
  - name: stress
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "0"]
    resources:
      requests:
        memory: "300Mi"
        cpu: "300m"
      limits:
        memory: "500Mi"
        cpu: "500m"
```

Мониторинг потребления ресурсов:

```bash
kubectl top pods
```

---

## OOM Killer

### Механизм работы

Kubernetes завершает контейнер через OOM killer когда потребление памяти превышает limits. Контейнер автоматически перезапускается согласно restartPolicy.

### Манифест для тестирования OOM

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-test-pod
spec:
  containers:
  - name: stress-oom
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "0"]
    resources:
      requests:
        memory: "100Mi"
      limits:
        memory: "200Mi"
```

Контейнер пытается выделить 250Mi при limits 200Mi, что гарантированно вызывает OOM.

### Диагностика OOM событий

Проверка статуса пода:

```bash
kubectl get pod oom-test-pod
```

Вывод при OOM:

```
NAME           READY   STATUS      RESTARTS   AGE
oom-test-pod   0/1     OOMKilled   3          2m
```

Детальная информация о завершении:

```bash
kubectl describe pod oom-test-pod | grep -A 10 "Last State"
```

Пример вывода:

```
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    1
  Started:      Fri, 17 Oct 2025 15:53:15 +0300
  Finished:     Fri, 17 Oct 2025 15:53:15 +0300
```

События кластера:

```bash
kubectl get events --sort-by='.lastTimestamp' | grep -i oom
```

---

## Приоритет завершения подов

При нехватке памяти на узле Kubernetes завершает поды в следующем порядке:

| Приоритет | QoS Class | Условие завершения |
|-----------|-----------|-------------------|
| 1 (низкий) | BestEffort | Первыми при любой нехватке памяти |
| 2 (средний) | Burstable | Если использует больше requests |
| 3 (высокий) | Guaranteed | Только при превышении собственных limits |

---

## Troubleshooting

### Pod в статусе Pending

**Причина:** Недостаточно ресурсов на узле.

**Диагностика:**

```bash
kubectl describe pod <pod-name> | grep -A 10 Events
```

**Решение:** Снизить requests или масштабировать кластер.

### Частые рестарты с OOMKilled

**Причина:** Контейнер систематически превышает memory limits.

**Диагностика:**

```bash
kubectl describe pod <pod-name> | grep "Restart Count"
kubectl top pod <pod-name>
```

**Решение:** Увеличить memory limits или оптимизировать приложение.

### Неожиданное завершение BestEffort подов

**Причина:** Узел испытывает memory pressure.

**Диагностика:**

```bash
kubectl describe node <node-name> | grep MemoryPressure
```

**Решение:** Установить requests/limits или добавить ресурсы узлу.

---

## Best Practices

**Requests и Limits:**
- Всегда устанавливать requests для продакшн подов
- Limits = Requests для критичных сервисов (Guaranteed)
- Limits > Requests для batch задач (Burstable)

**Мониторинг:**
- Регулярно проверять `kubectl top pods` и `kubectl top nodes`
- Настроить алерты на MemoryPressure и DiskPressure узлов
- Отслеживать метрики OOMKilled в системе мониторинга

**Тестирование:**
- Проверять поведение приложения при достижении limits
- Использовать stress-тесты перед продакшн deployment
- Документировать оптимальные значения requests/limits

**Архитектура:**
- Избегать BestEffort для stateful приложений
- Использовать PriorityClass для критичных подов
- Планировать запас ресурсов на узлах (20-30%)

---

## Полезные команды

```bash
# Проверка QoS класса
kubectl get pod <pod-name> -o jsonpath='{.status.qosClass}'

# Мониторинг ресурсов
kubectl top pods
kubectl top nodes

# Информация о ресурсах узла
kubectl describe node <node-name> | grep -A 5 "Allocatable:"
kubectl describe node <node-name> | grep -A 20 "Allocated resources:"

# События пода
kubectl describe pod <pod-name> | grep -A 10 Events

# История завершений контейнера
kubectl describe pod <pod-name> | grep -A 10 "Last State"

# Системные события кластера
kubectl get events --sort-by='.lastTimestamp'

# Логи предыдущего контейнера
kubectl logs <pod-name> --previous

# Удаление подов
kubectl delete pod <pod-name>
```
