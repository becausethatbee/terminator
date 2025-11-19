# Развертывание инфраструктуры Kubernetes в Yandex Cloud

Настройка Terraform для создания HA Kubernetes кластера с использованием remote state в Object Storage.  **ОС:** openSUSE Leap 16.0

---

## Установка Yandex Cloud CLI

Загрузка и установка:

```bash
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```

Применение изменений в shell:

```bash
exec -l $SHELL
```

Проверка версии:

```bash
yc version
```

Инициализация конфигурации:

```bash
yc init
```

При инициализации указать:
- OAuth token
- Cloud из списка доступных
- Folder (можно создать новый или выбрать существующий)
- Default compute zone (ru-central1-d)

Проверка конфигурации:

```bash
yc config list
```

---

## Настройка Service Account

Создание Service Account для Terraform:

```bash
yc iam service-account create --name terraform-sa --description "Service account for Terraform"
```

Получение ID созданного аккаунта:

```bash
yc iam service-account list
```

Сохранение ID в переменную:

```bash
SA_ID="<SERVICE_ACCOUNT_ID>"
```

Назначение роли editor на folder:

```bash
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role editor \
  --subject serviceAccount:$SA_ID
```

Создание авторизованного ключа для провайдера:

```bash
yc iam key create \
  --service-account-id $SA_ID \
  --folder-id <FOLDER_ID> \
  --output terraform/key.json
```

Создание Static Access Key для S3:

```bash
yc iam access-key create \
  --service-account-id $SA_ID \
  --description "S3 access for Terraform state"
```

Сохранить key_id и secret из вывода команды.

---

## S3 Bucket для Terraform State

Создание bucket с уникальным именем:

```bash
yc storage bucket create --name terraform-state-k8s-$(date +%s)
```

Сохранить имя созданного bucket.

---

## Установка Terraform

Скачивание Terraform через Yandex зеркало:

```bash
curl -fsSL https://hashicorp-releases.yandexcloud.net/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip -o terraform.zip
```

Установка unzip (если отсутствует):

```bash
sudo zypper install unzip
```

Распаковка архива:

```bash
unzip terraform.zip
```

Перемещение бинарника в системную директорию:

```bash
sudo mv terraform /usr/local/bin/
```

Проверка версии:

```bash
terraform version
```

Удаление временных файлов:

```bash
rm terraform.zip LICENSE.txt
```

---

## Создание структуры проекта

Создание директорий проекта:

```bash
mkdir -p ~/k8s-yandex-cloud/{terraform,ansible/{inventory,playbooks,roles},k8s/{manifests,gitlab-runner},app,docs}
```

Переход в директорию проекта:

```bash
cd ~/k8s-yandex-cloud
```

Проверка структуры:

```bash
tree -L 2

k8s-yandex-cloud/
├── ansible/
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
├── app/
├── docs/
├── k8s/
│   ├── gitlab-runner/
│   └── manifests/
└── terraform/
```

---

## Создание .gitignore

```bash
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl

# Credentials
key.json
.env
yc-key.txt

# IDE
.vscode/
.idea/

# Temporary files
*.tmp
*.log
EOF
```

---

## Создание .env файла

```bash
cat > terraform/.env << 'EOF'
# Yandex Cloud credentials
export YC_CLOUD_ID="<CLOUD_ID>"
export YC_FOLDER_ID="<FOLDER_ID>"
export YC_ZONE="ru-central1-d"

# S3 backend credentials
export AWS_ACCESS_KEY_ID="<ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<SECRET_ACCESS_KEY>"
export TF_S3_BUCKET="<BUCKET_NAME>"
EOF
```

Заменить плейсхолдеры на реальные значения.

---

## Архитектура инфраструктуры

### Конфигурация кластера

| Компонент | Количество | vCPU | RAM | Disk | IP | Preemptible |
|-----------|------------|------|-----|------|-------|-------------|
| Bastion | 1 | 2 | 2GB | 10GB | Публичный | Да |
| Control Plane | 3 | 4 | 8GB | 20GB | Приватный | Нет |
| Worker | 8 | 2 | 4GB | 15GB | Приватный | Нет |

### Сетевая архитектура

