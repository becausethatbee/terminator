# Автоматизация и отладка инфраструктуры Kubernetes кластера

Итеративное улучшение Terraform и Ansible конфигурации для полной автоматизации развертывания и управления HA Kubernetes кластером в Yandex Cloud.

## Предварительные требования

**ПО:**
- Terraform >= 1.5.0 с remote state в S3
- Ansible >= 2.15.0 с базовыми roles
- just для automation commands

**Инфраструктура:**
- Yandex Cloud: 12 VM (1 bastion + 3 control plane + 8 workers)
- containerd на всех K8s нодах
- kubeadm, kubelet, kubectl v1.28.15
- SSH доступ через bastion с ProxyCommand

---

## Увеличение памяти worker нод

Изменение memory в переменных Terraform с 4GB на 8GB для обеспечения рабочих нагрузок достаточным количеством ресурсов.

Редактирование `variables.tf`:

```bash
cd ~/k8s-yandex-cloud/terraform
nano variables.tf
```

Обновление worker_resources:

```hcl
variable "worker_resources" {
  description = "Resources for worker nodes"
  type = object({
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    cores  = 2
    memory = 8  # CHANGED: увеличено с 4GB для поддержки рабочих нагрузок
    disk   = 15
  }
}
```

---

## Конфигурация Preemptible инстансов

Снижение стоимости инфраструктуры (~70% экономия) для worker нод при сохранении надежности критических компонентов.

### Worker ноды

Редактирование `workers.tf`:

```bash
nano workers.tf
```

Конфигурация worker instance:

```hcl
resource "yandex_compute_instance" "worker" {
  count = var.worker_count

  name        = "k8s-worker-${count.index + 1}"
  hostname    = "k8s-worker-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  allow_stopping_for_update = true  # CHANGED: добавлено для изменения ресурсов без пересоздания

  resources {
    cores  = var.worker_resources.cores
    memory = var.worker_resources.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.worker_resources.disk
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
    ip_address         = "10.10.0.${20 + count.index}"
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  scheduling_policy {
    preemptible = true  # CHANGED: с false на true для экономии ~70%
  }
}
```

### Control Plane

Редактирование `control-plane.tf`:

```hcl
scheduling_policy {
  preemptible = false  # KEPT: control plane должен быть всегда доступен
}
```

### Bastion

Редактирование `bastion.tf`:

```hcl
scheduling_policy {
  preemptible = false  # KEPT: bastion - единственная точка входа в кластер
}
```

**Экономия стоимости:**

| Компонент | Количество | Preemptible | Экономия |
|-----------|------------|-------------|----------|
| Bastion | 1 | Нет | 0% |
| Control Plane | 3 | Нет | 0% |
| Workers | 8 | Да | ~70% |

---

## Автоматизация генерации Ansible inventory

Использование Terraform resource `local_file` для автоматической генерации inventory вместо ручного скрипта.

### Template inventory

Создание `inventory.tpl`:

```bash
nano inventory.tpl
```

Содержимое:

```ini
[bastion]  # ADDED: новая секция для bastion с external IP
k8s-bastion ansible_host=${bastion_external_ip}

[bastion:vars]  # ADDED: vars для прямого доступа без proxy
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[control_plane]
%{ for name, ip in control_plane_ips ~}
${name} ansible_host=${ip}
%{ endfor ~}

[workers]
%{ for name, ip in worker_ips ~}
${name} ansible_host=${ip}
%{ endfor ~}

[k8s_cluster:children]
control_plane
workers

[k8s_cluster:vars]  # CHANGED: использует ProxyCommand только для K8s нод
ansible_user=ubuntu
ansible_ssh_common_args='-o ProxyCommand="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@${bastion_external_ip}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

### Terraform resource

Создание `inventory.tf`:

```hcl
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    bastion_external_ip = yandex_compute_instance.bastion.network_interface[0].nat_ip_address  # CHANGED: переименовано с bastion_ip
    control_plane_ips = {
      for idx, instance in yandex_compute_instance.control_plane :
      instance.name => instance.network_interface[0].ip_address
    }
    worker_ips = {
      for idx, instance in yandex_compute_instance.worker :
      instance.name => instance.network_interface[0].ip_address
    }
  })

  filename        = "${path.module}/../ansible/inventory/kubeadm/hosts.ini"
  file_permission = "0644"
}
```

### Обновление justfile

Редактирование `justfile`:

```makefile
deploy:
    @echo "Deploying infrastructure..."
    just apply
    just output
    just status
    # REMOVED: just update-inventory  # больше не требуется - автогенерируется Terraform

