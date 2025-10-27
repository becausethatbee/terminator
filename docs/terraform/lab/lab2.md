# Работа со State

Работа со state файлом: удаление ресурсов без удаления файлов, переименование и переимпортирование ресурсов.

---

## Удаление ресурса из State без удаления файла

Команда `terraform state rm` удаляет ресурс из state, но не удаляет сам файл на диске. Это полезно при миграции ресурсов или разделении конфигурации.

**Конфигурация:**

```hcl
resource "local_file" "state_test" {
  filename = "state_test.txt"
  content  = "This is state test file."
}
```

Создание ресурса:

```bash
terraform apply -auto-approve
```

Ресурс в state:

```bash
terraform state list
```

Удаление из state (файл остаётся):

```bash
terraform state rm local_file.state_test
```

Проверка state:

```bash
terraform state list
```

Проверка что файл остался на диске:

```bash
ls -la state_test.txt
cat state_test.txt
```

**Результат:** Ресурс удалён из state, но файл сохранился на диске. Terraform больше не отслеживает этот ресурс.

---

## Переименование ресурса в State

Переименование ресурса в конфигурации требует синхронизации state через `terraform state mv`.

**Исходная конфигурация:**

```hcl
resource "local_file" "old_name" {
  filename = "my_example.txt"
  content  = "Example file for rename test."
}
```

Применение конфигурации:

```bash
terraform apply -auto-approve
```

Проверка state:

```bash
terraform state list
```

Изменение имени ресурса в конфиге:

```bash
sed -i 's/resource "local_file" "old_name"/resource "local_file" "new_name"/' main.tf
```

Синхронизация state:

```bash
terraform state mv local_file.old_name local_file.new_name
```

Проверка обновленного state:

```bash
terraform state list
```

Проверка что файл на месте:

```bash
ls -la my_example.txt
```

**Результат:** Ресурс переименован в state, файл не затронут, Terraform отслеживает ресурс под новым именем.

---

## Операции с State

| Операция | Команда | Описание |
|----------|---------|----------|
| Список ресурсов | `terraform state list` | Показывает все управляемые ресурсы |
| Показать ресурс | `terraform state show <resource>` | Выводит атрибуты ресурса |
| Удалить ресурс | `terraform state rm <resource>` | Убирает ресурс из state (файл не удаляется) |
| Переместить ресурс | `terraform state mv <old> <new>` | Переименовывает или перемещает ресурс |
| Вытащить из другого state | `terraform state pull` | Экспортирует текущий state |
| Закинуть новый state | `terraform state push <file>` | Импортирует state из файла |

---

## Troubleshooting

### State desync после удаления ресурса вручную

**Ошибка:**

```
Error: resource local_file.state_test does not exist in configuration
```

**Причина:** Файл удалён вручную, но Terraform ещё отслеживает ресурс в state.

**Решение:**

```bash
terraform state rm local_file.state_test
```

### Ошибка при переименовании несуществующего ресурса

**Ошибка:**

```
Error: resource local_file.old_name does not exist in state
```

**Причина:** Ресурс уже был удалён из state или имя указано неправильно.

**Решение:**

```bash
terraform state list
```

Проверить актуальное имя и повторить команду `terraform state mv`.

### State conflict после ручного редактирования файла

**Ошибка:**

```
Error reading state: invalid character
```

**Причина:** Некорректный JSON в terraform.tfstate.

**Решение:**

```bash
cp terraform.tfstate.backup terraform.tfstate
terraform state push terraform.tfstate
```

Восстановиться из backup и заново применить конфигурацию.

---

## Best Practices

- **Резервная копия:** Terraform автоматически создаёт `.backup` файл перед изменениями state. Версионирование в CI/CD должно быть настроено.

- **Удаление vs Переименование:** Если нужно переместить ресурс — следует использовать `state mv`, не удалять и не пересоздавать.

- **State lock:** В production должен использоваться remote state с блокировкой (S3 + DynamoDB, Terraform Cloud, Consul).

- **Audit trail:** Изменения state должны отслеживаться через git или мониторинг remote storage.

- **Никогда не редактируй state вручную:** Только через `terraform state` команды.

- **Проверка перед apply:** `terraform plan` должен быть выполнен перед `terraform apply`.

---

## Полезные команды

**Просмотр определённого ресурса:**

```bash
terraform state show local_file.state_test
```

**Экспорт state в JSON:**

```bash
terraform state pull > state_export.json
```

**Импорт существующего файла в state:**

```bash
terraform import local_file.existing /path/to/file
```

**Удаление всех ресурсов и state:**

```bash
terraform destroy
```

**Проверка синтаксиса конфигурации:**

```bash
terraform validate
```

**Форматирование конфигурации:**

```bash
terraform fmt -recursive
```
