# Подготовка инфраструктуры для Kubernetes кластера в Yandex Cloud

Развертывание базовой инфраструктуры с использованием Terraform и подготовка нод через Ansible для последующей установки Kubernetes.

## Предварительные требования

**Программное обеспечение:**
- Yandex Cloud CLI >= 0.120.0
- Terraform >= 1.5.0
- Ansible >= 2.15.0
- just >= 1.43.0
- jq

**Yandex Cloud:**
- Service Account с ролью editor
- S3 bucket для Terraform state
- Terraform конфигурация базовой инфраструктуры

**Доступы:**
- GitLab аккаунт для репозитория

---

## Установка just

Установка последней стабильной версии:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | sudo bash -s -- --to /usr/local/bin
```

Проверка версии:

```bash
just --version
```

---

## Структура проекта

Создание дополнительных директорий:

```bash
cd ~/k8s-yandex-cloud
mkdir -p ansible/{inventory/kubeadm,playbooks,roles/{common,containerd,kubeadm,haproxy}/{tasks,templates,handlers}} docs
```

Итоговая структура:

```
k8s-yandex-cloud/
├── terraform/
│   ├── network.tf          # Обновлен: добавлен NAT Gateway
│   ├── justfile            # Новый
│   └── generate-inventory.sh  # Новый
├── ansible/
│   ├── ansible.cfg         # Новый
│   ├── justfile           # Новый
│   ├── inventory/kubeadm/
│   │   └── hosts.ini      # Auto-generated
│   ├── playbooks/
│   │   ├── bastion.yml    # Новый
│   │   └── k8s-prep.yml   # Новый
│   └── roles/
│       ├── common/        # Новый
│       ├── containerd/    # Новый
│       ├── kubeadm/       # Новый
│       └── haproxy/       # Новый
└── docs/
```

---

## Обновление Terraform конфигурации

### Добавление NAT Gateway в network.tf

Обновление существующего файла `terraform/network.tf`:

```hcl
resource "yandex_vpc_network" "k8s_network" {
  name        = "k8s-network"
  description = "Network for Kubernetes cluster"
}

resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet"
  description    = "Subnet for Kubernetes cluster"
  v4_cidr_blocks = ["10.10.0.0/24"]
  zone           = var.zone
  network_id     = yandex_vpc_network.k8s_network.id
  route_table_id = yandex_vpc_route_table.k8s_route_table.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "k8s-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "k8s_route_table" {
  name       = "k8s-route-table"
  network_id = yandex_vpc_network.k8s_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-security-group"
  description = "Security group for Kubernetes cluster"
  network_id  = yandex_vpc_network.k8s_network.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "SSH access"
  }

  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Kubernetes API"
  }

  ingress {
    protocol          = "ANY"
    predefined_target = "self_security_group"
    description       = "Internal cluster traffic"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}
```

NAT Gateway обеспечивает доступ в интернет для приватных нод. Route table направляет весь исходящий трафик через NAT.

### Terraform justfile

Создание файла `terraform/justfile`:

```justfile
set dotenv-load

default:
    @echo "Terraform Automation Commands"
    @echo "=============================="
    @echo ""
    @echo "CORE TERRAFORM COMMANDS:"
    @echo "  init            Initialize Terraform and backend"
    @echo "  validate        Validate Terraform configuration"
    @echo "  fmt             Format Terraform files"
    @echo "  plan            Show execution plan"
    @echo "  apply           Apply changes (requires confirmation)"
    @echo "  apply-auto      Apply changes without confirmation"
    @echo "  destroy         Destroy infrastructure (requires confirmation)"
    @echo "  destroy-auto    Destroy infrastructure without confirmation"
    @echo ""
    @echo "OUTPUTS & STATUS:"
    @echo "  output          Show all Terraform outputs"
    @echo "  show <n>        Show specific output value"
    @echo "  status          List Yandex Cloud instances"
    @echo "  bastion-ip      Get bastion external IP"
    @echo "  all-ips         Get all infrastructure IPs"
    @echo ""
    @echo "WORKFLOWS:"
    @echo "  prepare         Full workflow: init -> validate -> plan"
    @echo "  deploy          Deploy workflow: apply -> output -> status"
    @echo "  quick-deploy    Quick deploy (auto-approve)"

