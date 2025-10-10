# Ansible Vault

Встроенный инструмент шифрования конфиденциальных данных с использованием AES256.

## Функциональность

- Шифрование файлов с переменными
- Шифрование отдельных строк
- Интеграция с playbooks
- Управление паролями шифрования

---

## Подготовка

Структура проекта:

```bash
mkdir -p vault-practice/group_vars/all
cd vault-practice
```

Inventory файл:

```bash
cat > inventory.yml << 'EOF'
all:
  hosts:
    localhost:
      ansible_connection: local
EOF
```

---

## Создание файла с секретами

Файл `group_vars/all/vault.yml`:

```yaml
---
vault_db_password: "<DB_PASSWORD>"
vault_api_token: "<API_TOKEN>"
vault_admin_user: "<ADMIN_USER>"
vault_admin_password: "<ADMIN_PASSWORD>"
```

Структура:

```
vault-practice/
├── inventory.yml
└── group_vars/
    └── all/
        └── vault.yml
```

Соглашение именования:
- `group_vars/all/` - переменные для группы "all"
- `vault.yml` - стандартное имя
- `vault_` - префикс для зашифрованных переменных

---

## Шифрование файла

Базовое шифрование:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

Ansible запрашивает пароль дважды:

```
New Vault password: ********
Confirm New Vault password: ********
Encryption successful
```

Процесс шифрования:
1. Запрос пароля
2. Шифрование AES256
3. Замена содержимого
4. Добавление заголовка `$ANSIBLE_VAULT;1.1;AES256`

Просмотр зашифрованного файла:

```bash
cat group_vars/all/vault.yml
```

---

## Работа с зашифрованными файлами

### Просмотр

Временный просмотр:

```bash
ansible-vault view group_vars/all/vault.yml
```

### Редактирование

Безопасное редактирование:

```bash
ansible-vault edit group_vars/all/vault.yml
```

Последовательность:
1. Запрос пароля
2. Расшифровка
3. Открытие в редакторе
4. Автоматическое шифрование после сохранения

### Изменение пароля

```bash
ansible-vault rekey group_vars/all/vault.yml
```

### Расшифровка

Полная расшифровка:

```bash
ansible-vault decrypt group_vars/all/vault.yml
```

---

## Использование в Playbook

Ansible автоматически загружает переменные из:
- `group_vars/all/`
- `group_vars/<group_name>/`
- `host_vars/<hostname>/`

Тестовый playbook `test-vault.yml`:

```yaml
---
- name: Test Vault variables
  hosts: localhost
  gather_facts: no
  
  tasks:
    - name: Display vault variable
      ansible.builtin.debug:
        msg: "DB Password: {{ vault_db_password }}"
    
    - name: Display API token
      ansible.builtin.debug:
        msg: "API Token: {{ vault_api_token }}"
    
    - name: Use vault variable
      ansible.builtin.shell: echo "User {{ vault_admin_user }} logged in"
      register: result
    
    - name: Display result
      ansible.builtin.debug:
        msg: "{{ result.stdout }}"
```

---

## Запуск Playbook

### Без пароля (ошибка)

```bash
ansible-playbook -i inventory.yml test-vault.yml
```

Результат:

```
[ERROR]: Attempting to decrypt but no vault secrets found.
```

### С паролем

Интерактивный ввод:

```bash
ansible-playbook -i inventory.yml test-vault.yml --ask-vault-pass
```

---

## Автоматизация

### Файл с паролем

Создание файла пароля:

```bash
echo "<VAULT_PASSWORD>" > .vault_pass
chmod 600 .vault_pass
```

Добавление в .gitignore:

```bash
echo ".vault_pass" >> .gitignore
```

Запуск с файлом:

```bash
ansible-playbook -i inventory.yml test-vault.yml --vault-password-file .vault_pass
```

### Переменная окружения

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_pass
```

Запуск:

```bash
ansible-playbook -i inventory.yml test-vault.yml
```

---

## Шифрование отдельных строк

Шифрование конкретной строки:

```bash
ansible-vault encrypt_string '<SECRET_VALUE>' --name 'vault_db_password'
```

Результат:

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
db_host: "localhost"
db_port: 5432
db_name: "production"

vault_db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          66386439653832323234323863393633306364633462613461363130363662663430383633303561
          3131303539366237303336333937306633313533633061370a613835383564666161383565616234
```

Преимущества:
- Видимость обычных переменных
- Шифрование только критичных данных
- Улучшенная работа с Git diff

---

