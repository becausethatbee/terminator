# Полный синтаксис Terraform

Детальное описание структуры, типов данных, функций и лучших практик написания IaC кода на Terraform.

---

## Основная структура файлов

Типичный Terraform проект состоит из нескольких файлов. Каждый файл имеет свою роль, хотя Terraform обрабатывает все `.tf` файлы в каталоге как единое целое.

**main.tf** содержит основные ресурсы. Это главный файл конфигурации где описываются объекты которые нужно создать. Здесь находятся блоки `resource` и `provider`.

**variables.tf** хранит объявления переменных. Это входные параметры которые можно переопределять при apply. Каждая переменная описана типом, значением по умолчанию и описанием.

**outputs.tf** определяет выходные значения. После apply Terraform показывает эти значения. Это нужно когда нужно получить результаты (IP адреса, ID ресурсов и т.д.).

**terraform.tfvars** или `*.tfvars` файлы содержат конкретные значения переменных для разных окружений. Например, `prod.tfvars` для production и `dev.tfvars` для development.

**locals.tf** или секция `locals` в main.tf содержит локальные переменные. Это вспомогательные значения которые вычисляются внутри модуля.

---

## Блоки и их синтаксис

### Блок terraform

Блок `terraform` конфигурирует параметры самого Terraform и содержит настройки версий провайдеров.

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

`required_version` указывает минимальную версию Terraform. Синтаксис `>= 1.0` означает версию 1.0 или выше. Можно использовать `> 1.0` (строго больше), `~> 1.5` (любая 1.x где x >= 5), `>= 1.0, < 2.0` (диапазон).

`required_providers` объявляет какие провайдеры нужны для этого кода. Каждый провайдер имеет источник (откуда его скачивать) и версию. Source обычно имеет формат `namespace/type`. Hashicorp это официальный источник, но могут быть и сторонние провайдеры.

`backend` конфигурирует где хранить state файл. Без backend, state хранится локально в файле `terraform.tfstate`. С backend'ом state хранится в облаке (S3, GCS, Terraform Cloud) и может быть доступен из разных мест.

### Блок provider

Блок `provider` конфигурирует провайдер с учётными данными и регионом.

**Amazon AWS:**

```hcl
provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "eu"
  region = "eu-west-1"
}
```

**Яндекс Облако:**

```hcl
provider "yandex" {
  token     = var.yandex_token
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = "ru-central1-a"
}

provider "yandex" {
  alias     = "ru-central1-b"
  token     = var.yandex_token
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = "ru-central1-b"
}
```

Первый блок конфигурирует провайдер с параметрами по умолчанию. `default_tags` добавляет теги которые будут применены ко всем ресурсам. Это удобно когда требуется помечать все ресурсы как управляемые Terraform.

Второй блок использует провайдер для другого региона или облака. Параметр `alias` позволяет использовать несколько экземпляров одного провайдера. При создании ресурса можно указать какой провайдер использовать через `provider = aws.eu` или `provider = yandex.ru-central1-b`.

Для Яндекс Облака требуются токен аутентификации, ID облака и ID папки. Зона указывает в каком регионе создавать ресурсы (ru-central1-a, ru-central1-b, ru-central1-c).

### Блок resource

Блок `resource` объявляет ресурс который требуется создать.

**Amazon AWS:**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
}
```

**Яндекс Облако:**

```hcl
resource "yandex_compute_instance" "web" {
  name        = "web-server"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"
  
  resources {
    cores  = 2
    memory = 4
  }
  
  boot_disk {
    initialize_params {
      image_id = "fd8u0fjnochhr3nalkbl"
    }
  }
  
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }
  
  tags = {
    Name = "web-server"
  }
}
```

Структура `resource "type" "name"` где type это тип ресурса (aws_instance для AWS, yandex_compute_instance для Яндекса), а name это локальное имя используемое для обращения к ресурсу в коде. Это имя не видно в облаке, это только для Terraform.

Внутри блока находятся параметры ресурса. Каждый параметр имеет имя и значение. Параметры зависят от типа ресурса. Для AWS EC2 это ami и instance_type, для Яндекс Облака это platform_id и блоки resources, boot_disk, network_interface.

В примере Яндекса параметр `nat = true` означает что ВМ получит публичный IP адрес. Блок `resources` указывает количество ядер (cores) и объём памяти (memory) в гигабайтах.

### Блок variable

Блок `variable` объявляет входную переменную.

```hcl
variable "instance_count" {
  type        = number
  description = "Number of instances to create"
  default     = 1
  sensitive   = false
}

