# Deployment виртуальной машины в Yandex Cloud через Terraform

Автоматизация создания VM с использованием Infrastructure as Code подхода и конфигурации через cloud-init.

## Предварительные требования

- Terraform >= 1.0
- Yandex Cloud CLI >= 0.169.0
- Активный аккаунт Yandex Cloud
- SSH клиент
- jq для обработки JSON

---

## Установка инструментов

### Terraform

**Метод 1: Через APT репозиторий HashiCorp**

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

Для Debian Trixie необходима корректировка репозитория:

```bash
sudo sed -i 's/trixie/bookworm/g' /etc/apt/sources.list.d/hashicorp.list
sudo apt update
```

Валидация установки:

```bash
terraform version
```

**Метод 2: Через зеркало Yandex Cloud**

При блокировке registry.terraform.io используется зеркало Yandex.

Загрузка бинарника:

```bash
curl -fsSL https://hashicorp-releases.yandexcloud.net/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip -o terraform.zip
```

Распаковка и установка:

```bash
unzip terraform.zip
sudo mv terraform /usr/local/bin/terraform
```

Валидация установки:

```bash
terraform version
```

Ожидаемый вывод: `Terraform v1.6.6`

### Конфигурация Terraform для работы через зеркало

При блокировке registry.terraform.io настройка зеркала Yandex Cloud для загрузки провайдеров.

Файл `~/.terraformrc`:

```hcl
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
```

Конфигурация перенаправляет запросы к registry.terraform.io на зеркало Yandex. Файл `.terraformrc` считывается Terraform автоматически при каждом запуске.

### Yandex Cloud CLI

```bash
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```

Перезагрузка shell для применения изменений PATH:

```bash
exec -l $SHELL
```

```bash
source ~/.bashrc
```

Валидация установки:

```bash
yc version
```

### Вспомогательные утилиты

```bash
sudo apt install -y jq
```

---

## Инициализация Yandex Cloud

### Конфигурация CLI

```bash
yc init
```

В процессе инициализации выполняется:
- Получение OAuth токена через веб-интерфейс
- Выбор cloud и folder для работы
- Настройка зоны по умолчанию

Параметры сохраняются в `~/.config/ycloud/config.yaml`.

### Создание сервисного аккаунта

```bash
yc iam service-account create --name terraform-sa --description "Service account for Terraform"
```

Назначение роли editor:

```bash
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role editor \
  --subject serviceAccount:$(yc iam service-account get terraform-sa --format json | jq -r .id)
```

Генерация авторизованного ключа:

```bash
yc iam key create --service-account-name terraform-sa --output key.json
```

Файл `key.json` содержит приватный ключ для авторизации Terraform в Yandex Cloud API.

---

## Структура проекта

### Создание директорий и файлов

```bash
mkdir -p ~/yandex-terraform
cd ~/yandex-terraform
touch provider.tf variables.tf main.tf terraform.tfvars
```

Организация кода Terraform:

| Файл | Назначение |
|------|-----------|
| provider.tf | Конфигурация провайдера и версий |
| variables.tf | Объявление входных переменных |
| main.tf | Описание ресурсов инфраструктуры |
| terraform.tfvars | Значения переменных |

### Генерация SSH ключа

```bash
ssh-keygen -t ed25519 -f ~/.ssh/yc-terraform -N "" -C "terraform-vm-key"
```

---

## Конфигурация Terraform

### provider.tf

```hcl
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }
  required_version = ">= 1.0"
}

provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
```

Провайдер преобразует декларативное описание инфраструктуры в API вызовы к Yandex Cloud.

### variables.tf

```hcl
variable "service_account_key_file" {
  description = "Path to service account key file"
  type        = string
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "zone" {
  description = "Yandex Cloud Zone"
  type        = string
  default     = "ru-central1-a"
}

variable "instance_name" {
  description = "VM instance name"
  type        = string
  default     = "terraform-vm"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}
```

Переменные без default обязательны для определения в terraform.tfvars.

### terraform.tfvars

```hcl
service_account_key_file = "key.json"
cloud_id                 = "<CLOUD_ID>"
folder_id                = "<FOLDER_ID>"
zone                     = "ru-central1-a"
instance_name            = "terraform-vm"
ssh_public_key           = "<SSH_PUBLIC_KEY>"
```

Значения подставляются из вывода команд `yc init` и `cat ~/.ssh/yc-terraform.pub`.

### main.tf

```hcl
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "vm" {
  name        = var.instance_name
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
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = <<-EOF
      #cloud-config
      users:
        - name: ubuntu
          groups: sudo
          shell: /bin/bash
          sudo: ['ALL=(ALL) NOPASSWD:ALL']
          ssh_authorized_keys:
            - ${var.ssh_public_key}
    EOF
  }
}

resource "yandex_vpc_network" "network" {
  name = "terraform-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "terraform-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.128.0.0/24"]
}

output "external_ip" {
  value = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}
```

**Компоненты конфигурации:**

**Data source yandex_compute_image**

Получает актуальный образ Ubuntu 22.04 LTS из публичного каталога Yandex Cloud.

**Resource yandex_compute_instance**