quick-deploy:
    @echo "Quick deploy (auto-approve)..."
    just apply-auto
    just all-ips
    # REMOVED: just update-inventory  # больше не требуется
```

---

## SSH конфигурация на Bastion

Автоматическое создание SSH конфигурации при развертывании bastion для устранения host key checking warnings.

Редактирование `bastion.tf`:

```hcl
resource "yandex_compute_instance" "bastion" {
  name        = "k8s-bastion"
  hostname    = "k8s-bastion"
  platform_id = "standard-v3"
  zone        = var.zone

  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
    ip_address         = "10.10.0.5"
    nat                = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  provisioner "file" {
    source      = "~/.ssh/id_ed25519"
    destination = "/home/ubuntu/.ssh/id_ed25519"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.network_interface[0].nat_ip_address
      private_key = file("~/.ssh/id_ed25519")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/ubuntu/.ssh/id_ed25519",
      "chmod 700 /home/ubuntu/.ssh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.network_interface[0].nat_ip_address
      private_key = file("~/.ssh/id_ed25519")
    }
  }

  provisioner "remote-exec" {  # ADDED: новый provisioner для SSH config
    inline = [
      "cat << 'EOF' > /home/ubuntu/.ssh/config",
      "Host 10.10.0.*",
      "    StrictHostKeyChecking no",
      "    UserKnownHostsFile /dev/null",
      "EOF",
      "chmod 600 /home/ubuntu/.ssh/config"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.network_interface[0].nat_ip_address
      private_key = file("~/.ssh/id_ed25519")
    }
  }

  scheduling_policy {
    preemptible = false
  }
}
```

---

## Применение изменений Terraform

Переход в директорию:

```bash
cd ~/k8s-yandex-cloud/terraform
source .env
```

Проверка плана изменений:

```bash
just plan
```

Terraform показывает:
- Изменение worker нод (RAM + preemptible)
- Переконфигурация bastion (provisioners)
- Создание local_file resource для inventory

Применение:

```bash
just apply-auto
```

Проверка outputs:

```bash
just all-ips
```

---

## Отладка: добавление Bastion в Inventory

### Диагностика

Проверка сгенерированного inventory:

```bash
cd ~/k8s-yandex-cloud/ansible
cat inventory/kubeadm/hosts.ini
```

Отсутствует секция `[bastion]`.

Проверка Ansible команд:

```bash
just check-haproxy
```

Ошибка: `Could not match supplied host pattern, ignoring: bastion`.

### Обновление template

Редактирование `terraform/inventory.tpl` для включения bastion секции с разделением vars для прямого доступа и ProxyCommand для K8s нод:

```ini
[bastion]  # ADDED: новая секция для прямого доступа к bastion
k8s-bastion ansible_host=${bastion_external_ip}

[bastion:vars]  # ADDED: vars без proxy для прямого подключения
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

[control_plane]
%{ for name, ip in control_plane_ips ~}
${name} ansible_host=${ip}
%{ endfor ~}

[workers]
%{ for name, ip in worker_ips ~}
${name} ansible_host=${ip}
%{ endfor ~}

[k8s_cluster:children]  # ADDED: группировка control_plane и workers
control_plane
workers

[k8s_cluster:vars]  # CHANGED: переименовано с [all:vars], использует ProxyCommand только для K8s нод
ansible_user=ubuntu
ansible_ssh_common_args='-o ProxyCommand="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@${bastion_external_ip}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

### Обновление resource

