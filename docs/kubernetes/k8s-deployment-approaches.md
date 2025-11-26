# Развертывание Kubernetes кластера: kubeadm и kubespray

Развертывание HA Kubernetes кластера в Yandex Cloud. Предварительные работы по развертке и подготовке инфраструктуры описаны в Infrastructure Setup и Infrastructure Prep.

## Предварительные требования

**ПО:**
- Terraform >= 1.5.0 с remote state в S3
- Ansible >= 2.15.0
- Python 3.13 с venv
- kubectl >= 1.28
- just >= 1.43.0

**Инфраструктура:**
- 12 VM: 1 bastion + 3 control plane + 8 workers
- NAT Gateway для приватных нод
- HAProxy на bastion для балансировки API
- SSH ключи настроены

**Доступы:**
- Yandex Cloud credentials
- Git repository access

---

## Развертывание с kubeadm

### Архитектура

```
Internet → NAT Gateway → [Bastion HAProxy:6443]
                              ↓
                    ┌─────────┴─────────┐
              Control Plane (3)    Workers (8)
              10.10.0.10-12        10.10.0.20-27
              etcd + API           kubelet
              Flannel              Flannel
```

### Подготовка

Проверка доступности нод:

```bash
cd ~/k8s-yandex-cloud/ansible
just ping
```

Все 11 K8s нод должны быть доступны через bastion.

### Инициализация первого control plane

Подключение к k8s-control-1:

```bash
ssh -J ubuntu@<BASTION_EXTERNAL_IP> ubuntu@10.10.0.10
```

Выполнение kubeadm init:

```bash
sudo kubeadm init \
  --control-plane-endpoint=10.10.0.5:6443 \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16
```

Параметры:
- `--control-plane-endpoint`: HAProxy endpoint для HA
- `--upload-certs`: автоматическая репликация сертификатов между control plane
- `--pod-network-cidr`: CIDR для Flannel

Команда выводит join tokens для control plane и workers - сохранить вывод.

### Настройка kubeconfig

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown ubuntu:ubuntu ~/.kube/config
```

Проверка:

```bash
kubectl get nodes
```

Нода в статусе NotReady до установки CNI.

### Установка Flannel CNI

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Flannel создает DaemonSet на всех нодах для pod networking.

Ожидание готовности:

```bash
kubectl get nodes
```

Нода переходит в Ready после запуска flannel pod.

### Присоединение control plane нод

Подключение к control-2:

```bash
exit
ssh -J ubuntu@<BASTION_EXTERNAL_IP> ubuntu@10.10.0.11
```

Выполнение join с флагами control-plane:

```bash
sudo kubeadm join 10.10.0.5:6443 \
  --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH> \
  --control-plane \
  --certificate-key <CERT_KEY>
```

Значения token, hash и certificate-key из вывода kubeadm init.

Повторить для control-3 (10.10.0.12).

### Присоединение worker нод

Массовое присоединение через Ansible:

```bash
cd ~/k8s-yandex-cloud/ansible
ansible workers -m shell -a "sudo kubeadm join 10.10.0.5:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>" --become
```

Команда выполняется параллельно на всех 8 workers.

### Проверка кластера

Подключение к control-1:

```bash
ssh -J ubuntu@<BASTION_EXTERNAL_IP> ubuntu@10.10.0.10
```

Проверка нод:

```bash
kubectl get nodes
```

Все 11 нод в статусе Ready.

Проверка системных компонентов:

```bash
kubectl get pods -n kube-system
```

Работают: coredns, kube-proxy, etcd (на control plane), api-server, controller-manager, scheduler.

Проверка Flannel:

```bash
kubectl get pods -n kube-flannel
```

11 flannel pods Running (DaemonSet).

### Проверка containerd runtime

Создание тестового pod:

```bash
kubectl run nginx-test --image=nginx:latest --restart=Never
```

Ожидание запуска:

```bash
kubectl get pods -o wide -w
```

Проверка runtime:

```bash
kubectl get pod nginx-test -o jsonpath='{.status.containerStatuses[0].containerID}'
```

Вывод начинается с `containerd://` - pod работает через containerd.

Проверка работоспособности:

```bash
kubectl exec nginx-test -- curl -s localhost
```

Возвращает HTML страницу nginx.

---

## Развертывание с kubespray

### Подготовка инфраструктуры

Пересоздание VM для чистого развертывания:

```bash
cd ~/k8s-yandex-cloud/terraform
source .env
just destroy-clean
just apply-auto
```

Проверка нового bastion IP:

```bash
just all-ips
```

### Установка kubespray

Клонирование репозитория:

```bash
cd ~/k8s-yandex-cloud
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
```

