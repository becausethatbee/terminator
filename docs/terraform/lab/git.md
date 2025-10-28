# Публикация Terraform модуля в Git

Вынос Terraform модуля в отдельный Git репозиторий для переиспользования в различных проектах.

## Предварительные требования

- Git >= 2.0
- Доступ к Git платформе (GitHub/GitLab/Bitbucket)
- SSH ключ настроен для Git
- Готовый Terraform модуль
- Terraform >= 1.0

---

## Подготовка модуля

### Копирование файлов модуля

```bash
mkdir terraform-vm-module
cd terraform-vm-module
cp -r /path/to/project/modules/vm_module/* .
```

Структура директории модуля:

```
terraform-vm-module/
├── main.tf
├── variables.tf
└── outputs.tf
```

### Валидация структуры

```bash
ls -la
```

Модуль должен содержать минимум три файла: `main.tf`, `variables.tf`, `outputs.tf`.

---

## Инициализация Git репозитория

### Локальный репозиторий

```bash
git init
git add .
git commit -m "Initial commit: VM module for Yandex Cloud"
```

Создается локальный git репозиторий с первым коммитом.

### Проверка статуса

```bash
git status
git log --oneline
```

Репозиторий готов к публикации в удаленное хранилище.

---

## Публикация в GitLab

### Создание репозитория

Через веб-интерфейс GitLab:

1. New project → Create blank project
2. Project name: `terraform-vm-module`
3. Visibility Level: **Public**
4. Снять галочку "Initialize repository with a README"
5. Create project

Публичный доступ обязателен для использования модуля в Terraform без аутентификации.

### Проверка SSH доступа

```bash
ssh -T git@gitlab.com
```

Ожидаемый ответ: `Welcome to GitLab, @username!`

### Добавление remote

```bash
git remote add origin git@gitlab.com:<USERNAME>/<REPO_NAME>.git
git branch -M main
```

Связывает локальный репозиторий с удаленным и переименовывает ветку в `main`.

### Push в репозиторий

```bash
git push -u origin main
```

Отправляет код модуля в GitLab. При первом push GitLab инициализирует репозиторий.

---

## Использование модуля из Git

### Удаление локального модуля

```bash
cd /path/to/terraform/project
rm -rf modules/
rm -rf .terraform/
```

Удаление локальной копии модуля и кэша Terraform.

### Изменение source в конфигурации

Файл `main.tf`:

```hcl
module "web_vm" {
  source = "git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git"

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
  source = "git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git"

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

Префикс `git::` указывает Terraform использовать git для загрузки модуля.

### Инициализация с git модулем

```bash
terraform init
```

Terraform клонирует репозиторий и размещает модуль в `.terraform/modules/`.

Вывод показывает:
```
Downloading git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git for web_vm...
Downloading git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git for db_vm...
```

### Применение конфигурации

```bash
terraform apply -auto-approve
```

Создание инфраструктуры с использованием модуля из Git репозитория.

---

## Версионирование модулей

### Создание тега

```bash
cd terraform-vm-module
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

Тег фиксирует версию модуля для стабильных релизов.

### Использование конкретной версии

```hcl
module "web_vm" {
  source = "git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git?ref=v1.0.0"

  vm_name = "web-server-01"
  # ...
}
```

Параметр `?ref=` указывает на конкретный тег, ветку или коммит.

### Использование ветки

```hcl
module "web_vm" {
  source = "git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git?ref=develop"

  vm_name = "web-server-01"
  # ...
}
```

### Использование коммита

```hcl
module "web_vm" {
  source = "git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git?ref=abc123"

  vm_name = "web-server-01"
  # ...
}
```

---

## Источники модулей

| Источник | Формат | Пример |
|----------|--------|--------|
| Локальный путь | `./path/to/module` | `source = "./modules/vm_module"` |
| Git HTTPS | `git::https://` | `source = "git::https://gitlab.com/user/repo.git"` |
| Git SSH | `git::ssh://` | `source = "git::ssh://git@gitlab.com/user/repo.git"` |
| GitHub сокращенный | `github.com` | `source = "github.com/user/repo"` |
| GitLab сокращенный | `gitlab.com` | `source = "gitlab.com/user/repo"` |
| Terraform Registry | `registry` | `source = "registry.terraform.io/user/module"` |
| Git с тегом | `?ref=tag` | `source = "git::https://...?ref=v1.0.0"` |
| Git с веткой | `?ref=branch` | `source = "git::https://...?ref=main"` |
| Git с коммитом | `?ref=commit` | `source = "git::https://...?ref=abc123"` |
| Поддиректория | `//subdir` | `source = "git::https://.../repo.git//modules/vm"` |