init:
    @echo "Initializing Terraform..."
    terraform init

validate:
    @echo "Validating configuration..."
    terraform validate

fmt:
    @echo "Formatting Terraform files..."
    terraform fmt -recursive

plan:
    @echo "Creating execution plan..."
    terraform plan

apply:
    @echo "Applying infrastructure changes..."
    terraform apply

apply-auto:
    @echo "Auto-applying infrastructure..."
    terraform apply -auto-approve

destroy:
    @echo "Destroying infrastructure..."
    terraform destroy

destroy-auto:
    @echo "Auto-destroying infrastructure..."
    terraform destroy -auto-approve

output:
    @echo "Terraform outputs:"
    terraform output

show output_name:
    @echo "Output: {{output_name}}"
    terraform output {{output_name}}

status:
    @echo "Yandex Cloud instances:"
    yc compute instance list

bastion-ip:
    @echo "Bastion external IP:"
    @terraform output -json bastion_ip | jq -r '.external_ip'

all-ips:
    @echo "Infrastructure IPs:"
    @echo ""
    @echo "=== Bastion ==="
    @terraform output -json bastion_ip | jq -r '"External: " + .external_ip + "\nInternal: " + .internal_ip'
    @echo ""
    @echo "=== Control Plane ==="
    @terraform output -json control_plane_ips | jq -r 'to_entries[] | .key + ": " + .value'
    @echo ""
    @echo "=== Workers ==="
    @terraform output -json worker_ips | jq -r 'to_entries[] | .key + ": " + .value'

prepare:
    @echo "Preparing infrastructure..."
    just init
    just validate
    just plan

deploy:
    @echo "Deploying infrastructure..."
    just apply
    just output
    just status

quick-deploy:
    @echo "Quick deploy (auto-approve)..."
    just apply-auto
    just all-ips
```

### Скрипт генерации Ansible inventory

Создание файла `terraform/generate-inventory.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}"
INVENTORY_FILE="${SCRIPT_DIR}/../ansible/inventory/kubeadm/hosts.ini"

echo "Generating Ansible inventory from Terraform outputs..."

cd "$TERRAFORM_DIR"

if ! terraform state list &>/dev/null; then
    echo "ERROR: No Terraform state found. Run 'terraform apply' first."
    exit 1
fi

BASTION_EXTERNAL_IP=$(terraform output -json bastion_ip | jq -r '.external_ip')
BASTION_INTERNAL_IP=$(terraform output -json bastion_ip | jq -r '.internal_ip')

mkdir -p "$(dirname "$INVENTORY_FILE")"

cat > "$INVENTORY_FILE" << EEOF
# Generated from Terraform outputs on $(date)

[all:vars]
ansible_user=ubuntu
ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[bastion]
k8s-bastion ansible_host=${BASTION_EXTERNAL_IP}

[control_plane]
EEOF

terraform output -json control_plane_ips | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value)"' >> "$INVENTORY_FILE"

echo "" >> "$INVENTORY_FILE"
echo "[workers]" >> "$INVENTORY_FILE"

terraform output -json worker_ips | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value)"' >> "$INVENTORY_FILE"

cat >> "$INVENTORY_FILE" << EEOF

[k8s_cluster:children]
control_plane
workers

[k8s_cluster:vars]
ansible_ssh_common_args='-o ProxyJump=ubuntu@${BASTION_EXTERNAL_IP} -o StrictHostKeyChecking=no'
EEOF

