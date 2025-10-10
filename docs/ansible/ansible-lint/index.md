# Ansible-lint

Инструмент статического анализа для валидации Ansible playbooks и ролей на соответствие best practices.

---

## Установка

Установка через pip:

```bash
pip3 install ansible-lint
```

Установка через apt:

```bash
sudo apt install ansible-lint
```

Проверка версии:

```bash
ansible-lint --version
```

---

## Конфигурация

Файл `.ansible-lint` в корне проекта:

```yaml
---
exclude_paths:
  - backups/
  - .ansible/
  - /tmp/

skip_list:
  - yaml[line-length]

warn_list:
  - experimental

kinds:
  - playbook: "playbooks/*.yml"
  - tasks: "roles/*/tasks/*.yml"
  - vars: "group_vars/*.yml"
  - vars: "host_vars/*.yml"
```

Параметры конфигурации:

| Параметр | Назначение |
|----------|------------|
| exclude_paths | Каталоги для исключения |
| skip_list | Игнорируемые правила |
| warn_list | Правила с уровнем warning |
| kinds | Типы файлов для проверки |

---

## Запуск

Проверка всего проекта:

```bash
ansible-lint
```

Проверка конкретного файла:

```bash
ansible-lint playbooks/deploy-etcd.yml
```

Проверка роли:

```bash
ansible-lint roles/patroni/
```

Verbose режим:

```bash
ansible-lint -v
```

---

## Типы нарушений

### FQCN (Fully Qualified Collection Names)

Нарушение:

```yaml
- name: Install package
  apt:
    name: nginx
```

FQCN обеспечивает явное указание источника модуля, предотвращая конфликты при наличии модулей с идентичными именами.

Исправление:

```yaml
- name: Install package
  ansible.builtin.apt:
    name: nginx
```

Основные FQCN:

| Короткое имя | FQCN |
|--------------|------|
| apt | ansible.builtin.apt |
| yum | ansible.builtin.yum |
| copy | ansible.builtin.copy |
| template | ansible.builtin.template |
| file | ansible.builtin.file |
| systemd | ansible.builtin.systemd |
| service | ansible.builtin.service |
| shell | ansible.builtin.shell |
| command | ansible.builtin.command |
| ufw | community.general.ufw |

Автоматическое исправление:

```bash
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/^  apt:/  ansible.builtin.apt:/g' {} \;
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/^  ufw:/  community.general.ufw:/g' {} \;
```

---

### yaml[truthy]

Нарушение:

```yaml
- name: Enable service
  systemd:
    enabled: yes
    state: started
```

YAML спецификация рекомендует `true/false` вместо `yes/no` для предотвращения неоднозначной интерпретации разными парсерами.

Исправление:

```yaml
- name: Enable service
  ansible.builtin.systemd:
    enabled: true
    state: started
```

Автоматическое исправление:

```bash
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/: yes$/: true/g' {} \;
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/: no$/: false/g' {} \;
```

---

### name[casing]

Нарушение:

```yaml
handlers:
  - name: reload systemd
    systemd:
      daemon_reload: true
```

Единообразное именование с заглавной буквы улучшает читаемость кода.

Исправление:

```yaml
handlers:
  - name: Reload systemd
    ansible.builtin.systemd:
      daemon_reload: true
```

---

### yaml[trailing-spaces]

Trailing spaces в конце строк засоряют diff и могут вызывать проблемы с парсерами.

Исправление:

```bash
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/[[:space:]]*$//' {} \;
```

---

### var-naming[read-only]

Нарушение:

```yaml
vars:
  inventory_file: /path/to/inventory
```

Переопределение зарезервированных переменных Ansible приводит к конфликтам.

Исправление:

```yaml
vars:
  custom_inventory_path: /path/to/inventory
```

---

### schema[tasks]

Нарушение структуры playbook:

```yaml
---
- hosts: all
  vars_files:
    - vars.yml
  roles:
    - role1
```