Редактирование `terraform/inventory.tf`:

```hcl
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    bastion_external_ip = yandex_compute_instance.bastion.network_interface[0].nat_ip_address  # FIXED: переименовано с bastion_ip для соответствия template
    control_plane_ips = {
      for idx, instance in yandex_compute_instance.control_plane :
      instance.name => instance.network_interface[0].ip_address
    }
    worker_ips = {
      for idx, instance in yandex_compute_instance.worker :
      instance.name => instance.network_interface[0].ip_address
    }
  })

  filename        = "${path.module}/../ansible/inventory/kubeadm/hosts.ini"
  file_permission = "0644"
}
```

Изменено: `bastion_ip` → `bastion_external_ip`.

### Регенерация inventory

```bash
source .env
just apply-auto
```

local_file ресурс пересоздается с новым содержимым. Inventory содержит все необходимые секции.

---

## Установка HAProxy на Bastion

Выполнение bastion playbook после восстановления bastion в inventory:

```bash
cd ~/k8s-yandex-cloud/ansible
just prep-bastion
```

Ansible выполняет role common и role haproxy. Результат:

```
PLAY RECAP
k8s-bastion: ok=12 changed=9 unreachable=0 failed=0 skipped=1
```

---

## Проверка статуса

### VM статус

```bash
cd ~/k8s-yandex-cloud/terraform
just status
```

Все 12 VM в статусе RUNNING.

### Connectivity

```bash
cd ~/k8s-yandex-cloud/ansible
just ping
```

Все 12 хостов доступны: bastion через direct connection, K8s ноды через ProxyCommand.

### Сервисы

Проверка HAProxy:

```bash
just check-haproxy
```

HAProxy активен. Backend серверы DOWN до инициализации Kubernetes API - это нормально.

Проверка containerd:

```bash
just check-containerd
```

Все 11 K8s нод показывают active (running).

Проверка версий:

```bash
just check-versions
```

Все ноды: kubeadm v1.28.15, kubelet v1.28.15, kubectl v1.28.15.

---

## Troubleshooting

### Inventory не содержит bastion

**Ошибка:**
```
[WARNING]: Could not match supplied host pattern, ignoring: bastion
```

**Решение:** Обновить `terraform/inventory.tpl` для включения bastion секции, затем выполнить `terraform apply`.

### HAProxy backend серверы DOWN

**Ошибка:**
```
Server k8s_control_plane/k8s-control-1 is DOWN
Connection refused at initial connection step
```

**Причина:** Kubernetes API (порт 6443) еще не запущен на control plane нодах.

**Решение:** Статус нормален до инициализации кластера. После `kubeadm init` backend серверы станут UP.

### Worker ноды не применяют изменения ресурсов

**Ошибка:** После изменения `worker_resources` в variables.tf ноды не обновляются.

**Причина:** Отсутствие `allow_stopping_for_update = true` в resource.

**Решение:** Добавить параметр в `terraform/workers.tf`:

```hcl
resource "yandex_compute_instance" "worker" {
  allow_stopping_for_update = true  # ADDED: позволяет менять ресурсы без пересоздания
}
```

Затем выполнить `terraform apply`.

### Preemptible ноды перезапускаются

**Ошибка:** Worker ноды периодически останавливаются Yandex Cloud.

**Причина:** Preemptible instances могут быть остановлены в любой момент с предупреждением за 30 секунд.

**Решение:** Использовать preemptible только для stateless workloads. Для критических сервисов установить `preemptible = false`.

---

## Best Practices

**Terraform автоматизация**

local_file resource генерирует конфигурации без ручных скриптов. Template files обеспечивают декларативный подход. Provisioners для начальной настройки выполняются один раз при создании инстанса.

**Ansible inventory**

Разделение vars для bastion и k8s_cluster обеспечивает правильную маршрутизацию SSH. ProxyCommand только для приватных нод снижает latency. Автогенерация гарантирует актуальность IP адресов после изменений инфраструктуры.

**Оптимизация стоимости**