echo "Inventory file generated: $INVENTORY_FILE"
echo ""
echo "Bastion IP: $BASTION_EXTERNAL_IP"
echo ""
echo "Control Plane nodes:"
terraform output -json control_plane_ips | jq -r 'to_entries[] | "  \(.key): \(.value)"'
echo ""
echo "Worker nodes:"
terraform output -json worker_ips | jq -r 'to_entries[] | "  \(.key): \(.value)"'
```

Установка прав на выполнение:

```bash
chmod +x terraform/generate-inventory.sh
```

Скрипт автоматически извлекает IP адреса из Terraform state и генерирует Ansible inventory с ProxyJump через bastion.

---

## Применение обновленной Terraform конфигурации

Переход в директорию terraform:

```bash
cd ~/k8s-yandex-cloud/terraform
```

Загрузка переменных окружения:

```bash
source .env
```

Просмотр изменений:

```bash
just plan
```

Terraform покажет добавление NAT Gateway и route table.

Применение изменений:

```bash
just apply
```

Просмотр результатов:

```bash
just all-ips
```

---

## Ansible конфигурация

### ansible.cfg

Создание файла `ansible/ansible.cfg`:

```ini
[defaults]
inventory = inventory/kubeadm/hosts.ini
roles_path = roles
host_key_checking = False
timeout = 30
forks = 10
gather_facts = yes
retry_files_enabled = False
interpreter_python = auto_silent
command_warnings = False
deprecation_warnings = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

### Установка Ansible

```bash
sudo zypper install ansible
```

Установка required collections:

```bash
ansible-galaxy collection install community.general ansible.posix
```

---

## Ansible Roles

### Role: common

Создание файла `ansible/roles/common/tasks/main.yml`:

```yaml
---
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600

- name: Install required packages
  ansible.builtin.apt:
    name:
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
      - lsb-release
      - software-properties-common
      - net-tools
      - vim
      - htop
    state: present

- name: Disable swap
  ansible.builtin.command: swapoff -a
  changed_when: false
  when: ansible_swaptotal_mb > 0

- name: Remove swap from fstab
  ansible.builtin.lineinfile:
    path: /etc/fstab
    regexp: '\sswap\s'
    state: absent

- name: Load kernel modules
  community.general.modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - overlay
    - br_netfilter

- name: Ensure kernel modules load on boot
  ansible.builtin.copy:
    content: |
      overlay
      br_netfilter
    dest: /etc/modules-load.d/k8s.conf
    mode: '0644'

- name: Set sysctl parameters for Kubernetes
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_set: true
    state: present
    reload: true
  loop:
    - { key: 'net.bridge.bridge-nf-call-iptables', value: '1' }
    - { key: 'net.bridge.bridge-nf-call-ip6tables', value: '1' }
    - { key: 'net.ipv4.ip_forward', value: '1' }

- name: Set timezone to UTC
  community.general.timezone:
    name: UTC
```

Role выполняет базовую подготовку системы для Kubernetes: отключение swap, загрузку kernel modules, настройку sysctl параметров.

### Role: containerd

Создание файла `ansible/roles/containerd/tasks/main.yml`:

```yaml
---
- name: Install containerd dependencies
  ansible.builtin.apt:
    name:
      - containerd
    state: present

- name: Create containerd config directory
  ansible.builtin.file:
    path: /etc/containerd
    state: directory
    mode: '0755'

- name: Generate default containerd config
  ansible.builtin.shell: containerd config default > /etc/containerd/config.toml
  args:
    creates: /etc/containerd/config.toml
  changed_when: false

- name: Configure containerd to use systemd cgroup driver
  ansible.builtin.lineinfile:
    path: /etc/containerd/config.toml
    regexp: '^\s*SystemdCgroup\s*='
    line: '            SystemdCgroup = true'
    insertafter: '^\s*\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\.runc\.options\]'
    state: present

- name: Restart containerd
  ansible.builtin.systemd:
    name: containerd
    state: restarted
    enabled: true
    daemon_reload: true

- name: Wait for containerd socket
  ansible.builtin.wait_for:
    path: /run/containerd/containerd.sock
    state: present
    timeout: 30
```

Containerd настраивается с systemd cgroup driver для корректной работы с kubelet.