Параметры виртуальной машины:
- Platform: standard-v3 (Intel Ice Lake)
- CPU: 2 cores
- RAM: 2 GB
- Disk: 10 GB network-hdd
- NAT: публичный IP для внешнего доступа

**Metadata с cloud-init**

Cloud-init выполняется при первой загрузке VM и конфигурирует:
- Пользователя ubuntu с sudo привилегиями
- SSH авторизацию по публичному ключу
- Shell окружение

**Network инфраструктура**

VPC network и subnet создают изолированное сетевое пространство для VM.

**Output external_ip**

Извлекает публичный IP адрес из сетевого интерфейса VM после создания.

---

## Deployment инфраструктуры

### Инициализация проекта

```bash
terraform init
```

Операции инициализации:
- Создание директории `.terraform`
- Загрузка провайдера yandex из Terraform Registry
- Инициализация state backend

### Планирование изменений

```bash
terraform plan
```

План показывает ресурсы для создания без применения изменений.

### Применение конфигурации

```bash
terraform apply
```

Terraform создает ресурсы в следующем порядке:
1. yandex_vpc_network
2. yandex_vpc_subnet
3. yandex_compute_instance

После завершения выводится публичный IP адрес VM.

### Авторизация на VM

```bash
ssh -i ~/.ssh/yc-terraform ubuntu@<EXTERNAL_IP>
```

Cloud-init завершает конфигурацию в течение 30-60 секунд после создания VM.

Валидация окружения:

```bash
hostname
cat /etc/os-release | grep PRETTY_NAME
```

### Удаление инфраструктуры

```bash
terraform destroy
```

Ресурсы удаляются в обратном порядке зависимостей. State обнуляется, конфигурационные файлы сохраняются.

---

## Troubleshooting

### Permission denied при назначении роли

**Ошибка:**
```
ERROR: expect subject in TYPE:ID format, but got "serviceAccount:"
```

**Причина:** Отсутствует утилита jq для парсинга JSON.

**Решение:**
```bash
sudo apt install -y jq
```

### SSH connection refused

**Ошибка:**
```
ssh: connect to host <IP> port 22: Connection refused
```

**Причина:** Cloud-init еще не завершил инициализацию VM.

**Решение:**
Ожидание 30-60 секунд после создания VM. Проверка статуса через Yandex Cloud Console.

### Repository not found для HashiCorp

**Ошибка:**
```
The repository 'https://apt.releases.hashicorp.com trixie Release' does not have a Release file
```

**Причина:** Отсутствует официальный репозиторий для Debian Trixie.

**Решение:**
```bash
sudo sed -i 's/trixie/bookworm/g' /etc/apt/sources.list.d/hashicorp.list
sudo apt update
```

### Invalid service account key format

**Ошибка:**
```
Error: failed to load service account key file: invalid key format
```

**Причина:** Некорректный путь к key.json или поврежденный файл.

**Решение:**
Проверка наличия файла и регенерация ключа:
```bash
ls -la key.json
yc iam key create --service-account-name terraform-sa --output key.json --force
```

---

## Best Practices

**Управление состоянием**

Использовать remote backend (S3, Terraform Cloud) для команд работы и state locking.

**Версионирование провайдеров**

Фиксировать мажорные версии через `~>` для предотвращения breaking changes.

**Модульная архитектура**

Разделять инфраструктуру на переиспользуемые модули для network, compute, security.

**Secrets management**

Исключить terraform.tfvars из VCS через .gitignore. Использовать переменные окружения или secret managers для чувствительных данных.

**Валидация конфигурации**

```bash
terraform fmt
terraform validate
```

Форматирование и валидация перед коммитом изменений.

**Идемпотентность операций**

Terraform обеспечивает идемпотентность через state tracking. Повторный apply не создает дубликаты ресурсов.

**Таgging ресурсов**

```hcl
labels = {
  environment = "dev"
  managed_by  = "terraform"
  project     = "infrastructure"
}
```

Метки упрощают биллинг и управление ресурсами.

---

## Полезные команды

**Terraform**

| Команда | Описание |
|---------|----------|
| `terraform init` | Инициализация проекта, загрузка провайдеров |
| `terraform plan` | Просмотр плана изменений |
| `terraform apply` | Применение конфигурации |
| `terraform destroy` | Удаление всех ресурсов |
| `terraform state list` | Список ресурсов в state |
| `terraform output` | Вывод значений output переменных |
| `terraform fmt` | Форматирование .tf файлов |
| `terraform validate` | Валидация синтаксиса |
| `terraform show` | Отображение текущего state |

**Yandex Cloud CLI**

| Команда | Описание |
|---------|----------|
| `yc init` | Инициализация CLI |
| `yc config list` | Текущая конфигурация |
| `yc compute instance list` | Список VM в folder |
| `yc vpc network list` | Список сетей |
| `yc iam service-account list` | Список сервисных аккаунтов |
| `yc iam key list --service-account-name <NAME>` | Ключи сервисного аккаунта |

**SSH**

| Команда | Описание |
|---------|----------|
| `ssh-keygen -t ed25519` | Генерация ed25519 ключа |
| `ssh-keygen -l -f <KEY>` | Fingerprint ключа |
| `ssh -i <KEY> user@host` | Подключение с указанием ключа |
| `ssh-add <KEY>` | Добавление ключа в ssh-agent |