Preemptible для stateless workers обеспечивает ~70% экономию. Regular instances для критической инфраструктуры (bastion, control plane) гарантируют доступность. allow_stopping_for_update позволяет изменять ресурсы без пересоздания.

**SSH конфигурация**

Отключение host key checking через StrictHostKeyChecking необходимо для automation. Использование null UserKnownHostsFile предотвращает конфликты при масштабировании. SSH config на bastion устраняет warnings при интерактивном использовании.

---

## Полезные команды

**Terraform:**

```bash
cd ~/k8s-yandex-cloud/terraform
source .env

just plan
just apply-auto
just all-ips
just status
just fmt
```

**Ansible:**

```bash
cd ~/k8s-yandex-cloud/ansible

just ping
just check-versions
just check-containerd
just check-haproxy
just prep-bastion

ansible all -m shell -a "uptime"
ansible k8s_cluster -m shell -a "free -h"
```

**SSH доступ:**

```bash
ssh ubuntu@<BASTION_EXTERNAL_IP>

ssh -J ubuntu@<BASTION_EXTERNAL_IP> ubuntu@10.10.0.10

ssh -J ubuntu@<BASTION_EXTERNAL_IP> ubuntu@10.10.0.20
```

**Inventory:**

```bash
cat ansible/inventory/kubeadm/hosts.ini

ansible k8s_cluster --list-hosts
ansible bastion --list-hosts
```

**Git:**

```bash
cd ~/k8s-yandex-cloud

git status
git add terraform/inventory.tpl terraform/inventory.tf
git commit -m "feat: add bastion to inventory auto-generation"
git push origin master
```

---

## Архитектура инфраструктуры

```
Internet
   ↓
[NAT Gateway]
   ↓
[Bastion - <BASTION_EXTERNAL_IP>]
   │ (HAProxy:6443 → Control Plane API)
   │
   └─ [VPC 10.10.0.0/24]
      │
      ├─ Control Plane (regular instances)
      │  ├─ k8s-control-1: 10.10.0.10
      │  ├─ k8s-control-2: 10.10.0.11
      │  └─ k8s-control-3: 10.10.0.12
      │
      └─ Workers (preemptible instances)
         ├─ k8s-worker-1: 10.10.0.20
         ├─ k8s-worker-2: 10.10.0.21
         ├─ k8s-worker-3: 10.10.0.22
         ├─ k8s-worker-4: 10.10.0.23
         ├─ k8s-worker-5: 10.10.0.24
         ├─ k8s-worker-6: 10.10.0.25
         ├─ k8s-worker-7: 10.10.0.26
         └─ k8s-worker-8: 10.10.0.27
```

---

## Использование ресурсов

**Конфигурация:**

| Компонент | Количество | vCPU | RAM | Disk | Preemptible | IP |
|-----------|------------|------|-----|------|-------------|-----|
| Bastion | 1 | 2 | 2GB | 10GB | Нет | External |
| Control Plane | 3 | 4 | 8GB | 20GB | Нет | Private |
| Workers | 8 | 2 | 8GB | 15GB | Да | Private |
| **Итого** | **12** | **30** | **90GB** | **190GB** | - | **1 external** |

**Квоты Yandex Cloud:**

| Ресурс | Используется | Лимит | Процент |
|--------|--------------|-------|---------|
| VM instances | 12 | 12 | 100% |
| vCPU | 30 | 32 | 93.75% |
| RAM | 90GB | 128GB | 70.3% |
| SSD disks | 190GB | 200GB | 95% |

---

## Статус готовности компонентов

| Компонент | Статус |
|-----------|--------|
| Terraform infrastructure | Развернуто |
| Ansible inventory | Автогенерируется |
| SSH connectivity | Настроено |
| Bastion HAProxy | Установлено |
| Containerd | Запущено |
| Kubeadm/kubelet/kubectl | Установлены (v1.28.15) |
| Preemptible optimization | Активировано |
| RAM upgrade | Применено |

Инфраструктура подготовлена к инициализации Kubernetes кластера через kubeadm, установке CNI plugin и подключению worker нод.