```
Internet
   ↓
Bastion (158.160.x.x:22)
   ↓
Private Network (10.10.0.0/24)
   ├── Control Plane nodes (10.10.0.x:6443)
   └── Worker nodes (10.10.0.x)
```

### Security Group правила

| Направление | Протокол | Порт | Источник | Назначение |
|-------------|----------|------|----------|------------|
| Ingress | TCP | 22 | 0.0.0.0/0 | SSH доступ |
| Ingress | TCP | 6443 | 0.0.0.0/0 | Kubernetes API |
| Ingress | ANY | ANY | self_security_group | Внутренний трафик |
| Egress | ANY | ANY | 0.0.0.0/0 | Исходящий трафик |

---

## Terraform конфигурация

### Структура проекта

```
terraform/
├── .env              # Переменные окружения (не в Git)
├── key.json          # Service account ключ (не в Git)
├── provider.tf       # Провайдер и backend
├── variables.tf      # Переменные конфигурации
├── data.tf          # Data sources
├── network.tf       # VPC и subnet
├── bastion.tf       # Bastion host
├── control-plane.tf # Control plane ноды
├── workers.tf       # Worker ноды
└── outputs.tf       # Outputs
```

### provider.tf

```hcl
terraform {
  # Минимальная версия Terraform
  required_version = ">= 1.5.0"
  
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.120.0"  # Yandex Cloud провайдер
    }
  }
  
  # S3 backend для remote state
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"  # Endpoint Yandex Object Storage
    }
    bucket = "<BUCKET_NAME>"                   # Имя созданного bucket
    region = "ru-central1"                     # Регион
    key    = "k8s-cluster/terraform.tfstate"   # Путь к state файлу в bucket
    
    # Пропуск валидаций для совместимости с Yandex S3
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

# Провайдер Yandex Cloud
provider "yandex" {
  service_account_key_file = "key.json"  # Путь к ключу service account
  cloud_id                 = "<CLOUD_ID>"
  folder_id                = "<FOLDER_ID>"
  zone                     = "ru-central1-d"  # Зона по умолчанию
}
```

### variables.tf

```hcl
# Yandex Cloud ID
variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
  default     = "<CLOUD_ID>"
}

# Yandex Cloud Folder ID
variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
  default     = "<FOLDER_ID>"
}

# Availability Zone
variable "zone" {
  description = "Yandex Cloud Zone"
  type        = string
  default     = "ru-central1-d"
}

# Количество Control Plane нод
variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 3
}

# Количество Worker нод
variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 8
}

# Ресурсы для Control Plane нод
variable "control_plane_resources" {
  description = "Resources for control plane nodes"
  type = object({
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    cores  = 4
    memory = 8
    disk   = 20
  }
}

# Ресурсы для Worker нод
variable "worker_resources" {
  description = "Resources for worker nodes"
  type = object({
    cores  = number
    memory = number
    disk   = number
  })
  default = {
    cores  = 2
    memory = 4
    disk   = 15
  }
}
```

### data.tf

```hcl
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}
```

### network.tf

```hcl
# VPC Network
resource "yandex_vpc_network" "k8s_network" {
  name        = "k8s-network"
  description = "Network for Kubernetes cluster"
}

# Subnet для всех нод кластера
resource "yandex_vpc_subnet" "k8s_subnet" {
  name           = "k8s-subnet"
  description    = "Subnet for Kubernetes cluster"
  v4_cidr_blocks = ["10.10.0.0/24"]
  zone           = var.zone
  network_id     = yandex_vpc_network.k8s_network.id
}

# Security Group с правилами доступа
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

### bastion.tf

```hcl
# Bastion Host - единственная точка входа в кластер
resource "yandex_compute_instance" "bastion" {
  name        = "k8s-bastion"
  hostname    = "k8s-bastion"
  platform_id = "standard-v3"
  zone        = var.zone

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
    nat                = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  scheduling_policy {
    preemptible = false
  }
}
```

### control-plane.tf

```hcl
# Control Plane Nodes (etcd + API server + scheduler + controller-manager)
resource "yandex_compute_instance" "control_plane" {
  count = var.control_plane_count
  
  name        = "k8s-control-${count.index + 1}"
  hostname    = "k8s-control-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.control_plane_resources.cores
    memory = var.control_plane_resources.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.control_plane_resources.disk
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s_subnet.id
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id]
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  scheduling_policy {
    preemptible = false
  }
}
```

### workers.tf

```hcl
# Worker Nodes (kubelet + containerd)
resource "yandex_compute_instance" "worker" {
  count = var.worker_count
  
  name        = "k8s-worker-${count.index + 1}"
  hostname    = "k8s-worker-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

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
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }

  scheduling_policy {
    preemptible = false
  }
}
```

### outputs.tf

```hcl
# Control Plane IPs (только приватные)
output "control_plane_ips" {
  description = "Internal IPs of control plane nodes"
  value = {
    for idx, instance in yandex_compute_instance.control_plane :
    instance.name => instance.network_interface[0].ip_address
  }
}