---

## Обновление модуля

### Внесение изменений

```bash
cd terraform-vm-module
nano main.tf
git add .
git commit -m "Update: increase default disk size"
git push origin main
```

### Обновление в проекте

```bash
cd /path/to/terraform/project
terraform init -upgrade
```

Параметр `-upgrade` заставляет Terraform загрузить последнюю версию модуля.

### Без версионирования

При отсутствии `?ref=` Terraform использует HEAD ветки по умолчанию (main/master).

### С версионированием

При использовании `?ref=v1.0.0` обновление требует изменения тега в конфигурации:

```hcl
source = "git::https://gitlab.com/<USERNAME>/<REPO_NAME>.git?ref=v1.1.0"
```

Затем:

```bash
terraform init -upgrade
```

---

## Troubleshooting

### Permission denied (publickey)

**Ошибка:**
```
Permission denied (publickey)
fatal: Could not read from remote repository
```

**Причина:** SSH ключ не добавлен в GitLab или используется неправильный ключ.

**Решение:**

Проверить SSH ключ:

```bash
cat ~/.ssh/id_ed25519.pub
```

Добавить в GitLab: Settings → SSH Keys → Add new key.

Альтернатива - использовать HTTPS:

```bash
git remote set-url origin https://gitlab.com/<USERNAME>/<REPO_NAME>.git
```

### Project not found

**Ошибка:**
```
ERROR: The project you were looking for could not be found
```

**Причина:** Репозиторий не существует или URL неправильный.

**Решение:**

Проверить URL репозитория:

```bash
git remote -v
```

Создать репозиторий в GitLab если не существует.

### Module not found

**Ошибка:**
```
Error: Module not found: git::https://...
```

**Причина:** Репозиторий приватный или Terraform не может клонировать.

**Решение:**

Сделать репозиторий публичным: Settings → General → Visibility → Public.

Или настроить git credentials для приватных репозиториев.

### Failed to load module

**Ошибка:**
```
Error downloading modules: Error loading modules
```

**Причина:** Некорректная структура модуля в репозитории.

**Решение:**

Проверить что в корне репозитория есть `main.tf`, `variables.tf`, `outputs.tf`.

### Cached module not updated

**Проблема:** Изменения в git не применяются после push.

**Причина:** Terraform использует закэшированную версию модуля.

**Решение:**

```bash
rm -rf .terraform/modules/
terraform init
```

Или:

```bash
terraform init -upgrade
```

---

## Best Practices

**Семантическое версионирование**
- Используйте формат `vMAJOR.MINOR.PATCH`
- MAJOR - breaking changes
- MINOR - новый функционал, обратная совместимость
- PATCH - исправления без изменения API

**Документация модуля**
- README.md с описанием использования
- Примеры конфигураций в `examples/`
- CHANGELOG.md для отслеживания изменений

**Структура репозитория**

```
terraform-vm-module/
├── main.tf
├── variables.tf
├── outputs.tf
├── README.md
├── CHANGELOG.md
└── examples/
    └── basic/
        └── main.tf
```

**Фиксация версий**
- Production конфигурации должны использовать `?ref=v1.0.0`
- Development может использовать ветку `?ref=develop`
- Избегайте использования без `?ref=` в production

**Тестирование перед релизом**
- Создавайте feature ветки для разработки
- Тестируйте изменения перед созданием тега
- Используйте pre-commit hooks для валидации

**CI/CD для модулей**
- Автоматическая валидация `terraform validate`
- Форматирование `terraform fmt -check`
- Документирование с terraform-docs
- Семантические коммиты для автогенерации версий

---

## Полезные команды

| Команда | Описание |
|---------|----------|
| `terraform init -upgrade` | Обновление всех модулей до последних версий |
| `terraform get` | Загрузка модулей без инициализации провайдеров |
| `git tag -l` | Список всех тегов в репозитории модуля |
| `git tag -a v1.0.0 -m "message"` | Создание аннотированного тега |
| `git push origin --tags` | Push всех тегов в удаленный репозиторий |
| `git tag -d v1.0.0` | Удаление локального тега |
| `git push origin :refs/tags/v1.0.0` | Удаление удаленного тега |
| `terraform providers lock` | Создание lock файла для провайдеров |
| `rm -rf .terraform/modules/` | Очистка кэша модулей |