Исправление:

```yaml
---
- name: Playbook description
  hosts: all
  become: true
  tasks:
    - name: Task name
      ansible.builtin.command: echo "test"
```

Playbooks с ролями:

```yaml
---
- name: Deploy services
  hosts: all
  become: true
  roles:
    - role1
```

---

## Профили

Встроенные профили проверки:

| Профиль | Описание |
|---------|----------|
| min | Минимальные проверки |
| basic | Базовые правила |
| moderate | Умеренные требования |
| safety | Безопасность |
| shared | Общие практики |
| production | Production-ready код |

Проверка по профилю:

```bash
ansible-lint --profile production
```

---

## Интеграция в workflow

### Pre-commit hook

Файл `.git/hooks/pre-commit`:

```bash
#!/bin/bash
ansible-lint
if [ $? -ne 0 ]; then
    echo "ansible-lint failed. Commit aborted."
    exit 1
fi
```

Активация hook:

```bash
chmod +x .git/hooks/pre-commit
```

### Makefile

```makefile
lint:
	@echo "Running ansible-lint..."
	@ansible-lint || (echo "Lint failed!" && exit 1)
	@echo "Lint passed!"

validate: lint syntax-check
	@echo "All validations passed!"
```

Использование:

```bash
make lint
make validate
```

---

## Массовое исправление

### Скрипт FQCN

Файл `fix_fqcn.sh`:

```bash
#!/bin/bash

FILES=$(find roles/ playbooks/ -name "*.yml" -type f)

for file in $FILES; do
  echo "Processing: $file"
  
  sed -i 's/^  user:/  ansible.builtin.user:/g' "$file"
  sed -i 's/^  file:/  ansible.builtin.file:/g' "$file"
  sed -i 's/^  template:/  ansible.builtin.template:/g' "$file"
  sed -i 's/^  systemd:/  ansible.builtin.systemd:/g' "$file"
  sed -i 's/^  apt:/  ansible.builtin.apt:/g' "$file"
  sed -i 's/^  shell:/  ansible.builtin.shell:/g' "$file"
  sed -i 's/^  copy:/  ansible.builtin.copy:/g' "$file"
  sed -i 's/^  lineinfile:/  ansible.builtin.lineinfile:/g' "$file"
  sed -i 's/^  blockinfile:/  ansible.builtin.blockinfile:/g' "$file"
  sed -i 's/^  ufw:/  community.general.ufw:/g' "$file"
done

echo "FQCN fix completed!"
```

Запуск:

```bash
chmod +x fix_fqcn.sh
./fix_fqcn.sh
```

### Скрипт truthy

Файл `fix_truthy.sh`:

```bash
#!/bin/bash

find roles/ playbooks/ -name "*.yml" -type f | while read file; do
  sed -i 's/: yes$/: true/g' "$file"
  sed -i 's/: no$/: false/g' "$file"
done

echo "Truthy values fixed!"
```

---

## Best Practices

### Структура task

Корректная структура:

```yaml
- name: Install and configure nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true
  become: true
  tags:
    - nginx
    - webserver
```

Элементы:
1. Name с заглавной буквы
2. FQCN модуль
3. Параметры модуля
4. become при необходимости
5. tags для селективного выполнения

### Идемпотентность

Идемпотентная задача:

```yaml
- name: Ensure nginx is installed
  ansible.builtin.apt:
    name: nginx
    state: present
```

Неидемпотентная задача (избегать):

```yaml
- name: Install nginx
  ansible.builtin.shell: apt install -y nginx
```

### Handlers

```yaml
tasks:
  - name: Copy nginx config
    ansible.builtin.template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Restart nginx

handlers:
  - name: Restart nginx
    ansible.builtin.systemd:
      name: nginx
      state: restarted
```

### Переменные в defaults

Все переменные роли в `defaults/main.yml`:

```yaml
---
service_name: nginx
service_port: 80
service_user: www-data
```