## Применение в production

### Credentials

```yaml
# group_vars/production/vault.yml (зашифровано)
vault_db_host: "<PROD_DB_HOST>"
vault_db_user: "<DB_USER>"
vault_db_password: "<DB_PASSWORD>"
vault_db_port: 5432
```

Использование:

```yaml
- name: Configure application
  ansible.builtin.template:
    src: app-config.j2
    dest: /etc/app/config.ini
  vars:
    db_host: "{{ vault_db_host }}"
    db_pass: "{{ vault_db_password }}"
```

### API токены

```yaml
vault_github_token: "<GITHUB_TOKEN>"
vault_docker_password: "<DOCKER_PASSWORD>"
vault_slack_webhook: "<SLACK_WEBHOOK>"
vault_aws_access_key: "<AWS_ACCESS_KEY>"
vault_aws_secret_key: "<AWS_SECRET_KEY>"
```

### SSL/TLS сертификаты

```yaml
vault_ssl_certificate: |
  -----BEGIN CERTIFICATE-----
  <CERTIFICATE_CONTENT>
  -----END CERTIFICATE-----

vault_ssl_private_key: |
  -----BEGIN RSA PRIVATE KEY-----
  <KEY_CONTENT>
  -----END RSA PRIVATE KEY-----
```

### Создание пользователей

```yaml
- name: Create users
  ansible.builtin.user:
    name: "{{ item.name }}"
    password: "{{ item.password | password_hash('sha512') }}"
  loop:
    - name: admin
      password: "{{ vault_admin_password }}"
    - name: deploy
      password: "{{ vault_deploy_password }}"
```

---

## Best Practices

### Организация файлов

Разделение переменных:

```
group_vars/
├── all/
│   ├── vars.yml      # Обычные переменные
│   └── vault.yml     # Зашифрованные переменные
├── production/
│   ├── vars.yml
│   └── vault.yml
└── staging/
    ├── vars.yml
    └── vault.yml
```

### Именование

Префиксы для vault-переменных:

```yaml
# Правильно
vault_db_password: "<PASSWORD>"
vault_api_key: "<KEY>"
vault_aws_access_key: "<KEY>"

# Неправильно
password: "<PASSWORD>"
api_key: "<KEY>"
```

### Безопасность

Исключение из Git:

```bash
# .gitignore
.vault_pass
*.vault
.vault_pass_*
```

Разные пароли для окружений:

```
.vault_pass_dev
.vault_pass_staging
.vault_pass_prod
```

### Ротация секретов

Регулярная смена паролей:

```bash
ansible-vault rekey group_vars/all/vault.yml
```

### CI/CD интеграция

GitLab CI:

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

HashiCorp Vault:

```bash
vault kv get -field=ansible_vault_pass secret/ansible > .vault_pass
ansible-playbook playbook.yml --vault-password-file .vault_pass
rm -f .vault_pass
```

AWS Secrets Manager:

```bash
aws secretsmanager get-secret-value --secret-id ansible-vault-pass \
  --query SecretString --output text > .vault_pass
ansible-playbook playbook.yml --vault-password-file .vault_pass
rm -f .vault_pass
```

---

## Применение файла пароля

Локально файл `.vault_pass` нецелесообразен (незашифрованный пароль на диске).

Реальные сценарии:

**CI/CD пайплайны:**
- Пароль в секретных переменных
- Динамическое создание при деплое
- Удаление после выполнения

**Production серверы:**
- Файл только на сервере деплоя
- Права доступ `chmod 600`
- Ограниченный доступ к серверу

**Автоматизация:**
- Cron задачи
- Автоматические обновления
- Scheduled pipelines

---

## Команды Vault

Справочник:

```bash
# Шифрование
ansible-vault encrypt file.yml

# Расшифровка
ansible-vault decrypt file.yml

# Просмотр
ansible-vault view file.yml

# Редактирование
ansible-vault edit file.yml

# Смена пароля
ansible-vault rekey file.yml

# Шифрование строки
ansible-vault encrypt_string '<SECRET>' --name 'variable_name'

# Создание зашифрованного файла
ansible-vault create new_file.yml
```

Опции playbook:

```bash
# Интерактивный ввод
ansible-playbook playbook.yml --ask-vault-pass

# Файл с паролем
ansible-playbook playbook.yml --vault-password-file .vault_pass

# Несколько vault паролей
ansible-playbook playbook.yml \
  --vault-id dev@.vault_pass_dev \
  --vault-id prod@.vault_pass_prod
```
