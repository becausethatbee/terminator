# Исправления и автоматизация инфраструктуры Kubernetes

Исправления и дополнения к базовой конфигурации из Infrastructure Setup и Infrastructure Prep. Применяется после развертывания базовой инфраструктуры для оптимизации стоимости, повышения отказоустойчивости и улучшения автоматизации.

## Изменения в variables.tf

### Зона и платформа

```hcl
variable "zone" {
  description = "Yandex Cloud Zone"
  type        = string
  default     = "ru-central1-a"  # CHANGED: с ru-central1-d - platform standard-v1 недоступен в зоне d
}

variable "platform_id" {  # ADDED: новая переменная для единообразия платформы
  description = "Yandex Cloud Platform ID"
  type        = string
  default     = "standard-v1"  # CHANGED: с standard-v3 - требование зоны
}

variable "disk_type" {  # ADDED: новая переменная для типа диска
  description = "Boot disk type"
  type        = string
  default     = "network-ssd"  # CHANGED: с network-ssd-nonreplicated - ошибка размера диска
}
```

### Количество нод

```hcl
variable "bastion_count" {  # ADDED: новая переменная для HA bastion
  description = "Number of bastion nodes (HA)"
  type        = number
  default     = 2  # CHANGED: с 1 - добавлен secondary bastion для отказоустойчивости
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 7  # CHANGED: с 8 - оптимизация под квоты
}
```