### Role: kubeadm

Создание файла `ansible/roles/kubeadm/tasks/main.yml`:

```yaml
---
- name: Add Kubernetes apt key
  ansible.builtin.apt_key:
    url: https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key
    keyring: /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    state: present

- name: Add Kubernetes apt repository
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /"
    filename: kubernetes
    state: present

- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true

- name: Install kubeadm, kubelet, kubectl
  ansible.builtin.apt:
    name:
      - kubelet=1.28.*
      - kubeadm=1.28.*
      - kubectl=1.28.*
    state: present
    allow_change_held_packages: true

- name: Hold Kubernetes packages
  ansible.builtin.dpkg_selections:
    name: "{{ item }}"
    selection: hold
  loop:
    - kubelet
    - kubeadm
    - kubectl

- name: Enable kubelet service
  ansible.builtin.systemd:
    name: kubelet
    enabled: true
    state: started
    daemon_reload: true
```

Пакеты фиксируются для предотвращения автоматических обновлений.

### Role: haproxy

Создание файла `ansible/roles/haproxy/tasks/main.yml`:

```yaml
---
- name: Install HAProxy
  ansible.builtin.apt:
    name: haproxy
    state: present

- name: Configure HAProxy
  ansible.builtin.template:
    src: haproxy.cfg.j2
    dest: /etc/haproxy/haproxy.cfg
    mode: '0644'
  notify: Restart HAProxy

- name: Enable and start HAProxy
  ansible.builtin.systemd:
    name: haproxy
    enabled: true
    state: started
```

Создание файла `ansible/roles/haproxy/templates/haproxy.cfg.j2`:

```
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend k8s_api
    bind *:6443
    mode tcp
    default_backend k8s_control_plane

backend k8s_control_plane
    mode tcp
    balance roundrobin
    option tcp-check
    server k8s-control-1 10.10.0.18:6443 check
    server k8s-control-2 10.10.0.3:6443 check
    server k8s-control-3 10.10.0.31:6443 check

listen stats
    bind *:8080
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:admin
```

HAProxy балансирует запросы к Kubernetes API между тремя control plane нодами. IP адреса должны соответствовать актуальным значениям из Terraform outputs.

Создание файла `ansible/roles/haproxy/handlers/main.yml`:

```yaml
---
- name: Restart HAProxy
  ansible.builtin.systemd:
    name: haproxy
    state: restarted
```

---

## Ansible Playbooks

### bastion.yml

Создание файла `ansible/playbooks/bastion.yml`:

```yaml
---
- name: Configure bastion with HAProxy
  hosts: bastion
  become: true
  roles:
    - common
    - haproxy
```

### k8s-prep.yml

Создание файла `ansible/playbooks/k8s-prep.yml`:

```yaml
---
- name: Prepare Kubernetes nodes
  hosts: k8s_cluster
  become: true
  roles:
    - common
    - containerd
    - kubeadm
```

---

## Ansible justfile

Создание файла `ansible/justfile`:

