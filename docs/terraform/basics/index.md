# Terraform: Базовый Workflow

Основы работы с Terraform: инициализация проекта, управление ресурсами, применение изменений и форматирование конфигурации.

## Предварительные требования

- Terraform >= 1.0
- Права на запись в рабочей директории
- Базовое понимание HCL синтаксиса

---

## Жизненный цикл Terraform-проекта

### Инициализация проекта

Создание рабочей директории:

```bash
mkdir terraform-lab1
cd terraform-lab1
```

Создание конфигурационного файла `main.tf`:

```hcl
resource "local_file" "hello" {
  filename = "hello.txt"
  content  = "Hello from Terraform!"
}
```

Инициализация Terraform:

```bash
terraform init
```

Выполняется установка провайдера `hashicorp/local`, создается служебная структура `.terraform/` и lock-файл `.terraform.lock.hcl`.

### Планирование изменений

```bash
terraform plan
```

Команда анализирует конфигурацию и выводит план предстоящих изменений без применения к инфраструктуре.

Вывод включает:
- Ресурсы для создания (`+ create`)
- Ресурсы для изменения (`~ update`)
- Ресурсы для удаления (`- destroy`)

### Применение конфигурации

```bash
terraform apply
```

Применение требует подтверждения ввода `yes`. После выполнения создается файл состояния `terraform.tfstate`.

Проверка результата:

```bash
cat hello.txt
```

### Обновление ресурсов

Изменение атрибута `content` в `main.tf`:

```hcl
resource "local_file" "hello" {
  filename = "hello.txt"
  content  = "Terraform updated content!"
}
```

Применение изменений:

```bash
terraform apply
```

Terraform обнаруживает изменение и пересоздает ресурс.

### Повторная инициализация

```bash
terraform init
```

При повторном запуске проверяется lock-файл, установка провайдеров пропускается.

---

## Управление множественными ресурсами

### Конфигурация с несколькими ресурсами

Файл `main.tf` с двумя независимыми ресурсами:

```hcl
resource "local_file" "first" {
  filename = "first.txt"
  content  = "First file from Terraform."
}

resource "local_file" "second" {
  filename = "second.txt"
  content  = "Second file from Terraform."
}
```

Применение:

```bash
terraform apply
```

Plan отображает:
- `1 to destroy` (удаление предыдущего ресурса `hello`)
- `2 to add` (создание `first` и `second`)

Проверка созданных файлов:

```bash
ls -la *.txt
cat first.txt second.txt
```

### Форматирование конфигурации

```bash
terraform fmt
```

Автоматическое форматирование всех `.tf` файлов в директории. Команда возвращает список отформатированных файлов.

---

## Компоненты Terraform-проекта

| Файл/Директория | Назначение |
|-----------------|------------|
| `main.tf` | Основная конфигурация ресурсов |
| `.terraform/` | Установленные провайдеры и модули |
| `.terraform.lock.hcl` | Блокировка версий провайдеров |
| `terraform.tfstate` | Текущее состояние инфраструктуры |
| `terraform.tfstate.backup` | Резервная копия предыдущего состояния |

---

## Основные команды

| Команда | Описание |
|---------|----------|
| `terraform init` | Инициализация проекта, установка провайдеров |
| `terraform plan` | Предварительный просмотр изменений |
| `terraform apply` | Применение конфигурации |
| `terraform destroy` | Удаление всех управляемых ресурсов |
| `terraform fmt` | Форматирование конфигурационных файлов |
| `terraform validate` | Валидация синтаксиса конфигурации |
| `terraform show` | Просмотр текущего состояния |

---

## Жизненный цикл ресурса local_file

Ресурс `local_file` создает файл на локальной файловой системе.

**Атрибуты:**

| Атрибут | Тип | Описание |
|---------|-----|----------|
| `filename` | string | Путь к создаваемому файлу |
| `content` | string | Содержимое файла |
| `file_permission` | string | Права доступа (опционально) |

**Поведение при изменении:**

- Изменение `content` → пересоздание файла (destroy + create)
- Изменение `filename` → удаление старого, создание нового
- Изменение `file_permission` → обновление без пересоздания

---

## Troubleshooting

### Provider not found

**Ошибка:**
```
Error: Could not load plugin
```

**Причина:** Провайдер не установлен.

**Решение:**
```bash
terraform init
```

### State locked

**Ошибка:**
```
Error: Error acquiring the state lock
```

**Причина:** State заблокирован другим процессом.

**Решение:**
```bash
terraform force-unlock <LOCK_ID>
```

### File already exists

**Ошибка:**
```
Error: error creating file: file already exists
```

**Причина:** Файл существует вне управления Terraform.

**Решение:**
- Удалить файл вручную
- Импортировать в state: `terraform import local_file.resource_name ./filename`

---

## Best Practices

- Всегда выполнять `terraform plan` перед `apply`
- Хранить state в удаленном backend для командной работы
- Использовать `.gitignore` для исключения `.terraform/` и `*.tfstate`
- Применять `terraform fmt` перед commit
- Версионировать `.terraform.lock.hcl` в VCS
- Использовать переменные вместо hardcoded значений
- Регулярно создавать backup state-файлов

