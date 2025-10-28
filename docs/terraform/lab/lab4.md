# Создание и использование Terraform модулей

Разработка переиспользуемого модуля для создания виртуальных машин в Yandex Cloud с последующим применением в проекте.

## Предварительные требования

- Terraform >= 1.0
- Yandex Cloud CLI
- Настроенный провайдер Yandex Cloud
- SSH ключ для доступа к VM
- Активный service account с правами на создание ресурсов

---

## Структура проекта

```
terraform-project/
├── modules/
│   └── vm_module/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── provider.tf
├── variables.tf
└── terraform.tfvars
```

---

## Создание модуля

### Директория модуля

```bash
mkdir -p modules/vm_module
```

### Variables модуля

Файл `modules/vm_module/variables.tf` определяет входные параметры модуля.

```hcl
variable "vm_name" {
  description = "VM instance name"
  type        = string
}

variable "cpu" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "RAM size in GB"
  type        = number
  default     = 2
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 10
}

variable "subnet_id" {
  description = "Subnet ID for network interface"
  type        = string
}

variable "zone" {
  description = "Availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "ssh_keys" {
  description = "SSH public keys for user access"
  type        = list(string)
}

variable "username" {
  description = "Username for SSH access"
  type        = string
  default     = "ubuntu"
}
```

Переменные с `default` являются опциональными, остальные обязательны при вызове модуля.

### Ресурсы модуля

Файл `modules/vm_module/main.tf` содержит логику создания VM.

```hcl
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

resource "yandex_compute_instance" "vm" {
  name        = var.vm_name
  platform_id = "standard-v2"
  zone        = var.zone
  allow_stopping_for_update = true

  resources {
    cores  = var.cpu
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = "fd8kb72eo1r5fs97a1ki"
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.username}:${join("\n${var.username}:", var.ssh_keys)}"
  }
}
```

Параметр `allow_stopping_for_update` разрешает остановку VM для изменения ресурсов.

### Outputs модуля

Файл `modules/vm_module/outputs.tf` определяет возвращаемые значения.

```hcl
output "instance_id" {
  description = "VM instance ID"
  value       = yandex_compute_instance.vm.id
}

output "external_ip" {
  description = "External IP address"
  value       = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}

output "internal_ip" {
  description = "Internal IP address"
  value       = yandex_compute_instance.vm.network_interface.0.ip_address
}

output "fqdn" {
  description = "Fully qualified domain name"
  value       = yandex_compute_instance.vm.fqdn
}
```

Outputs модуля доступны через `module.<name>.<output_name>`.

---

## Использование модуля

### Конфигурация сети

Файл `main.tf` в корне проекта создает сетевую инфраструктуру и вызывает модуль.

```hcl
resource "yandex_vpc_network" "network" {
  name = "terraform-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "terraform-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["10.128.0.0/24"]
}
```

### Вызов модуля

```hcl
module "web_vm" {
  source = "./modules/vm_module"

  vm_name   = "web-server-01"
  cpu       = 2
  memory    = 2
  disk_size = 10
  subnet_id = yandex_vpc_subnet.subnet.id
  zone      = var.zone
  ssh_keys  = [var.ssh_public_key]
  username  = "ubuntu"
}

module "db_vm" {
  source = "./modules/vm_module"

  vm_name   = "db-server-01"
  cpu       = 4
  memory    = 4
  disk_size = 20
  subnet_id = yandex_vpc_subnet.subnet.id
  zone      = var.zone
  ssh_keys  = [var.ssh_public_key]
  username  = "ubuntu"
}
```

Каждый вызов `module` создает отдельный экземпляр VM с указанными параметрами.

### Outputs проекта

```hcl
output "web_vm_ip" {
  value = module.web_vm.external_ip
}

output "db_vm_ip" {
  value = module.db_vm.external_ip
}
```

---

## Применение конфигурации

### Инициализация

```bash
terraform init
```

Terraform загружает модули из указанных источников в `.terraform/modules/`.

### Планирование

```bash
terraform plan
```

План показывает создание 4 ресурсов: сеть, подсеть, 2 VM через модуль.

### Применение

```bash
terraform apply -auto-approve
```

Создаются все ресурсы согласно конфигурации.

### Проверка

```bash
yc compute instance list
```

Список должен содержать обе VM с указанными именами и ресурсами.

---

## Модификация модуля

### Изменение параметра

Изменение в `modules/vm_module/main.tf`:

```hcl
resources {
  cores  = 2  # Было: var.cpu
  memory = var.memory
}
```

Фиксированное значение игнорирует переданный параметр `cpu`.

### Применение изменений

```bash
terraform plan
```

План покажет изменение `db_vm`: 4 cores → 2 cores.

```bash
terraform apply -auto-approve
```

Terraform остановит `db_vm`, изменит ресурсы, запустит обратно.

---

## Сравнение подходов

| Аспект | Без модуля | С модулем |
|--------|------------|-----------|
| Дублирование кода | Высокое | Минимальное |
| Количество строк (2 VM) | ~60 | ~20 |
| Изменение логики | В каждом ресурсе | В одном месте |
| Переиспользование | Невозможно | В любых проектах |
| Поддержка | Сложная | Упрощенная |

---

## Troubleshooting

### Ошибка: Changing resources requires stopping

**Ошибка:**
```
Error: Changing the resources in an instance requires stopping it.
To acknowledge this action, please set allow_stopping_for_update = true
```

**Решение:**

Добавить в `modules/vm_module/main.tf`:

```hcl
resource "yandex_compute_instance" "vm" {
  allow_stopping_for_update = true
  # ...
}
```

### Модуль не найден

**Ошибка:**
```
Module not found: ./modules/vm_module
```

**Причина:** Неправильный путь к модулю или модуль не инициализирован.

**Решение:**

```bash
terraform init
```

### Переменная не определена

**Ошибка:**
```
The argument "cpu" is required, but no definition was found
```

**Причина:** Не передан обязательный параметр при вызове модуля.

**Решение:**

Добавить параметр в блок `module`:

```hcl
module "vm" {
  source = "./modules/vm_module"
  cpu    = 2  # Добавить отсутствующий параметр
  # ...
}
```

---

## Best Practices

**Разделение ответственности**
- Модуль содержит только логику создания ресурсов
- Основная конфигурация управляет сетью и параметрами

**Версионирование модулей**
- Используйте семантическое версионирование при публикации
- Фиксируйте версии модулей в production

**Валидация входных данных**
- Добавляйте `validation` блоки для переменных
- Предотвращайте некорректные конфигурации

**Документирование**
- Заполняйте `description` для всех переменных
- Добавляйте README.md в директорию модуля

**Идемпотентность**
- Модуль должен работать корректно при повторном apply
- Избегайте зависимостей от внешнего состояния

**Минимальные зависимости**
- Передавайте только необходимые параметры
- Избегайте жесткой связи с родительской конфигурацией

---

## Полезные команды

| Команда | Описание |
|---------|----------|
| `terraform init -upgrade` | Обновление модулей и провайдеров |
| `terraform get` | Загрузка/обновление модулей без полной инициализации |
| `terraform plan -target=module.web_vm` | План изменений для конкретного модуля |
| `terraform apply -target=module.web_vm` | Применение изменений только для указанного модуля |
| `terraform state list` | Список всех ресурсов включая модульные |
| `terraform state show module.web_vm.yandex_compute_instance.vm` | Детали конкретного ресурса в модуле |
| `terraform output` | Все outputs включая модульные |
| `terraform graph` | Граф зависимостей с модулями |