# Worker IPs (только приватные)
output "worker_ips" {
  description = "Internal IPs of worker nodes"
  value = {
    for idx, instance in yandex_compute_instance.worker :
    instance.name => instance.network_interface[0].ip_address
  }
}

# Network ID (для reference в других модулях)
output "network_id" {
  description = "VPC Network ID"
  value       = yandex_vpc_network.k8s_network.id
}

# Subnet ID (для reference в других модулях)
output "subnet_id" {
  description = "Subnet ID"
  value       = yandex_vpc_subnet.k8s_subnet.id
}

# Bastion IPs (публичный и приватный)
output "bastion_ip" {
  description = "Bastion host IPs"
  value = {
    external_ip = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
    internal_ip = yandex_compute_instance.bastion.network_interface[0].ip_address
  }
}
```

---

## Terraform Workflow

Переход в директорию terraform:

```bash
cd terraform
source .env                    # Загрузка переменных окружения
terraform init                 # Инициализация
terraform validate             # Валидация синтаксиса
terraform plan                 # Просмотр плана изменений
terraform apply                # Создание инфраструктуры
terraform output               # Просмотр outputs
terraform destroy              # Удаление инфраструктуры
terraform fmt -recursive       # Форматирование кода
```

---


## Проверка развернутой инфраструктуры

Просмотр созданных VM:

```bash
yc compute instance list
```

Подключение к bastion:

```bash
ssh ubuntu@<BASTION_EXTERNAL_IP>
```

Проверка доступа к приватной сети:

```bash
ping -c 3 <CONTROL_PLANE_INTERNAL_IP>
```

Выход из bastion:

```bash
exit
```

---


## GitLab CLI установка

Скачивание glab:

```bash
curl -fsSL https://gitlab.com/gitlab-org/cli/-/releases/v1.42.0/downloads/glab_1.42.0_Linux_x86_64.tar.gz -o glab.tar.gz
```

Распаковка:

```bash
tar -xzf glab.tar.gz
```

Установка:

```bash
sudo mv bin/glab /usr/local/bin/
```

Проверка версии:

```bash
glab version
```

Авторизация:

```bash
glab auth login
```

Параметры авторизации:
- Instance: gitlab.com
- Method: Token
- Token: Personal Access Token с scopes api, write_repository
- Protocol: SSH

Создание репозитория:

```bash
glab repo create k8s-yandex-cloud --private --description "Kubernetes HA cluster in Yandex Cloud"
```

---


## Git workflow

Инициализация Git:

```bash
cd ~/k8s-yandex-cloud
git init
```

Настройка пользователя:

```bash
git config user.email "your@email.com"
git config user.name "Your Name"
```

Добавление файлов:

```bash
git add .
```

Первый коммит:

```bash
git commit -m "Initial commit: Terraform infrastructure for K8s cluster in YC"
```

Добавление remote:

```bash
git remote add origin https://gitlab.com/<USERNAME>/k8s-yandex-cloud.git
```

Push в GitLab:

```bash
git push -u origin master
```

---

## Квоты и ограничения

### Лимиты Yandex Cloud Grant

Согласно официальной документации Yandex Cloud:

| Ресурс | Лимит | Квота |
|--------|-------|-------|
| Виртуальные машины (инстансы) | 12 | compute.instances.count |
| Общая оперативная память (RAM) | 128 ГБ | compute.instanceMemory.size |
| Максимум vCPU в совокупности | 32 | compute.instanceCores.count |
| Группы VM (instance groups) | 10 | - |
| Группы размещения (placement groups) | 2 | - |
| Дисков | 32 | compute.disks.count |
| SSD-диски (сумма) | 200 ГБ | compute.ssdDisks.size |
| HDD-диски (сумма) | 500 ГБ | compute.hddDisks.size |
| Файловые системы | 100 штук | - |
| Размер одной FS (SSD или HDD) | 512 ГБ | - |
| Снимки дисков (snapshots) | 32 | - |
| Общий объем snapshots | 400 ГБ | - |
| GPU в триале | 0 (недоступен) | - |


### Текущая конфигурация

| Компонент | Количество | vCPU | RAM | Disk | IP | Сумма vCPU | Сумма RAM |
|-----------|------------|------|-----|------|----|-----------|---------| 
| Bastion | 1 | 2 | 2GB | 10GB | Публичный | 2 | 2GB |
| Control Plane | 3 | 4 | 8GB | 20GB | Приватный | 12 | 24GB |
| Worker | 8 | 2 | 4GB | 15GB | Приватный | 16 | 32GB |
| **Итого** | **12** | - | - | **190GB** | **1 публичный** | **30** | **58GB** |

**Использование лимитов:**
- Инстансов: 12 из 12 (100%)
- vCPU: 30 из 32 (93.75%)
- RAM: 58GB из 128GB (45.3%)
- SSD диски: 190GB из 200GB (95%)

---

## Troubleshooting

### SSH connection timeout

Проблема: Невозможно подключиться к bastion по SSH.

Проверка:

```bash
# Проверить что VM запущена
yc compute instance get k8s-bastion

