# Ansible Vault - Шифрование секретных данных

Практическое руководство по безопасному хранению паролей, токенов и других конфиденциальных данных в Ansible проектах.

## Что такое Ansible Vault

**Ansible Vault** - встроенный инструмент для шифрования конфиденциальных данных в Ansible проектах.

**Основные возможности:**
- Шифрование файлов с переменными
- Шифрование отдельных строк внутри файлов
- Алгоритм шифрования AES256
- Интеграция с playbooks без изменения кода

## Подготовка окружения

Создание структуры проекта:

```bash
mkdir -p vault-practice/group_vars/all
cd vault-practice
```

Создание inventory файла:

```bash
cat > inventory.yml << 'EOF'
all:
  hosts:
    localhost:
      ansible_connection: local
EOF
```

## Создание файла с секретными данными

Создание файла с конфиденциальными переменными (до шифрования):

```bash
cat > group_vars/all/vault.yml << 'EOF'
---
# Тестовые секретные переменные
vault_db_password: "MySecretPassword123"
vault_api_token: "test-token-1234567890"
vault_admin_user: "admin"
vault_admin_password: "AdminPass2024"
EOF
```

Проверка содержимого:

```bash
cat group_vars/all/vault.yml
```

Результат:

```
---
# Тестовые секретные переменные
vault_db_password: "MySecretPassword123"
vault_api_token: "test-token-1234567890"
vault_admin_user: "admin"
vault_admin_password: "AdminPass2024"
```

**Структура директорий:**

```
vault-practice/
├── inventory.yml
└── group_vars/
    └── all/
        └── vault.yml    # Файл с секретами
```

**Почему именно эта структура:**
- `group_vars/all/` - переменные доступны всем хостам в группе "all"
- `vault.yml` - стандартное имя для vault-файлов
- Префикс `vault_` - соглашение для различия зашифрованных переменных

## Шифрование файла

Базовое шифрование существующего файла:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

При выполнении Ansible запросит пароль дважды:

```
New Vault password: ********
Confirm New Vault password: ********
Encryption successful
```

**Что происходит при шифровании:**
1. Ansible запрашивает пароль шифрования
2. Файл шифруется алгоритмом AES256
3. Оригинальное содержимое заменяется на зашифрованное
4. Файл помечается заголовком `$ANSIBLE_VAULT;1.1;AES256`

Просмотр зашифрованного файла:

```bash
cat group_vars/all/vault.yml
```

Результат:

```
$ANSIBLE_VAULT;1.1;AES256
31666262353934393830623833613065356166303036663366313332333062653130366137643733
6334346330373237636561356364306337613064623062330a393562306532366264633864363866
35353130343539613037393466386434383838633934633132306231646132393963353439323761
3864363334663932330a373437316664326461396163393761653935333530393437323033353862
62653830303232376433343463373637613065653039356339613565353162316463623866656431
31383030326465653031386661616430666565366265663439346263373136346137356430313061
65663536616439383230646564373461613139356239376637353938643539623634376130343130
61623735653164393439366633383435336630623939343162313963623161636132373666636433
```

## Работа с зашифрованными файлами

### Просмотр содержимого

Временный просмотр без расшифровки файла:

```bash
ansible-vault view group_vars/all/vault.yml
```

Ansible запросит пароль и покажет расшифрованное содержимое:

```
Vault password: ********

---
# Тестовые секретные переменные
vault_db_password: "MySecretPassword123"
vault_api_token: "test-token-1234567890"
vault_admin_user: "admin"
vault_admin_password: "AdminPass2024"
```

### Редактирование зашифрованного файла

Безопасное редактирование с автоматической расшифровкой/шифровкой:

```bash
ansible-vault edit group_vars/all/vault.yml
```

Последовательность действий:
1. Ansible запрашивает пароль
2. Расшифровывает файл
3. Открывает в текстовом редакторе
4. После сохранения автоматически шифрует обратно

### Изменение пароля шифрования

Смена пароля на новый:

```bash
ansible-vault rekey group_vars/all/vault.yml
```

Последовательность:

```
Vault password: ******** (старый пароль)
New Vault password: ******** (новый пароль)
Confirm New Vault password: ********
Rekey successful
```

### Расшифровка файла

Полная расшифровка (убирает шифрование):

```bash
ansible-vault decrypt group_vars/all/vault.yml
```

**Внимание:** после этого файл станет читаемым в открытом виде.

## Использование зашифрованных переменных в Playbook

### Автоматическая загрузка переменных