variable "tags" {
  type = object({
    environment = string
    team        = string
  })
  description = "Tags to apply to resources"
}

variable "environments" {
  type    = list(string)
  default = ["dev", "staging", "prod"]
}
```

Параметр `type` определяет какой тип данных может содержать переменная. Это может быть string, number, bool, list, map, set, object или any.

`description` это текст для документации. Это позволяет другим разработчикам понять что означает переменная при просмотре кода.

`default` это значение по умолчанию. Если при apply переменную не передали, будет использоваться это значение. Если default не указана, переменная становится обязательной.

`sensitive` если true, значение переменной не будет показано в output и в логах. Используется для паролей и ключей.

Также допускается добавить `validation` блок для проверки значения:

```hcl
variable "instance_type" {
  type = string
  
  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium"], var.instance_type)
    error_message = "Instance type must be t2.micro, t2.small, or t2.medium"
  }
}
```

### Блок output

Блок `output` определяет значения которые Terraform выводит после apply.

```hcl
output "instance_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP of the web server"
  sensitive   = false
}

output "instance_details" {
  value = {
    id    = aws_instance.web.id
    ip    = aws_instance.web.public_ip
    type  = aws_instance.web.instance_type
  }
  description = "Details of created instance"
}
```

`value` это выражение которое нужно вывести. Это может быть атрибут ресурса, переменная, результат функции или сложное выражение.

`description` это текст для документации.

`sensitive` если true, значение не будет показано в консоли. Полезно для вывода токенов и паролей.

После apply Terraform выводит все output'ы:

```
Outputs:

instance_ip = "54.123.45.67"
instance_details = {
  "id" = "i-0123456789abcdef0"
  "ip" = "54.123.45.67"
  "type" = "t2.micro"
}
```

### Блок locals

Блок `locals` объявляет локальные переменные которые вычисляются внутри модуля.

```hcl
locals {
  environment = "production"
  
  common_tags = {
    Environment = local.environment
    Project     = "myapp"
    ManagedBy   = "terraform"
  }
  
  instance_name = "${local.environment}-web-server"
}
```

Локальные переменные используются через `local.name`. Отличие от `variable` в том что locals нельзя переопределить извне, они всегда одни.

Locals удобны для промежуточных вычислений и избегания копипасты. Если в коде несколько мест где используется одно и то же значение, лучше создать local один раз.

### Блок data

Блок `data` получает информацию о существующих ресурсах которые не управляются Terraform.

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
}
```

Data блоки это read-only источники информации. Terraform не создаёт ничего, просто читает информацию. В примере выше мы получаем ID последнего Ubuntu образа вместо того чтобы вписывать конкретный ID.

Обращение к data блоку происходит через `data.type.name.attribute`.

### Блок module

Блок `module` подключает переиспользуемый код из другой директории.

```hcl
module "vpc" {
  source = "./modules/vpc"
  
  name       = "my-vpc"
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "my-vpc"
  }
}

module "networking" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0"
  
  name = "production-vpc"
  cidr = "10.1.0.0/16"
}
```

`source` может быть локальным путём (./modules/vpc) или удалённым (из Terraform Registry или GitHub).

`version` используется для удалённых модулей из Registry.

Остальные параметры это переменные модуля. Модуль может экспортировать output'ы которые используются как `module.vpc.output_name`.

---

## Типы данных

Terraform поддерживает несколько базовых типов данных.

**string** это текст. Используются двойные кавычки.

```hcl
variable "environment" {
  type    = string
  default = "production"
}

variable "multiline_text" {
  type = string
  default = <<-EOT
    This is a
    multiline string
  EOT
}
```

Синтаксис `<<-EOT ... EOT` используется для многострочных строк. Первый `EOT` это начало, последний `EOT` конец.

**number** это числа. Могут быть целые или с плавающей точкой.

```hcl
variable "instance_count" {
  type    = number
  default = 3
}

variable "cpu_threshold" {
  type    = number
  default = 75.5
}
```

**bool** это булево значение true или false.

```hcl
variable "enable_monitoring" {
  type    = bool
  default = true
}
```

**list** это упорядоченный набор значений одного типа. Обращение через индекс `[0]`.

```hcl
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "ports" {
  type    = list(number)
  default = [80, 443, 8080]
}
```

Индексирование начинается с нуля. `var.availability_zones[0]` это `"us-east-1a"`.

**map** это неупорядоченный набор пар ключ-значение. Обращение через ключ `["key"]`.

```hcl
variable "environment_variables" {
  type = map(string)
  default = {
    DATABASE_HOST = "localhost"
    DATABASE_PORT = "5432"
    DEBUG_MODE    = "true"
  }
}
```