Переключение на стабильный релиз:

```bash
git checkout v2.29.0
```

### Настройка Python venv

Создание изолированного окружения:

```bash
python3 -m venv venv
source venv/bin/activate
```

Установка совместимой версии Ansible:

```bash
pip install ansible-core==2.17.7
pip install -r requirements.txt
```

Проверка версии:

```bash
ansible --version
```

Должна быть ansible-core 2.17.x.

### Автоматизация inventory через Terraform

Создание template для kubespray:

```bash
cd ~/k8s-yandex-cloud/terraform
nano kubespray-inventory.tpl
```

Содержимое template:

```yaml
# ADDED: template для kubespray inventory с автоматической генерацией группировки нод
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
    kube_control_plane:  # ADDED: группа для control plane нод
      hosts:
%{ for name, ip in control_plane_ips ~}
        ${name}:
%{ endfor ~}
    kube_node:  # ADDED: группа для worker нод
      hosts:
%{ for name, ip in worker_ips ~}
        ${name}:
%{ endfor ~}
    etcd:  # ADDED: etcd кластер на control plane
      hosts:
%{ for name, ip in control_plane_ips ~}
        ${name}:
%{ endfor ~}
    k8s_cluster:  # ADDED: общая группа для всех K8s нод
      children:
        kube_control_plane:
        kube_node:
    calico_rr:  # ADDED: route reflector для Calico BGP
      hosts: {}
  vars:
    ansible_user: ubuntu
    ansible_ssh_common_args: '-o ProxyCommand="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@${bastion_external_ip}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
```

Создание Terraform resource:

```bash
nano kubespray-inventory.tf
```

Содержимое:

```hcl
# ADDED: local_file resource для генерации kubespray inventory
resource "local_file" "kubespray_inventory" {
  content = templatefile("${path.module}/kubespray-inventory.tpl", {
    bastion_external_ip = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
    control_plane_ips = {
      for idx, instance in yandex_compute_instance.control_plane :
      instance.name => instance.network_interface[0].ip_address
    }
    worker_ips = {
      for idx, instance in yandex_compute_instance.worker :
      instance.name => instance.network_interface[0].ip_address
    }
  })

  filename        = "${path.module}/../kubespray/inventory/mycluster/hosts.yaml"  # CHANGED: путь для kubespray
  file_permission = "0644"
}
```

Применение изменений:

```bash
source .env
just apply-auto
```

Terraform автоматически создает inventory с актуальным bastion IP.

### Настройка kubespray

Копирование sample inventory:

```bash
cd ~/k8s-yandex-cloud/kubespray
cp -r inventory/sample inventory/mycluster
```

Проверка CNI plugin:

```bash
grep "kube_network_plugin" inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
```

По умолчанию установлен Calico.

### Развертывание кластера

Активация venv:

```bash
source venv/bin/activate
```

Запуск playbook:

```bash
ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml
```

Процесс занимает 25-35 минут. Kubespray выполняет:
- Установка container runtime (containerd)
- Настройка etcd кластера
- Развертывание control plane компонентов
- Присоединение worker нод
- Установка Calico CNI
- Настройка системных аддонов

### Проверка результатов

После завершения playbook вывод:

```
PLAY RECAP
k8s-control-1: ok=631 changed=141 unreachable=0 failed=0
k8s-control-2: ok=546 changed=128 unreachable=0 failed=0
k8s-control-3: ok=548 changed=129 unreachable=0 failed=0
k8s-worker-1-8: ok=433 changed=87 unreachable=0 failed=0
```

failed=0 на всех нодах = успешное развертывание.

### Настройка kubeconfig

Выход из venv:

```bash
deactivate
```

Подключение к control-1:

```bash
ssh -J ubuntu@<BASTION_EXTERNAL_IP> ubuntu@10.10.0.10
```

Kubespray не копирует kubeconfig автоматически. Ручная настройка:

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown ubuntu:ubuntu ~/.kube/config
```

Проверка кластера:

```bash
kubectl get nodes
```

Все 11 нод Ready, Kubernetes версия определена kubespray.

### Проверка Calico

```bash
kubectl get pods -n kube-system | grep calico
```

Должны работать:
- 11 calico-node pods (DaemonSet)
- 1 calico-kube-controllers pod

Calico предоставляет pod networking, Network Policies support и BGP routing (опционально).

### Проверка containerd

Создание тестового pod:

```bash
kubectl run nginx-kubespray --image=nginx:latest --restart=Never
```

Ожидание запуска:

```bash
kubectl get pods -o wide -w
```

Проверка runtime:

```bash
kubectl get pod nginx-kubespray -o jsonpath='{.status.containerStatuses[0].containerID}'
```

Вывод: `containerd://...`