```justfile
default:
    @echo "Ansible Automation Commands"
    @echo "==========================="
    @echo ""
    @echo "SETUP & PREPARATION:"
    @echo "  gen-inventory       Generate inventory from Terraform outputs"
    @echo "  ping                Test connectivity to all hosts"
    @echo "  check <playbook>    Check playbook syntax"
    @echo "  list-hosts          List all hosts in inventory"
    @echo ""
    @echo "PLAYBOOKS:"
    @echo "  prep-bastion        Configure bastion with HAProxy"
    @echo "  prep-nodes          Prepare all K8s nodes"
    @echo "  prep-all            Run both bastion and nodes preparation"
    @echo ""
    @echo "KUBERNETES CHECKS:"
    @echo "  check-containerd    Check containerd status"
    @echo "  check-kubelet       Check kubelet status"
    @echo "  check-versions      Show K8s component versions"
    @echo ""
    @echo "HAPROXY:"
    @echo "  check-haproxy       Check HAProxy status on bastion"
    @echo "  restart-haproxy     Restart HAProxy on bastion"

gen-inventory:
    @echo "Generating inventory from Terraform..."
    @../terraform/generate-inventory.sh

ping:
    @echo "Testing connectivity..."
    ansible all -m ping

check playbook:
    @echo "Checking playbook syntax: {{playbook}}"
    ansible-playbook playbooks/{{playbook}} --syntax-check

list-hosts:
    @echo "Hosts in inventory:"
    ansible all --list-hosts

prep-bastion:
    @echo "Configuring bastion with HAProxy..."
    ansible-playbook playbooks/bastion.yml

prep-nodes:
    @echo "Preparing K8s nodes..."
    ansible-playbook playbooks/k8s-prep.yml

prep-all:
    @echo "Running full preparation..."
    just prep-bastion
    just prep-nodes

check-containerd:
    @echo "Checking containerd status..."
    ansible k8s_cluster -m shell -a "systemctl status containerd" | grep -E "Active:|Loaded:"

check-kubelet:
    @echo "Checking kubelet status..."
    ansible k8s_cluster -m shell -a "systemctl status kubelet" | grep -E "Active:|Loaded:"

check-versions:
    @echo "Kubernetes component versions:"
    @echo ""
    @echo "=== kubeadm ==="
    @ansible k8s_cluster -m shell -a "kubeadm version -o short" --one-line
    @echo ""
    @echo "=== kubelet ==="
    @ansible k8s_cluster -m shell -a "kubelet --version" --one-line
    @echo ""
    @echo "=== kubectl ==="
    @ansible k8s_cluster -m shell -a "kubectl version --client -o yaml | grep gitVersion" --one-line

check-haproxy:
    @echo "Checking HAProxy status..."
    ansible bastion -m shell -a "systemctl status haproxy"

restart-haproxy:
    @echo "Restarting HAProxy..."
    ansible bastion -m shell -a "systemctl restart haproxy" --become
```

---

## Подготовка SSH доступа

Копирование SSH ключа на bastion:

```bash
BASTION_IP=$(cd terraform && terraform output -json bastion_ip | jq -r '.external_ip')
scp ~/.ssh/id_ed25519 ubuntu@$BASTION_IP:~/.ssh/
```

Настройка прав:

```bash
ssh ubuntu@$BASTION_IP "chmod 600 ~/.ssh/id_ed25519"
```

Проверка доступа к приватным нодам:

```bash
ssh -J ubuntu@$BASTION_IP ubuntu@10.10.0.18 "hostname"
```

---

## Выполнение Ansible подготовки

Переход в директорию ansible:

```bash
cd ~/k8s-yandex-cloud/ansible
```

Генерация inventory:

```bash
just gen-inventory
```

Проверка connectivity:

```bash
just ping
```

Проверка синтаксиса playbooks:

```bash
just check bastion.yml
just check k8s-prep.yml
```

Выполнение ansible-lint:

```bash
ansible-lint playbooks/ roles/
```

Должно показать 0 failures.

Выполнение полной подготовки:

```bash
just prep-all
```

Ansible выполняет настройку bastion с HAProxy (12 tasks) и подготовку всех K8s нод (20 tasks на каждую ноду).

---

## Проверка результатов

Проверка версий компонентов:

```bash
just check-versions
```

Вывод показывает kubeadm v1.28.15, kubelet v1.28.15 на всех нодах.

Проверка containerd:

```bash
just check-containerd
```

Все ноды показывают `active (running)`.

Проверка HAProxy:

```bash
just check-haproxy
```

Bastion показывает `active (running)`.

Проверка доступа в интернет:

```bash
ssh -J ubuntu@$BASTION_IP ubuntu@10.10.0.18 "curl -s ifconfig.me"
```

Возвращает публичный IP NAT Gateway.

---

## Troubleshooting

### Failed to update apt cache

**Причина:** Приватные ноды не имеют доступа в интернет.

**Проверка:**