Обращение `var.environment_variables["DATABASE_HOST"]` возвращает `"localhost"`.

**set** похож на list но без упорядочивания и без дубликатов.

```hcl
variable "allowed_ports" {
  type    = set(number)
  default = [80, 443, 8080]
}
```

**object** это структурированный тип с фиксированными полями.

```hcl
variable "server_config" {
  type = object({
    name          = string
    instance_type = string
    port          = number
    enabled       = bool
  })
  default = {
    name          = "web-server"
    instance_type = "t2.micro"
    port          = 80
    enabled       = true
  }
}
```

Обращение `var.server_config.name` возвращает `"web-server"`.

**any** это универсальный тип который может содержать любые значения. Используется редко, обычно для совместимости.

```hcl
variable "dynamic_value" {
  type    = any
  default = "anything"
}
```

---

## Выражения и интерполяция

Выражения позволяют вычислять значения на основе переменных, локальных значений, атрибутов ресурсов.

**Интерполяция строк** вставляет значения в строку.

```hcl
locals {
  environment = "production"
  region      = "us-east-1"
  
  name = "${local.environment}-server-in-${local.region}"
}
```

Результат будет `"production-server-in-us-east-1"`. Синтаксис `${...}` позволяет вставлять выражения внутрь строк.

**Обращение к атрибутам ресурсов** позволяет использовать параметры созданных ресурсов.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  tags = {
    Name = "web-server"
  }
}

output "instance_id" {
  value = aws_instance.web.id
}

output "instance_ip" {
  value = aws_instance.web.public_ip
}
```

После создания ресурса, его атрибуты доступны через `resource_type.resource_name.attribute`. В примере выше `aws_instance.web.id` это ID созданной ВМ.

**Условные выражения** позволяют выбирать значение на основе условия.

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = var.environment == "production" ? "t2.large" : "t2.micro"
  
  tags = {
    Name = var.create_instance ? "server-enabled" : "server-disabled"
  }
}
```

Синтаксис `condition ? value_if_true : value_if_false`. Если `environment` равна "production", используется t2.large, иначе t2.micro.

**Коллекционные выражения** работают со списками и map'ами.

```hcl
variable "ports" {
  type    = list(number)
  default = [80, 443, 8080]
}

locals {
  ports_as_string = join(",", var.ports)
}
```

`join` объединяет список в строку с разделителем.

**Условные фильтры** с помощью `for`:

```hcl
variable "instances" {
  type = list(object({
    name    = string
    enabled = bool
  }))
  default = [
    { name = "web", enabled = true },
    { name = "api", enabled = false },
    { name = "db", enabled = true }
  ]
}

locals {
  enabled_instances = [for inst in var.instances : inst.name if inst.enabled]
}
```

Результат будет `["web", "db"]` потому что отфильтровали только enabled instance'ы.

---

## Встроенные функции

Terraform имеет большой набор встроенных функций для работы со строками, списками, map'ами и числами.

### Строковые функции

`upper(string)` преобразует в верхний регистр. `upper("hello")` вернёт `"HELLO"`.

`lower(string)` преобразует в нижний регистр. `lower("HELLO")` вернёт `"hello"`.

`length(string)` возвращает длину строки. `length("hello")` вернёт 5.

`substr(string, offset, length)` возвращает подстроку. `substr("hello", 1, 3)` вернёт `"ell"`.

`concat(strings...)` объединяет строки. `concat("hello", " ", "world")` вернёт `"hello world"`.

`join(separator, list)` объединяет список в строку. `join("-", ["a", "b", "c"])` вернёт `"a-b-c"`.

`split(separator, string)` разбивает строку на список. `split("-", "a-b-c")` вернёт `["a", "b", "c"]`.

`replace(string, substring, replacement)` заменяет подстроку. `replace("hello world", "world", "terraform")` вернёт `"hello terraform"`.

`format(format_string, values...)` форматирует строку. `format("Server %s has %d cores", "web-1", 4)` вернёт `"Server web-1 has 4 cores"`.

### Числовые функции

`max(numbers...)` возвращает максимум. `max(1, 5, 3)` вернёт 5.

`min(numbers...)` возвращает минимум. `min(1, 5, 3)` вернёт 1.

`ceil(number)` округляет вверх. `ceil(4.2)` вернёт 5.

`floor(number)` округляет вниз. `floor(4.8)` вернёт 4.

### Функции для списков

`length(list)` возвращает количество элементов. `length(["a", "b", "c"])` вернёт 3.

