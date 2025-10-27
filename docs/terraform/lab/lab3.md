# Переменные, Locals и Functions в Terraform

Управление переменными, локальными значениями и встроенными функциями для динамической генерации ресурсов.

## Переменные и Locals

**Переменные (variables.tf)** — входные параметры, которые можно переопределить при apply.

**Locals** — локальные значения внутри модуля, доступны только в текущем проекте.

Структура файлов:

```bash
mkdir -p files
cat > variables.tf << 'EOF'
variable "filename" {
  type        = string
  description = "Name of the file"
  default     = "test.txt"
}

variable "content" {
  type        = string
  description = "Content of the file"
  default     = "Hello from Terraform"
}
EOF
```

---

## Задание 1: Переменные, Locals и Output

Создание файла с использованием локального пути.

**Конфигурация:**

```hcl
locals {
  file_path = "${path.module}/files/${var.filename}"
}

resource "local_file" "task1" {
  filename = local.file_path
  content  = var.content
}
```

Применение:

```bash
terraform apply -auto-approve
```

Проверка файла:

```bash
cat files/test.txt
```

**Output:**

```hcl
output "file_path" {
  value       = local_file.task1.filename
  description = "Path to created file"
}
```

Просмотр пути:

```bash
terraform output file_path
```

**Результат:** Переменная `filename` объединена с переменной `content` через `locals`. Ресурс создан в директории `files/`. Output возвращает полный путь к файлу.

---

## Задание 2: For_each для множественных ресурсов

Создание нескольких файлов из map структуры.

**Переменная с map:**

```hcl
variable "files_map" {
  type        = map(string)
  description = "Map of filenames to content"
  default = {
    "file1.txt" = "Content of file 1"
    "file2.txt" = "Content of file 2"
    "file3.txt" = "Content of file 3"
  }
}
```

**Ресурс с for_each:**

```hcl
resource "local_file" "task2" {
  for_each = var.files_map
  
  filename = "${path.module}/files/${each.key}"
  content  = each.value
}
```

Применение:

```bash
terraform apply -auto-approve
```

Проверка всех файлов:

```bash
ls -la files/
```

**Результат:** Для каждой пары ключ-значение в map создаётся отдельный ресурс. `each.key` — имя файла, `each.value` — его содержимое.

| Элемент | Описание |
|---------|----------|
| `each.key` | Ключ из map (имя файла) |
| `each.value` | Значение из map (содержимое) |
| `each.self` | Полный объект map элемента |

---

## Задание 3: Функции Join и Upper

Обработка списка строк через встроенные функции.

**Переменная со списком:**

```hcl
variable "strings_list" {
  type        = list(string)
  description = "List of strings to join"
  default     = ["terraform", "is", "awesome"]
}
```

**Ресурс с функциями:**

```hcl
resource "local_file" "task3" {
  filename = "${path.module}/files/task3_output.txt"
  content  = upper(join(" ", var.strings_list))
}
```

Применение:

```bash
terraform apply -auto-approve
```

Проверка:

```bash
cat files/task3_output.txt
```

**Output:**

```hcl
output "task3_content" {
  value       = local_file.task3.content
  description = "Joined and uppercased content"
}
```

**Результат:** `join(" ", var.strings_list)` объединяет список с разделителем "пробел". `upper()` преобразует в верхний регистр. Итог: "TERRAFORM IS AWESOME"

---

## Встроенные функции

| Функция | Пример | Результат |
|---------|--------|-----------|
| `join(sep, list)` | `join(",", ["a","b"])` | "a,b" |
| `upper(str)` | `upper("hello")` | "HELLO" |
| `lower(str)` | `lower("HELLO")` | "hello" |
| `concat(list1, list2)` | `concat([1], [2])` | [1, 2] |
| `contains(list, item)` | `contains(["a"], "a")` | true |
| `length(value)` | `length([1,2,3])` | 3 |
| `reverse(list)` | `reverse([1,2,3])` | [3, 2, 1] |
| `sort(list)` | `sort([3,1,2])` | [1, 2, 3] |
| `flatten(nested)` | `flatten([[1],[2]])` | [1, 2] |
| `merge(map1, map2)` | `merge({a=1},{b=2})` | {a=1, b=2} |

---

## For_each vs Count

**For_each:**

```hcl
resource "local_file" "files" {
  for_each = var.files_map
  filename = each.key
  content  = each.value
}
```

Применяется для map или set. При добавлении/удалении элементов не перестраивает индексы.

**Count:**

```hcl
resource "local_file" "files" {
  count    = length(var.files_list)
  filename = var.files_list[count.index]
  content  = "File ${count.index}"
}
```

Применяется для списков. При изменении порядка может перестроить все ресурсы.

**Рекомендация:** `for_each` должен использоваться для map/set, `count` для простого масштабирования по числу.

---

## Типы переменных

```hcl
variable "string_var" {
  type = string
  default = "hello"
}

variable "number_var" {
  type = number
  default = 42
}

variable "bool_var" {
  type = bool
  default = true
}

variable "list_var" {
  type = list(string)
  default = ["a", "b", "c"]
}

variable "map_var" {
  type = map(string)
  default = {
    key1 = "value1"
    key2 = "value2"
  }
}

variable "object_var" {
  type = object({
    name = string
    age  = number
  })
  default = {
    name = "John"
    age  = 30
  }
}
```

---

## Locals vs Variables

| Аспект | Variables | Locals |
|--------|-----------|--------|
| Переопределение | Да (`terraform apply -var`) | Нет |
| Область видимости | Модуль и родители | Только текущий модуль |
| Использование | Входные параметры | Промежуточные вычисления |
| Пример | `var.filename` | `local.file_path` |

---

## Best Practices

- **Default значения:** Sensible defaults должны быть заданы для большинства переменных.

- **Описания:** `description` должен быть указан для каждой переменной.

- **Валидация:** `validation` блоки должны использоваться для сложных проверок.

```hcl
variable "filename" {
  type = string
  validation {
    condition     = can(regex("\\.txt$", var.filename))
    error_message = "Filename must end with .txt"
  }
}
```

- **Locals для вычислений:** Locals должны использоваться для промежуточных значений вместо дублирования в ресурсах.

- **Именование:** Переменные в snake_case, значения по смыслу (`environment`, `region`, `instance_count`).

- **Чувствительные данные:** `sensitive = true` должен быть указан для паролей и ключей.

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

---

## Полезные команды

**Просмотр всех переменных:**

```bash
terraform console
> var.filename
> local.file_path
```

**Валидация синтаксиса:**

```bash
terraform validate
```

**Форматирование конфигурации:**

```bash
terraform fmt -recursive
```

**Просмотр plan с переменными:**

```bash
terraform plan -var="filename=custom.txt"
```

**Вывод всех outputs:**

```bash
terraform output
```

**Вывод конкретного output:**

```bash
terraform output file_path
```

**Список управляемых ресурсов с for_each:**

```bash
terraform state list
```