---

## Автоматизация

### SSH cleanup

Terraform justfile команда для очистки known_hosts после пересоздания инфраструктуры:

```makefile
cleanup-ssh:  # ADDED: очистка SSH known_hosts для всех нод и bastion
    @echo "Cleaning SSH known_hosts..."
    @BASTION_IP=$(terraform output -json bastion_ip 2>/dev/null | jq -r '.external_ip' 2>/dev/null || echo "")
    @if [ -n "$BASTION_IP" ]; then ssh-keygen -R $BASTION_IP 2>/dev/null; fi
    @for ip in 10.10.0.{5,10,11,12,20,21,22,23,24,25,26,27}; do ssh-keygen -R $ip 2>/dev/null; done
    @echo "SSH keys cleaned"

destroy-clean:  # ADDED: composite команда для полной очистки инфраструктуры и SSH
    @echo "Destroying and cleaning..."
    just nuke
    just cleanup-ssh
```

Использование:

```bash
cd ~/k8s-yandex-cloud/terraform
just destroy-clean
```

### Kubeconfig setup через Ansible

Ansible playbook для автоматической настройки kubeconfig на control plane нодах:

```yaml
---
- name: Setup kubeconfig for ubuntu user  # ADDED: автоматическая настройка kubeconfig
  hosts: control_plane
  become: true
  tasks:
    - name: Create .kube directory
      ansible.builtin.file:
        path: /home/ubuntu/.kube
        state: directory
        owner: ubuntu
        group: ubuntu
        mode: '0755'

    - name: Copy admin.conf to user kubeconfig  # ADDED: копирование конфига после развертывания
      ansible.builtin.copy:
        src: /etc/kubernetes/admin.conf
        dest: /home/ubuntu/.kube/config
        remote_src: true
        owner: ubuntu
        group: ubuntu
        mode: '0600'

    - name: Verify kubectl works
      ansible.builtin.command: kubectl get nodes
      become: false
      register: kubectl_result
      changed_when: false

    - name: Display cluster status
      ansible.builtin.debug:
        var: kubectl_result.stdout_lines
```

Файл: `ansible/playbooks/kubeconfig-setup.yml`

Ansible justfile команда:

```makefile
setup-kubeconfig:  # ADDED: команда для автоматической настройки kubeconfig
    @echo "Setting up kubeconfig..."
    ansible-playbook playbooks/kubeconfig-setup.yml
```

Использование после kubespray развертывания:

```bash
cd ~/k8s-yandex-cloud/ansible
just setup-kubeconfig
```

### Inventory автогенерация

Оба inventory (Ansible и kubespray) генерируются автоматически через Terraform local_file resources:

```
Terraform outputs (bastion IP, node IPs)
    ↓
Templates (.tpl файлы)
    ↓
local_file resources
    ↓
Generated inventory (всегда актуальные IP)
    ↓
Automated deployment
```

Преимущества: единственный источник истины, автоматическое обновление, исключение ошибок с устаревшими IP.

---

## Troubleshooting

### kubeadm: Token expired

**Ошибка:**
```
worker nodes not joining, token not found
```

**Причина:** Bootstrap token действителен 24 часа.

**Решение:** Генерация нового token на control plane:

```bash
kubeadm token create --print-join-command
```

Вывод содержит полную команду join для workers.

### kubespray: SSH connection refused

**Ошибка:**
```
UNREACHABLE! => "Failed to connect: Connection refused"
```

**Причина:** Неактуальный bastion IP в inventory после пересоздания инфраструктуры.

**Решение:** Регенерация inventory через Terraform:

```bash
cd ~/k8s-yandex-cloud/terraform
just apply-auto
```

### kubespray: Ansible version mismatch

**Ошибка:**
```
Ansible must be between 2.17.3 and 2.18.0 - you have 2.19.4
```

**Причина:** Системная версия Ansible несовместима с kubespray.

**Решение:** Использование Python venv с совместимой версией:

```bash
cd ~/k8s-yandex-cloud/kubespray
python3 -m venv venv
source venv/bin/activate
pip install ansible-core==2.17.7
```

### HAProxy backend DOWN

**Ошибка:**
```
Server k8s_control_plane/k8s-control-1 is DOWN
```

**Причина:** Kubernetes API (порт 6443) не запущен.

**Статус:** Нормально до инициализации кластера. После kubeadm init или kubespray deploy backend автоматически переходит в UP.

**Проверка:** После развертывания кластера:

```bash
ansible bastion -m shell -a "echo 'show stat' | sudo socat stdio /run/haproxy/admin.sock | grep k8s_control_plane"
```