```bash
ssh -J ubuntu@$BASTION_IP ubuntu@10.10.0.18 "ping -c 2 8.8.8.8"
```

**Решение:** Проверить создание NAT Gateway и route table.

```bash
cd terraform
terraform state show yandex_vpc_gateway.nat_gateway
terraform state show yandex_vpc_route_table.k8s_route_table
```

### Permission denied (publickey)

**Причина:** SSH ключ не скопирован на bastion.

**Решение:**

```bash
scp ~/.ssh/id_ed25519 ubuntu@$BASTION_IP:~/.ssh/
ssh ubuntu@$BASTION_IP "chmod 600 ~/.ssh/id_ed25519"
```

### Containerd not starting

**Проверка:**

```bash
ansible k8s_cluster -m shell -a "systemctl status containerd" --become
ansible k8s_cluster -m shell -a "journalctl -u containerd -n 50" --become
```

Проверка конфигурации:

```bash
ansible k8s_cluster -m shell -a "containerd config dump | grep SystemdCgroup" --become
```

Должно быть `SystemdCgroup = true`.

---

## Best Practices

**Terraform:**
- Remote state в S3 обеспечивает безопасное хранение state файла
- NAT Gateway предпочтительнее NAT Instance для production
- Security Group ограничивает доступ только необходимыми портами

**Ansible:**
- FQCN обеспечивает совместимость
- Роли делают конфигурацию модульной и переиспользуемой
- Идемпотентность позволяет безопасно повторять playbooks
- ProxyJump через bastion защищает приватные ноды

**Инфраструктура:**
- Bastion как единственная точка входа минимизирует attack surface
- Приватная сеть для K8s нод повышает безопасность
- HAProxy на bastion обеспечивает HA для Kubernetes API

---

## Архитектура инфраструктуры

```
Internet
   ↓
[NAT Gateway]
   ↓
[Route Table] → 0.0.0.0/0
   ↓
[VPC 10.10.0.0/24]
   │
   ├─ Bastion (public IP)
   │  └─ HAProxy:6443 → Control Plane:6443
   │
   ├─ Control Plane (3 nodes, private IPs)
   │  ├─ k8s-control-1: 10.10.0.18
   │  ├─ k8s-control-2: 10.10.0.3
   │  └─ k8s-control-3: 10.10.0.31
   │
   └─ Workers (8 nodes, private IPs)
      ├─ k8s-worker-1 - k8s-worker-8
```

---

## Ресурсы кластера

| Компонент | Количество | vCPU | RAM | Disk | IP |
|-----------|------------|------|-----|------|-----|
| Bastion | 1 | 2 | 2GB | 10GB | Публичный |
| Control Plane | 3 | 4 | 8GB | 20GB | Приватный |
| Workers | 8 | 2 | 4GB | 15GB | Приватный |
| **Итого** | **12** | **30** | **58GB** | **190GB** | **1 публичный** |

**Использование квот:**
- VM: 12/12 (100%)
- vCPU: 30/32 (93.75%)
- RAM: 58GB/128GB (45.3%)
- SSD: 190GB/200GB (95%)

---

## Полезные команды

**Terraform:**

```bash
# Просмотр изменений
cd terraform && just plan

# Применение изменений
just apply

# Показать все IP
just all-ips

# Удаление инфраструктуры
just destroy
```

**Ansible:**

```bash
# Регенерация inventory
just gen-inventory

# Проверка доступности
just ping

# Проверка статуса сервисов
just check-containerd
just check-haproxy

# Ad-hoc команды
ansible all -m shell -a "uptime"
ansible k8s_cluster -m shell -a "df -h"
```

**SSH:**

```bash
# Подключение к bastion
ssh ubuntu@$(cd terraform && terraform output -json bastion_ip | jq -r '.external_ip')

# Подключение к control plane
BASTION_IP=$(cd terraform && terraform output -json bastion_ip | jq -r '.external_ip')
ssh -J ubuntu@$BASTION_IP ubuntu@10.10.0.18
```