Ansible автоматически загружает переменные из:
- `group_vars/all/` - для всех хостов
- `group_vars/<имя_группы>/` - для конкретной группы
- `host_vars/<имя_хоста>/` - для конкретного хоста

Создание тестового playbook:

```bash
cat > test-vault.yml << 'EOF'
---
- name: "Тест Ansible Vault переменных"
  hosts: localhost
  gather_facts: no
  
  tasks:
    - name: "Попытка вывести зашифрованную переменную"
      debug:
        msg: "DB Password: {{ vault_db_password }}"
    
    - name: "Вывод API токена"
      debug:
        msg: "API Token: {{ vault_api_token }}"
    
    - name: "Использование в реальной задаче"
      shell: echo "User {{ vault_admin_user }} logged in"
      register: result
    
    - name: "Показать результат"
      debug:
        msg: "{{ result.stdout }}"
EOF
```

### Запуск без пароля (будет ошибка)

Попытка запуска playbook без предоставления пароля:

```bash
ansible-playbook -i inventory.yml test-vault.yml
```

Результат:

```
PLAY [Тест Ansible Vault переменных] **************************

[ERROR]: Attempting to decrypt but no vault secrets found.
```

**Причина ошибки:** Ansible видит зашифрованный файл, но не может его расшифровать без пароля.

### Запуск с паролем (успешно)

Способ 1 - интерактивный ввод пароля:

```bash
ansible-playbook -i inventory.yml test-vault.yml --ask-vault-pass
```

Результат выполнения:

```
Vault password: ********

PLAY [Тест Ansible Vault переменных] **************************

TASK [Попытка вывести зашифрованную переменную] ***************
ok: [localhost] => {
    "msg": "DB Password: MySecretPassword123"
}

TASK [Вывод API токена] ****************************************
ok: [localhost] => {
    "msg": "API Token: test-token-1234567890"
}

TASK [Использование в реальной задаче] ************************
changed: [localhost]

TASK [Показать результат] **************************************
ok: [localhost] => {
    "msg": "User admin logged in"
}

PLAY RECAP *****************************************************
localhost                  : ok=4    changed=1    failed=0
```

## Автоматизация с файлом пароля

### Создание файла с паролем

Для автоматизации без интерактивного ввода:

```bash
echo "test123" > .vault_pass
chmod 600 .vault_pass
```

**Важно:** файл с паролем должен быть защищен от чтения другими пользователями.

Добавление в .gitignore:

```bash
echo ".vault_pass" >> .gitignore
```

### Запуск с файлом пароля

Запуск playbook без интерактивного ввода:

```bash
ansible-playbook -i inventory.yml test-vault.yml --vault-password-file .vault_pass
```

Playbook выполнится автоматически без запроса пароля.

### Использование переменной окружения

Установка пароля через переменную окружения:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_pass
```

Запуск playbook (пароль подтягивается автоматически):

```bash
ansible-playbook -i inventory.yml test-vault.yml
```

## Шифрование отдельных строк

Можно шифровать отдельные строки вместо целого файла.

Шифрование конкретной строки:

```bash
ansible-vault encrypt_string 'SuperSecretPassword123!' --name 'vault_db_password'
```

Результат для вставки в YAML:

```yaml
vault_db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653832323234323863393633306364633462613461363130363662663430383633303561
          3131303539366237303336333937306633313533633061370a613835383564666161383565616234
```

Использование в файле переменных:

```yaml
# group_vars/all/vars.yml
---
# Обычные переменные (не зашифрованы)
db_host: "localhost"
db_port: 5432
db_name: "production"

# Зашифрованная строка
vault_db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653832323234323863393633306364633462613461363130363662663430383633303561
          3131303539366237303336333937306633313533633061370a613835383564666161383565616234
```

**Преимущества этого подхода:**
- Видны обычные переменные в открытом виде
- Зашифрованы только критичные данные
- Легче работать с Git diff

## Реальные сценарии использования

### Credentials для подключения к сервисам

```yaml
# group_vars/production/vault.yml (зашифровано)
vault_db_host: "prod-db.company.com"
vault_db_user: "app_user"
vault_db_password: "SuperSecret123"
vault_db_port: 5432
```

Использование в playbook:

```yaml
- name: "Настройка приложения"
  template:
    src: app-config.j2
    dest: /etc/app/config.ini
  vars:
    db_host: "{{ vault_db_host }}"
    db_pass: "{{ vault_db_password }}"