`concat(lists...)` объединяет списки. `concat(["a"], ["b", "c"])` вернёт `["a", "b", "c"]`.

`contains(list, value)` проверяет наличие элемента. `contains(["a", "b"], "b")` вернёт true.

`index(list, value)` возвращает индекс элемента. `index(["a", "b", "c"], "b")` вернёт 1.

`reverse(list)` разворачивает список. `reverse([1, 2, 3])` вернёт `[3, 2, 1]`.

`sort(list)` сортирует список. `sort([3, 1, 2])` вернёт `[1, 2, 3]`.

`distinct(list)` удаляет дубликаты. `distinct([1, 2, 2, 3])` вернёт `[1, 2, 3]`.

`flatten(nested_list)` разворачивает вложенный список. `flatten([[1], [2, 3]])` вернёт `[1, 2, 3]`.

### Функции для map'ов

`keys(map)` возвращает список ключей. `keys({a = 1, b = 2})` вернёт `["a", "b"]`.

`values(map)` возвращает список значений. `values({a = 1, b = 2})` вернёт `[1, 2]`.

`lookup(map, key, default)` получает значение по ключу. `lookup({a = 1, b = 2}, "a", 0)` вернёт 1.

`merge(maps...)` объединяет map'ы. `merge({a = 1}, {b = 2})` вернёт `{a = 1, b = 2}`.

---

## For each и count

Это два способа создавать множество ресурсов из одного определения.

### For_each

For_each повторяет ресурс для каждого элемента map'а или set'а.

```hcl
variable "instances" {
  type = map(string)
  default = {
    "web"  = "t2.micro"
    "api"  = "t2.small"
    "db"   = "t2.medium"
  }
}

resource "aws_instance" "app" {
  for_each = var.instances
  
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = each.value
  
  tags = {
    Name = each.key
  }
}
```

`for_each = var.instances` означает что Terraform создаст три ресурса, по одному для каждой пары в map'е.

`each.key` это ключ (название экземпляра). На первой итерации это `"web"`, на второй `"api"`, на третьей `"db"`.

`each.value` это значение. На первой итерации `"t2.micro"`, на второй `"t2.small"`, на третьей `"t2.medium"`.

Обращение к созданным ресурсам: `aws_instance.app["web"].id` это ID web экземпляра.

### Count

Count повторяет ресурс заданное количество раз.

```hcl
variable "instance_count" {
  type    = number
  default = 3
}

resource "aws_instance" "app" {
  count = var.instance_count
  
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  tags = {
    Name = "app-${count.index + 1}"
  }
}
```

`count = var.instance_count` означает создать столько ресурсов сколько указано в переменной.

`count.index` это номер текущей итерации. Начинается с нуля. На первой итерации это 0, на второй 1, на третьей 2.

Обращение к созданным ресурсам: `aws_instance.app[0].id` это ID первого экземпляра, `aws_instance.app[1].id` это ID второго.

### Когда использовать

For_each лучше использовать когда нужны разные конфигурации для каждого ресурса. Например, разные type'ы instance'ов.

Count лучше когда просто нужно создать несколько одинаковых ресурсов. Например, три одинаковых ВМ для балансирования нагрузки.

For_each безопаснее при удалении элементов потому что использует ключи. Если удалить элемент из map, остальные не перенумеруются. С count если удалить элемент, остальные смещаются и переиндексируются что может привести к пересозданию ресурсов.

---

## Конкатенация и строитель конфигов

Terraform позволяет собирать сложные конфигурации динамически.

```hcl
locals {
  environment = "production"
  region      = "us-east-1"
  project     = "myapp"
  
  common_tags = {
    Environment = local.environment
    Project     = local.project
    Region      = local.region
    ManagedBy   = "terraform"
  }
  
  resource_name = "${local.project}-${local.environment}"
}

resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  
  tags = merge(
    local.common_tags,
    {
      Name = local.resource_name
      Role = "app-server"
    }
  )
}
```

`merge` объединяет несколько map'ов. В примере выше объединяются общие теги с дополнительными тегами для конкретного ресурса.

---

## Динамические блоки

Динамические блоки позволяют повторять блоки конфигурации основываясь на переменных.

```hcl
variable "security_group_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "app" {
  name = "app-sg"
  
  dynamic "ingress" {
    for_each = var.security_group_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

`dynamic "ingress"` повторяет блок ingress для каждого элемента в списке.

`for_each = var.security_group_rules` перебирает элементы списка.

`content` это содержимое блока которое повторяется.

`ingress.value` доступ к текущему элементу списка.

---

## Условная логика

Terraform позволяет создавать или пропускать ресурсы на основе условий.

```hcl
variable "create_database" {
  type    = bool
  default = false
}