### Ресурсы worker нод

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
    memory = 8  # CHANGED: с 4GB - увеличено для поддержки рабочих нагрузок
    disk   = 15
  }
}
```

---

## Изменения в bastion.tf

### HA Bastion конфигурация

```hcl
resource "yandex_compute_instance" "bastion" {
  count = var.bastion_count  # CHANGED: с единичного ресурса на count-based для HA

  name        = "k8s-bastion-${count.index + 1}"  # CHANGED: добавлен индекс в имя
  hostname    = "k8s-bastion-${count.index + 1}"
  platform_id = var.platform_id  # CHANGED: с hardcoded "standard-v3"
  zone        = var.zone

  allow_stopping_for_update = true  # ADDED: для изменения ресурсов без пересоздания

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = var.disk_type  # CHANGED: с hardcoded "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
    ip_address         = "10.10.0.${5 + count.index}"  # CHANGED: bastion-1: .5, bastion-2: .6
    nat                = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  # KEPT: provisioners для SSH ключа
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

  provisioner "remote-exec" {  # ADDED: автоматическая настройка SSH config
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
    preemptible = false  # CHANGED: с true - bastion критичен для доступа
  }
}
```

**IP адресация bastion:**
- k8s-bastion-1 (primary): 10.10.0.5
- k8s-bastion-2 (secondary): 10.10.0.6

---

## Изменения в control-plane.tf

```hcl
resource "yandex_compute_instance" "control_plane" {
  count       = var.control_plane_count
  platform_id = var.platform_id  # CHANGED: с hardcoded "standard-v3"
  zone        = var.zone

  name     = "k8s-control-${count.index + 1}"
  hostname = "k8s-control-${count.index + 1}"

  allow_stopping_for_update = true  # ADDED: для изменения ресурсов без пересоздания

  resources {
    cores  = var.control_plane_resources.cores
    memory = var.control_plane_resources.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.control_plane_resources.disk
      type     = var.disk_type  # CHANGED: с hardcoded "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
    ip_address         = "10.10.0.${10 + count.index}"  # ADDED: фиксированные IP
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  # scheduling_policy НЕ добавлять - control plane должен быть стабильным
}
```

**IP адресация control plane:**
- k8s-control-1: 10.10.0.10
- k8s-control-2: 10.10.0.11
- k8s-control-3: 10.10.0.12

---

## Изменения в workers.tf

```hcl
resource "yandex_compute_instance" "worker" {
  count = var.worker_count  # CHANGED: 7 вместо 8

  name        = "k8s-worker-${count.index + 1}"
  hostname    = "k8s-worker-${count.index + 1}"
  platform_id = var.platform_id  # CHANGED: с hardcoded "standard-v3"
  zone        = var.zone

  allow_stopping_for_update = true  # ADDED: для изменения ресурсов без пересоздания

  resources {
    cores  = var.worker_resources.cores
    memory = var.worker_resources.memory  # CHANGED: 8GB вместо 4GB
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.worker_resources.disk
      type     = var.disk_type  # CHANGED: с hardcoded "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
    ip_address         = "10.10.0.${20 + count.index}"  # ADDED: фиксированные IP
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  scheduling_policy {
    preemptible = true  # CHANGED: с false - экономия на stateless workers
  }
}
```

**IP адресация workers:**
- k8s-worker-1: 10.10.0.20
- k8s-worker-2: 10.10.0.21
- k8s-worker-3: 10.10.0.22
- k8s-worker-4: 10.10.0.23
- k8s-worker-5: 10.10.0.24
- k8s-worker-6: 10.10.0.25
- k8s-worker-7: 10.10.0.26

---

## Изменения в outputs.tf

```hcl
output "bastion_ips" {  # ADDED: новый output для всех bastion нод
  description = "All bastion nodes IPs"
  value = {
    for idx, instance in yandex_compute_instance.bastion :
    instance.name => {
      external_ip = instance.network_interface[0].nat_ip_address
      internal_ip = instance.network_interface[0].ip_address
    }
  }
}

output "bastion_ip" {
  description = "Primary bastion IP"
  value = {
    external_ip = yandex_compute_instance.bastion[0].network_interface[0].nat_ip_address  # CHANGED: добавлен [0] для count-based ресурса
    internal_ip = yandex_compute_instance.bastion[0].network_interface[0].ip_address
  }
}

# control_plane_ips и worker_ips без изменений
```

---

## Автогенерация Inventory через Terraform

### inventory.tf (замена generate-inventory.sh)

```hcl
# ADDED: замена bash скрипта на Terraform resource
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    bastion_external_ip = yandex_compute_instance.bastion[0].network_interface[0].nat_ip_address  # FIXED: bastion[0] для count-based
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

### inventory.tpl

```ini
# ADDED: новый template для Ansible inventory

[bastion]  # ADDED: секция bastion с прямым доступом
k8s-bastion ansible_host=${bastion_external_ip}

[bastion:vars]  # ADDED: vars без proxy для bastion
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

[k8s_cluster:vars]  # CHANGED: ProxyCommand только для K8s нод
ansible_user=ubuntu
ansible_ssh_common_args='-o ProxyCommand="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@${bastion_external_ip}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

### kubespray-inventory.tf

```hcl
# ADDED: автогенерация kubespray inventory
resource "local_file" "kubespray_inventory" {
  content = templatefile("${path.module}/kubespray-inventory.tpl", {
    bastion_external_ip = yandex_compute_instance.bastion[0].network_interface[0].nat_ip_address  # FIXED: bastion[0]
    control_plane_ips = {
      for idx, instance in yandex_compute_instance.control_plane :
      instance.name => instance.network_interface[0].ip_address
    }
    worker_ips = {
      for idx, instance in yandex_compute_instance.worker :
      instance.name => instance.network_interface[0].ip_address
    }
  })

  filename        = "${path.module}/../kubespray/inventory/mycluster/hosts.yaml"
  file_permission = "0644"
}
```

### kubespray-inventory.tpl

```yaml
# ADDED: template для kubespray inventory
all:
  hosts:
%{ for name, ip in control_plane_ips ~}
    ${name}:
      ansible_host: ${ip}
      ip: ${ip}
%{ endfor ~}
%{ for name, ip in worker_ips ~}
    ${name}:
      ansible_host: ${ip}
      ip: ${ip}
%{ endfor ~}
  children:
    kube_control_plane:
      hosts:
%{ for name, ip in control_plane_ips ~}
        ${name}:
%{ endfor ~}
    kube_node:
      hosts:
%{ for name, ip in worker_ips ~}
        ${name}:
%{ endfor ~}
    etcd:
      hosts:
%{ for name, ip in control_plane_ips ~}
        ${name}:
%{ endfor ~}
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
  vars:
    ansible_user: ubuntu
    ansible_ssh_common_args: '-o ProxyCommand="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@${bastion_external_ip}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

---

## Обновление terraform/justfile

### Команда all-ips для dual bastion

```makefile
all-ips:
    @echo "=== Bastion Nodes ==="
    @terraform output -json bastion_ips | jq -r 'to_entries[] | .key + ":\n  External: " + .value.external_ip + "\n  Internal: " + .value.internal_ip'  # CHANGED: показывает ОБА bastion
    @echo ""
    @echo "=== Control Plane ==="
    @terraform output -json control_plane_ips | jq -r 'to_entries[] | .key + ": " + .value'
    @echo ""
    @echo "=== Workers ==="
    @terraform output -json worker_ips | jq -r 'to_entries[] | .key + ": " + .value'
```

### Команда clean-ssh для dual bastion

```makefile
clean-ssh:  # CHANGED: обновлен диапазон IP для 2 bastion и 7 workers
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Cleaning SSH known_hosts..."
    
    # Primary bastion
    BASTION_IP=$(terraform output -json bastion_ip 2>/dev/null | jq -r '.external_ip' 2>/dev/null || echo "")
    if [ -n "$BASTION_IP" ]; then 
        ssh-keygen -R "$BASTION_IP" 2>/dev/null || true
    fi
    
    # All bastion nodes  # ADDED: очистка для всех bastion
    BASTION_IPS=$(terraform output -json bastion_ips 2>/dev/null | jq -r '.[].external_ip' 2>/dev/null || echo "")
    for ip in $BASTION_IPS; do
        ssh-keygen -R "$ip" 2>/dev/null || true
    done
    
    # Internal IPs  # CHANGED: обновлен диапазон
    for ip in 10.10.0.{5,6,10,11,12,20,21,22,23,24,25,26}; do  # 2 bastion + 3 control + 7 workers
        ssh-keygen -R "$ip" 2>/dev/null || true
    done
    
    echo "SSH keys cleaned"
```

### Удаление update-inventory из deploy

```makefile
deploy:
    @echo "Deploying infrastructure..."
    just apply
    just output
    just status
    # REMOVED: just update-inventory - автогенерируется Terraform

quick-deploy:
    @echo "Quick deploy (auto-approve)..."
    just apply-auto
    just all-ips
    # REMOVED: just update-inventory - автогенерируется Terraform
```

---

## Исправления kubespray/justfile

### Команда check

**Проблема:** Сложный парсинг YAML через grep/awk ненадежен.

```makefile
# BEFORE (не работает):
check:
    CONTROL_IP=$(grep -A 1 "kube_control_plane:" inventory/mycluster/hosts.yaml | ...)
    BASTION_IP=$(grep "ansible_ssh_common_args:" inventory/mycluster/hosts.yaml | ...)
    ssh -J ubuntu@$BASTION_IP ubuntu@$(...) "kubectl get nodes"

# AFTER (исправлено):
check:  # FIXED: использование Terraform outputs вместо парсинга YAML
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking cluster status..."
    source venv/bin/activate
    echo "Available Bastion nodes:"  # ADDED: показ всех bastion
    cd ../terraform
    source .env
    /usr/local/bin/terraform output -json bastion_ips | jq -r 'to_entries[] | "  " + .key + ": " + .value.external_ip'
    echo ""
    BASTION_IP=$(/usr/local/bin/terraform output -json bastion_ip | jq -r '.external_ip')
    echo "Using primary bastion: $BASTION_IP"
    echo "Connecting to first control plane node..."
    ssh -J ubuntu@$BASTION_IP ubuntu@10.10.0.10 "kubectl get nodes"  # FIXED: hardcoded IP первой control plane
```

### Команда setup-kubeconfig

**Проблема:** Ad-hoc команды не валидируют результат.

```makefile
# BEFORE (ненадежно):
setup-kubeconfig:
    ansible control_plane -m shell -a "mkdir -p /home/ubuntu/.kube"
    ansible control_plane -m copy -a "src=/etc/kubernetes/admin.conf dest=/home/ubuntu/.kube/config ..."

# AFTER (исправлено):
setup-kubeconfig:  # FIXED: использование dedicated playbook с валидацией
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Setting up kubeconfig on control plane nodes..."
    source venv/bin/activate
    ansible-playbook -i inventory/mycluster/hosts.yaml playbooks/kubeconfig-setup.yml
```

### Playbook kubeconfig-setup.yml

```yaml
# ADDED: dedicated playbook для настройки kubeconfig
---
- name: Setup kubeconfig for ubuntu user on control plane nodes
  hosts: kube_control_plane
  become: true
  tasks:
    - name: Create .kube directory
      ansible.builtin.file:
        path: /home/ubuntu/.kube
        state: directory
        owner: ubuntu
        group: ubuntu
        mode: '0755'

    - name: Copy admin.conf to user kubeconfig
      ansible.builtin.copy:
        src: /etc/kubernetes/admin.conf
        dest: /home/ubuntu/.kube/config
        remote_src: true
        owner: ubuntu
        group: ubuntu
        mode: '0600'

    - name: Verify kubectl works  # ADDED: валидация результата
      ansible.builtin.command: kubectl get nodes
      become: false
      register: kubectl_result
      changed_when: false

    - name: Display cluster status
      ansible.builtin.debug:
        var: kubectl_result.stdout_lines
```

Создание директории:

```bash
mkdir -p ~/k8s-yandex-cloud/kubespray/playbooks
```

---

## Стоимость инфраструктуры

Platform: standard-v1 (Intel Broadwell), Zone: ru-central1-a

| Компонент | Кол-во | vCPU | RAM | Disk | Preemptible | $/час |
|-----------|--------|------|-----|------|-------------|-------|
| Bastion | 2 | 2 | 2GB | 10GB | Нет | $0.052 |
| Control Plane | 3 | 4 | 8GB | 20GB | Нет | $0.196 |
| Workers | 7 | 2 | 8GB | 15GB | Да | $0.098 |
| **Итого** | **12** | **30** | **82GB** | **185GB** | - | **$0.346** |

**Стоимость: $0.35/час, ~$249/мес**

---

## Сводка изменений

### Terraform

| Файл | Изменение | Причина |
|------|-----------|---------|
| variables.tf | zone: d → a | Platform v1 недоступен в d |
| variables.tf | platform_id: v3 → v1 | Требование зоны |
| variables.tf | disk_type: nonreplicated → ssd | Ошибка размера |
| variables.tf | bastion_count: 1 → 2 | HA |
| variables.tf | worker_count: 8 → 7 | Оптимизация квот |
| variables.tf | worker_memory: 4 → 8 | Рабочие нагрузки |
| bastion.tf | count-based ресурс | HA bastion |
| bastion.tf | SSH config provisioner | Устранение warnings |
| bastion.tf | preemptible: true → false | Критичность для доступа |
| workers.tf | preemptible: false → true | Экономия ~70% |
| workers.tf | Фиксированные IP | Предсказуемость |
| outputs.tf | bastion_ips output | Dual bastion support |
| inventory.tf | local_file resource | Замена bash скрипта |
| kubespray-inventory.tf | local_file resource | Автогенерация |

### Justfile

| Файл | Команда | Изменение |
|------|---------|-----------|
| terraform/justfile | all-ips | Показ обоих bastion |
| terraform/justfile | clean-ssh | Диапазон для 2+3+7 нод |
| terraform/justfile | deploy | Удален update-inventory |
| kubespray/justfile | check | Terraform outputs вместо grep |
| kubespray/justfile | setup-kubeconfig | Dedicated playbook |

---

## Итоговая архитектура

```
Internet
   ↓
[NAT Gateway]
   ↓
[Bastion HA]
   ├─ k8s-bastion-1: <EXTERNAL_IP_1> / 10.10.0.5 (primary)
   └─ k8s-bastion-2: <EXTERNAL_IP_2> / 10.10.0.6 (secondary)
   │
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
         └─ k8s-worker-7: 10.10.0.26
```

---

## Граф связности конфигурационных файлов

```
┌─────────────────────────────────────────────────────────────────────┐
│                         variables.tf                                 │
│  zone, platform_id, disk_type, bastion_count, worker_count,         │
│  control_plane_count, worker_resources, control_plane_resources      │
└─────────────────────────┬───────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────────┐
│  bastion.tf          control-plane.tf          workers.tf           │
│  count=bastion_count count=control_plane_count count=worker_count   │
│  IP: 10.10.0.5+idx   IP: 10.10.0.10+idx       IP: 10.10.0.20+idx   │
└─────────────────────────┬───────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         outputs.tf                                   │
│  bastion_ip, bastion_ips, control_plane_ips, worker_ips             │
└─────────────────────────┬───────────────────────────────────────────┘
                          ↓
        ┌─────────────────┼─────────────────┐
        ↓                 ↓                 ↓
┌───────────────┐ ┌───────────────┐ ┌───────────────────┐
│ inventory.tf  │ │kubespray-     │ │ terraform/justfile│
│ → hosts.ini   │ │inventory.tf   │ │ all-ips, clean-ssh│
└───────────────┘ │→ hosts.yaml   │ └─────────┬─────────┘
                  └───────┬───────┘           │
                          ↓                   ↓
                  ┌───────────────────────────────────┐
                  │         kubespray/justfile        │
                  │  check, deploy, setup-kubeconfig  │
                  └───────────────────────────────────┘
```

**Связи между репозиториями:**

```
terraform/
  ├─ variables.tf          ──┐
  ├─ bastion.tf            ──┼──→ создает VMs
  ├─ control-plane.tf      ──┤
  ├─ workers.tf            ──┤
  ├─ outputs.tf            ──┼──→ генерирует outputs
  │                          │
  ├─ inventory.tf          ──┼──→ использует outputs
  │  └─ генерирует:          │    └─→ ansible/inventory/kubeadm/hosts.ini
  │                          │
  ├─ kubespray-inventory.tf ─┼──→ использует outputs
  │  └─ генерирует:          │    └─→ kubespray/inventory/mycluster/hosts.yaml
  │                          │
  └─ justfile              ──┘──→ использует outputs (bastion_ip, bastion_ips)

kubespray/
  ├─ inventory/mycluster/hosts.yaml  ← auto-generated из terraform
  └─ justfile                        ← использует terraform outputs

ansible/
  └─ inventory/kubeadm/hosts.ini     ← auto-generated из terraform
```

---

## Проблемы связности

| Файл | Проблема | Последствия |
|------|----------|-------------|
| kubespray/justfile `check` | Hardcoded IP `10.10.0.10` | Сломается при изменении IP схемы control plane |
| terraform/justfile `clean-ssh` | Hardcoded диапазон `{5,6,10,11,12,20..26}` | Не учтёт новые ноды (worker-8, bastion-3) |
| inventory.tf | Использует `bastion[0]` | Сломается при возврате к single bastion без count |
| infrastructure-prep.md | Описывает `generate-inventory.sh` | Скрипт заменён на inventory.tf, документ устарел |
| infrastructure-setup-full.md | Нет переменных `platform_id`, `disk_type`, `bastion_count` | Применение fixes требует добавления этих переменных |

---

## Рекомендации к исправлению

### kubespray/justfile — динамический IP control plane

```makefile
check:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ../terraform
    source .env
    BASTION_IP=$(/usr/local/bin/terraform output -json bastion_ip | jq -r '.external_ip')
    CONTROL_IP=$(/usr/local/bin/terraform output -json control_plane_ips | jq -r 'to_entries[0].value')
    ssh -J ubuntu@$BASTION_IP ubuntu@$CONTROL_IP "kubectl get nodes"
```

### terraform/justfile — динамический clean-ssh

```makefile
clean-ssh:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Bastion IPs из outputs
    for ip in $(terraform output -json bastion_ips 2>/dev/null | jq -r '.[].external_ip' 2>/dev/null); do
        ssh-keygen -R "$ip" 2>/dev/null || true
    done
    for ip in $(terraform output -json bastion_ips 2>/dev/null | jq -r '.[].internal_ip' 2>/dev/null); do
        ssh-keygen -R "$ip" 2>/dev/null || true
    done
    
    # Control plane IPs из outputs
    for ip in $(terraform output -json control_plane_ips 2>/dev/null | jq -r '.[]' 2>/dev/null); do
        ssh-keygen -R "$ip" 2>/dev/null || true
    done
    
    # Worker IPs из outputs
    for ip in $(terraform output -json worker_ips 2>/dev/null | jq -r '.[]' 2>/dev/null); do
        ssh-keygen -R "$ip" 2>/dev/null || true
    done
    
    echo "SSH keys cleaned"
```

### inventory.tf — совместимость с single/multi bastion

```hcl
locals {
  bastion_ip = length(yandex_compute_instance.bastion) > 0 ? yandex_compute_instance.bastion[0].network_interface[0].nat_ip_address : ""
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    bastion_external_ip = local.bastion_ip
    # ...
  })
}
```

### Синхронизация документации

После применения изменений в инфраструктуре обновить:
1. infrastructure-setup-full.md — добавить новые переменные
2. infrastructure-prep.md — удалить описание generate-inventory.sh