```

### API токены и ключи

```yaml
# Зашифрованные токены
vault_github_token: "ghp_xxxxxxxxxxxxx"
vault_docker_registry_password: "xxxxx"
vault_slack_webhook: "https://hooks.slack.com/services/xxxxx"
vault_aws_access_key: "AKIAIOSFODNN7EXAMPLE"
vault_aws_secret_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCY"
```

### SSL/TLS сертификаты и приватные ключи

```yaml
# Зашифрованные сертификаты
vault_ssl_certificate: |
  -----BEGIN CERTIFICATE-----
  MIIDXTCCAkWgAwIBAgIJAKL...
  -----END CERTIFICATE-----

vault_ssl_private_key: |
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA1qL...
  -----END RSA PRIVATE KEY-----
```

### Создание пользователей с паролями

```yaml
- name: "Создать пользователей"
  user:
    name: "{{ item.name }}"
    password: "{{ item.password | password_hash('sha512') }}"
  loop:
    - name: admin
      password: "{{ vault_admin_password }}"
    - name: deploy
      password: "{{ vault_deploy_password }}"
```

## Best Practices

### Организация файлов

Разделение обычных и зашифрованных переменных:

```
group_vars/
├── all/
│   ├── vars.yml      # Обычные переменные (не секретные)
│   └── vault.yml     # Зашифрованные переменные
├── production/
│   ├── vars.yml
│   └── vault.yml
└── staging/
    ├── vars.yml
    └── vault.yml
```

### Именование переменных

Используйте префиксы для vault-переменных:

```yaml
# Хорошо - явно видно что зашифровано
vault_db_password: "secret"
vault_api_key: "secret"
vault_aws_access_key: "secret"

# Плохо - неясно откуда переменная
password: "secret"
api_key: "secret"
```

### Безопасность паролей

Файлы с паролями НЕ коммитить в Git:

```bash
# .gitignore
.vault_pass
*.vault
.vault_pass_*
```

Использовать разные пароли для разных окружений:

```
.vault_pass_dev
.vault_pass_staging
.vault_pass_prod
```

### Ротация секретов

Регулярно меняйте пароли шифрования:

```bash
ansible-vault rekey group_vars/all/vault.yml
```

### CI/CD интеграция

В GitLab CI / GitHub Actions пароль хранится в секретных переменных:

```yaml
# .gitlab-ci.yml
deploy:
  script:
    - echo $VAULT_PASSWORD > .vault_pass
    - ansible-playbook playbook.yml --vault-password-file .vault_pass
  after_script:
    - rm -f .vault_pass
```

### Интеграция с менеджерами секретов

Использование HashiCorp Vault:

```bash
# Пароль берется из HashiCorp Vault
vault kv get -field=ansible_vault_pass secret/ansible > .vault_pass
ansible-playbook playbook.yml --vault-password-file .vault_pass
rm -f .vault_pass
```

Использование AWS Secrets Manager:

```bash
# Пароль из AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id ansible-vault-pass \
  --query SecretString --output text > .vault_pass
ansible-playbook playbook.yml --vault-password-file .vault_pass
rm -f .vault_pass
```

## Зачем нужен файл с паролем

**Локально файл .vault_pass бессмысленен** (незашифрованный пароль на диске).

**Реальные сценарии использования:**

**1. CI/CD пайплайны:**
- Пароль хранится в секретных переменных GitLab/GitHub
- Динамически создается файл при деплое
- Удаляется после выполнения

**2. Production серверы с ограниченным доступом:**
- Файл `.vault_pass` только на сервере деплоя
- Права доступа `chmod 600` (только владелец)
- Доступ к серверу имеют только DevOps инженеры

**3. Автоматизация без человеческого участия:**
- Cron задачи
- Автоматические обновления конфигураций
- Scheduled pipelines

## Команды Ansible Vault

Полный справочник команд:

```bash
# Шифрование файла
ansible-vault encrypt file.yml

# Расшифровка файла
ansible-vault decrypt file.yml

# Просмотр содержимого
ansible-vault view file.yml

# Редактирование
ansible-vault edit file.yml

# Смена пароля
ansible-vault rekey file.yml

# Шифрование строки
ansible-vault encrypt_string 'secret' --name 'variable_name'

# Создание нового зашифрованного файла
ansible-vault create new_file.yml
```

Опции для playbook:

```bash
# Интерактивный ввод пароля
ansible-playbook playbook.yml --ask-vault-pass

# Файл с паролем
ansible-playbook playbook.yml --vault-password-file .vault_pass

# Несколько vault паролей
ansible-playbook playbook.yml --vault-id dev@.vault_pass_dev --vault-id prod@.vault_pass_prod

```