variable "environment" {
  type    = string
  default = "dev"
}

resource "aws_db_instance" "app" {
  count = var.create_database ? 1 : 0
  
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "13.7"
  instance_class       = var.environment == "production" ? "db.t3.medium" : "db.t3.micro"
  identifier           = "app-db"
}

output "database_endpoint" {
  value = var.create_database ? aws_db_instance.app[0].endpoint : null
}
```

`count = var.create_database ? 1 : 0` означает создать один ресурс если create_database true, иначе ноль (не создавать).

`instance_class = var.environment == "production" ? "db.t3.medium" : "db.t3.micro"` выбирает разный тип для разных окружений.

`value = var.create_database ? aws_db_instance.app[0].endpoint : null` выводит endpoint только если база данных была создана.

---

## Зависимости между ресурсами

Terraform автоматически определяет зависимости когда один ресурс ссылается на другой. Но иногда нужно явно указать зависимость.

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_instance" "app" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  
  depends_on = [aws_subnet.private]
}
```

Обычно явная зависимость не нужна потому что `subnet_id = aws_subnet.private.id` уже создаёт неявную зависимость.

`depends_on` нужна когда есть неявные зависимости. Например, когда один ресурс должен быть создан после другого но они не связаны в конфиге.

---

## Best Practices

При написании Terraform кода следует придерживаться нескольких правил чтобы код был понятным и безопасным.

**Используются значимые имена ресурсов.** Имена должны отражать назначение ресурса. `aws_instance.web_server` понятнее чем `aws_instance.app`.

**Группируются связанные ресурсы.** При создании VPC с subnet'ами и security group, подобные ресурсы пишутся близко друг к другу.

**Используются переменные для параметров.** Конкретные значения не должны вписываться в ресурсы. Переменные используются для того чтобы переиспользовать код для разных окружений.

**Документируются переменные и output'ы.** К каждой переменной и output'у добавляется description.

**Используются locals для повторяющихся значений.** Если одно и то же значение используется в нескольких местах, создаётся local.

**Используется for_each вместо count когда это возможно.** For_each безопаснее при изменении количества ресурсов.

**Чувствительные данные хранятся в переменных.** Пароли и ключи не вписываются в конфиг. Переменные используются с `sensitive = true`.

**Modules используются для переиспользуемого кода.** Если код может быть полезен в других проектах, выносится в отдельный модуль.

**State файлы никогда не коммитятся.** `terraform.tfstate*` добавляется в `.gitignore`. State должен храниться в remote backend'е.

**Всегда выполняется terraform plan перед apply.** Проверяется что Terraform собирается делать перед тем как применить изменения.

---

## Troubleshooting

### Синтаксические ошибки

Если Terraform выводит ошибку синтаксиса, используется команда `terraform validate` для проверки синтаксиса.

```bash
terraform validate
```

Это покажет точный файл и строку где находится ошибка.

### Проблемы с интерполяцией

Если интерполяция не работает, требуется убедиться что используется правильный синтаксис `${...}` внутри строк.

```hcl
correct = "${var.name}-${local.environment}"
wrong   = "$var.name-$local.environment"
```

### Обращение к несуществующим атрибутам

Если происходит попытка обращения к атрибуту ресурса который не существует, Terraform выведет ошибку.

```bash
Error: Unsupported attribute

  on main.tf line 5, in output "instance_id":
   5:   value = aws_instance.web.invalid_attribute
```

Требуется проверить документацию провайдера какие атрибуты доступны для этого ресурса.

### Проблемы с типами данных

Если типы не совпадают, Terraform это определяет.

```hcl
variable "instance_count" {
  type    = number
  default = "three"  # Ошибка: string вместо number
}
```

Необходимо использовать правильные типы данных.

---

## Полезные команды

`terraform fmt -recursive` форматирует весь код в текущей директории и поддиректориях согласно стандартам.

`terraform validate` проверяет синтаксис и структуру конфига.

`terraform plan` показывает план изменений без применения.

`terraform apply` применяет конфигурацию и создаёт ресурсы.

`terraform destroy` удаляет все управляемые ресурсы.

`terraform state list` показывает все управляемые ресурсы.

`terraform state show resource.name` показывает атрибуты конкретного ресурса.

`terraform console` открывает интерактивную консоль для тестирования выражений.

`terraform output` показывает все output'ы.

`terraform output name -raw` показывает значение output'а без кавычек.