# Проверить security group правила
yc vpc security-group get <SECURITY_GROUP_ID>
```

Решение: Проверить ingress правило для порта 22.

### Terraform backend initialization failed

Проблема: Ошибка при инициализации S3 backend.

Проверка:

```bash
# Проверить переменные окружения
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Проверить bucket
yc storage bucket list
```

Решение: Проверить credentials в .env файле.

### Resource already exists

Проблема: Terraform пытается создать уже существующий ресурс.

Решение:

```bash
# Импортировать существующий ресурс в state
terraform import <RESOURCE_TYPE>.<NAME> <RESOURCE_ID>

# Или удалить ресурс вручную
yc compute instance delete <INSTANCE_ID>
```

---

## Best Practices

### Безопасность

- Хранить credentials в .env (исключить из Git)
- Использовать SSH ключи вместо паролей
- Применять Security Groups с минимальными правами
- Отключить password authentication на всех нодах

### Terraform

- Использовать remote state в S3
- Версионировать все изменения в Git
- Тестировать на dev окружении перед production
- Применять terraform fmt для форматирования
- Использовать terraform validate перед apply

### Инфраструктура

- Использовать preemptible для некритичных компонентов
- Разделять control plane и worker ресурсы
- Применять приватные IP для всех нод кроме bastion
- Документировать архитектурные решения

---

## Полезные команды

### Yandex Cloud

```bash
yc compute instance list              # Просмотр всех VM
yc compute instance stop <ID>         # Остановка VM
yc compute instance start <ID>        # Запуск VM
yc compute instance delete <ID>       # Удаление VM
yc vpc network list                   # Просмотр сетей
yc vpc subnet list                    # Просмотр подсетей
yc vpc security-group list            # Просмотр security groups
```

### Terraform

```bash
terraform show                        # Показать текущий state
terraform state list                  # Список ресурсов в state
terraform state show <RESOURCE>       # Детальная информация о ресурсе
terraform state rm <RESOURCE>         # Удалить ресурс из state
terraform refresh                     # Обновить state из реального состояния
terraform plan -out=tfplan            # Создать plan в файл
terraform apply tfplan                # Применить сохраненный plan
```

### Git


```bash
git status                            # Статус репозитория
git log --oneline                     # История коммитов
git diff                              # Просмотр изменений
git restore <FILE>                    # Отмена изменений в файле
git checkout -b feature/<NAME>        # Создание новой ветки
```