### Pod stuck in ContainerCreating

**Ошибка:** Pod не переходит в Running, статус ContainerCreating >5 минут.

**Диагностика:**

```bash
kubectl describe pod <POD_NAME>
```

Проверка Events секции.

**Частые причины:**
- CNI не установлен: установить Flannel/Calico
- Image pull проблемы: проверить описание pod
- Node NotReady: проверить `kubectl get nodes`

**Решение для CNI:**

kubeadm:
```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

kubespray: CNI устанавливается автоматически.

### kubectl: connection refused localhost:8080

**Ошибка:**
```
The connection to the server localhost:8080 was refused
```

**Причина:** Отсутствует или неправильный kubeconfig.

**Решение:**

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

Или через Ansible:

```bash
cd ~/k8s-yandex-cloud/ansible
just setup-kubeconfig
```

---

## Best Practices

**Автоматизация:**
- Terraform templates для всех inventory файлов
- Single source of truth (Terraform outputs)
- Идемпотентность всех операций
- Декларативные конфигурации где возможно

**HA control plane:**
- Минимум 3 ноды (нечетное количество для etcd quorum)
- Load balancer перед API server (HAProxy в данном случае)
- Распределение etcd членов по разным нодам

**Версионирование:**
- kubeadm: ручной контроль версий K8s
- kubespray: управление через переменные inventory
- Фиксация версий для production
- Тестирование обновлений на staging

**Backup:**
- etcd snapshots регулярно
- Kubeconfig файлы
- Terraform state в remote backend
- Документация конфигураций

---

## Полезные команды

**Terraform:**

```bash
cd ~/k8s-yandex-cloud/terraform
source .env

# Пересоздание инфраструктуры с очисткой SSH
just destroy-clean
just apply-auto

# Просмотр IP адресов
just all-ips

# Очистка SSH known_hosts
just cleanup-ssh
```

**Ansible:**

```bash
cd ~/k8s-yandex-cloud/ansible

# Проверка connectivity
just ping

# Настройка kubeconfig после kubespray
just setup-kubeconfig

# Проверка компонентов
just check-versions
just check-containerd
just check-haproxy
```

**kubeadm:**

```bash
# Генерация нового join token
kubeadm token create --print-join-command

# Проверка сертификатов
kubeadm certs check-expiration

# Upload certificates для новых control plane
kubeadm init phase upload-certs --upload-certs
```

**kubespray:**

```bash
cd ~/k8s-yandex-cloud/kubespray
source venv/bin/activate

# Полное развертывание
ansible-playbook -i inventory/mycluster/hosts.yaml --become cluster.yml

# Обновление кластера
ansible-playbook -i inventory/mycluster/hosts.yaml --become upgrade-cluster.yml

# Scale workers
ansible-playbook -i inventory/mycluster/hosts.yaml --become scale.yml

# Reset кластера
ansible-playbook -i inventory/mycluster/hosts.yaml --become reset.yml
```

**kubectl:**

```bash
# Статус нод
kubectl get nodes -o wide

# Системные компоненты
kubectl get pods -n kube-system

# CNI pods
kubectl get pods -n kube-flannel  # для kubeadm
kubectl get pods -n kube-system | grep calico  # для kubespray

# Проверка runtime
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.containerRuntimeVersion}{"\n"}{end}'

# Создание тестового pod
kubectl run test --image=nginx:latest --restart=Never
kubectl get pods -o wide
kubectl describe pod test
kubectl logs test
kubectl delete pod test
```

---

## Архитектурные отличия

**kubeadm:**
```
User → kubeadm CLI
         ↓
    Локальная инициализация
         ↓
    Manual certificate distribution
         ↓
    Manual join commands
         ↓
    Manual CNI installation
```

**kubespray:**
```
User → ansible-playbook
         ↓
    Kubespray роли
         ↓
    Автоматическая генерация конфигов
         ↓
    Автоматическое развертывание etcd
         ↓
    Автоматическая настройка control plane
         ↓
    Автоматическое присоединение workers
         ↓
    Автоматическая установка CNI
```

---

## DRY и идемпотентность

**Применено:**
- Terraform templates для inventory (kubeadm и kubespray)
- Single source of truth (Terraform outputs)
- Автоматическая регенерация при terraform apply
- Идемпотентные Ansible playbooks
- Декларативные конфигурации (kubectl apply)
- Версионированные конфигурации в Git

**Паттерн:**
```
Terraform State
    ↓
Templates (.tpl)
    ↓
local_file resources
    ↓
Generated configs
    ↓
Automated deployment
```

**Результат:** Изменение одного параметра в Terraform автоматически обновляет все зависимые конфигурации.
