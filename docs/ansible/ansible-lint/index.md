# Работа с ansible-lint

Руководство по использованию ansible-lint для обеспечения качества Ansible кода.

---

## О ansible-lint

ansible-lint - инструмент статического анализа для проверки Ansible playbooks и ролей на соответствие best practices.

### Установка

~~~bash
pip3 install ansible-lint
~~~

Или через apt:

~~~bash
sudo apt install ansible-lint
~~~

Проверка версии:

~~~bash
ansible-lint --version
~~~

---

## Конфигурация ansible-lint

### Файл .ansible-lint

Файл `.ansible-lint` в корне проекта:

~~~yaml
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
~~~

Параметры:

| Параметр | Назначение |
|----------|------------|
| exclude_paths | Исключить каталоги из проверки |
| skip_list | Игнорировать определенные правила |
| warn_list | Показывать как warning, не ошибку |
| kinds | Определение типов файлов |

---

## Запуск ansible-lint

### Проверка всего проекта

~~~bash
ansible-lint
~~~

### Проверка конкретного файла

~~~bash
ansible-lint playbooks/deploy-etcd.yml
~~~

### Проверка роли

~~~bash
ansible-lint roles/patroni/
~~~

### Verbose режим

~~~bash
ansible-lint -v
~~~

---

## Типы нарушений и их исправление

### FQCN (Fully Qualified Collection Names)

**Проблема:**

~~~yaml
- name: Install package
  apt:
    name: nginx
~~~

**Почему важно:**

FQCN обеспечивает явное указание источника модуля. Без FQCN Ansible ищет модуль в нескольких местах, что может привести к конфликтам при наличии модулей с одинаковыми именами из разных коллекций.

**Правильно:**

~~~yaml
- name: Install package
  ansible.builtin.apt:
    name: nginx
~~~

**Основные FQCN:**

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

**Автоматическое исправление:**

~~~bash
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/^  apt:/  ansible.builtin.apt:/g' {} \;
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/^  ufw:/  community.general.ufw:/g' {} \;
~~~

---

### yaml[truthy]

**Проблема:**

~~~yaml
- name: Enable service
  systemd:
    enabled: yes
    state: started
~~~

**Почему важно:**

YAML спецификация рекомендует использовать `true/false` вместо `yes/no`. Значения `yes/no` могут интерпретироваться по-разному в разных парсерах.

**Правильно:**

~~~yaml
- name: Enable service
  ansible.builtin.systemd:
    enabled: true
    state: started
~~~

**Автоматическое исправление:**

~~~bash
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/: yes$/: true/g' {} \;
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/: no$/: false/g' {} \;
~~~

---

### name[casing]

**Проблема:**

~~~yaml
handlers:
  - name: reload systemd
    systemd:
      daemon_reload: true
~~~

**Почему важно:**

Единообразное именование улучшает читаемость. Handlers и tasks должны начинаться с заглавной буквы.

**Правильно:**

~~~yaml
handlers:
  - name: Reload systemd
    ansible.builtin.systemd:
      daemon_reload: true
~~~

---

### yaml[trailing-spaces]

**Проблема:**

Пробелы в конце строк (невидимы в редакторе).

**Почему важно:**

Trailing spaces засоряют diff, могут вызывать проблемы с некоторыми парсерами.

**Исправление:**

~~~bash
find roles/ playbooks/ -name "*.yml" -exec sed -i 's/[[:space:]]*$//' {} \;
~~~

---

### var-naming[read-only]

**Проблема:**

~~~yaml
vars:
  inventory_file: /path/to/inventory
~~~

**Почему важно:**

`inventory_file` - зарезервированная переменная Ansible. Её переопределение может вызвать конфликты.

**Правильно:**

Использовать другое имя переменной:

~~~yaml
vars:
  custom_inventory_path: /path/to/inventory
~~~

---

### schema[tasks]

**Проблема:**

Неправильная структура playbook.

**Почему важно:**

Ansible требует определенную структуру. Нарушение схемы приводит к ошибкам выполнения.

**Пример проблемы:**

~~~yaml
---
- hosts: all
  vars_files:
    - vars.yml
  roles:
    - role1
~~~

**Правильно:**

~~~yaml
---
- name: Playbook description
  hosts: all
  become: true
  tasks:
    - name: Task name
      ansible.builtin.command: echo "test"
~~~

Для playbooks с ролями:

~~~yaml
---
- name: Deploy services
  hosts: all
  become: true
  roles:
    - role1
~~~

---

## Профили ansible-lint

ansible-lint имеет встроенные профили проверки:

| Профиль | Описание |
|---------|----------|
| min | Минимальные проверки |
| basic | Базовые правила |
| moderate | Умеренные требования |
| safety | Безопасность |
| shared | Общие практики |
| production | Production-ready код |

### Проверка по профилю

~~~bash
ansible-lint --profile production
~~~

Проект должен проходить **production** профиль.

---

## Интеграция в workflow

### Pre-commit hook

Файл `.git/hooks/pre-commit`:

~~~bash
#!/bin/bash
ansible-lint
if [ $? -ne 0 ]; then
    echo "ansible-lint failed. Commit aborted."
    exit 1
fi
~~~

~~~bash
chmod +x .git/hooks/pre-commit
~~~

### Makefile интеграция

~~~makefile
lint:
	@echo "Running ansible-lint..."
	@ansible-lint || (echo "Lint failed!" && exit 1)
	@echo "Lint passed!"

validate: lint syntax-check
	@echo "All validations passed!"
~~~

Использование:

~~~bash
make lint
make validate
~~~

---

## Исправление множественных нарушений

### Скрипт массового исправления FQCN

Файл `fix_fqcn.sh`:

~~~bash
#!/bin/bash

FILES=$(find roles/ playbooks/ -name "*.yml" -type f)

for file in $FILES; do
  echo "Processing: $file"
  
  # Builtin modules
  sed -i 's/^  user:/  ansible.builtin.user:/g' "$file"
  sed -i 's/^  file:/  ansible.builtin.file:/g' "$file"
  sed -i 's/^  template:/  ansible.builtin.template:/g' "$file"
  sed -i 's/^  systemd:/  ansible.builtin.systemd:/g' "$file"
  sed -i 's/^  apt:/  ansible.builtin.apt:/g' "$file"
  sed -i 's/^  shell:/  ansible.builtin.shell:/g' "$file"
  sed -i 's/^  copy:/  ansible.builtin.copy:/g' "$file"
  sed -i 's/^  lineinfile:/  ansible.builtin.lineinfile:/g' "$file"
  sed -i 's/^  blockinfile:/  ansible.builtin.blockinfile:/g' "$file"
  
  # Community modules
  sed -i 's/^  ufw:/  community.general.ufw:/g' "$file"
done

echo "FQCN fix completed!"
~~~

Запуск:

~~~bash
chmod +x fix_fqcn.sh
./fix_fqcn.sh
~~~

### Скрипт исправления truthy

Файл `fix_truthy.sh`:

~~~bash
#!/bin/bash

find roles/ playbooks/ -name "*.yml" -type f | while read file; do
  sed -i 's/: yes$/: true/g' "$file"
  sed -i 's/: no$/: false/g' "$file"
done

echo "Truthy values fixed!"
~~~

---

## Best Practices

### Структура task

**Правильная структура:**

~~~yaml
- name: Install and configure nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true
  become: true
  tags:
    - nginx
    - webserver
~~~

**Элементы:**
1. Name - описательное имя с заглавной буквы
2. FQCN модуль
3. Параметры модуля
4. become при необходимости
5. tags для селективного выполнения

### Идемпотентность

Все tasks должны быть идемпотентными:

~~~yaml
# Правильно - идемпотентно
- name: Ensure nginx is installed
  ansible.builtin.apt:
    name: nginx
    state: present

# Неправильно - не идемпотентно
- name: Install nginx
  ansible.builtin.shell: apt install -y nginx
~~~

### Использование handlers

~~~yaml
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
~~~

### Переменные в defaults

Все переменные роли должны быть в `defaults/main.yml`:

~~~yaml
---
service_name: nginx
service_port: 80
service_user: www-data
~~~

---

## Результаты проекта

### До исправлений

~~~
Failed: 86 failure(s), 0 warning(s) on 51 files
~~~

### После исправлений

~~~
Passed: 0 failure(s), 0 warning(s) on 43 files
Last profile: production
~~~

### Основные изменения

| Категория | Количество исправлений |
|-----------|------------------------|
| FQCN | 42 |
| yaml[truthy] | 24 |
| name[casing] | 2 |
| trailing-spaces | 18 |

Все нарушения исправлены, проект соответствует production стандартам.

