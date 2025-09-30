# Ansible: Структура проекта с окружениями

Практическое руководство по созданию упорядоченной структуры Ansible-проекта с поддержкой нескольких окружений (dev, prod).

## Предварительные требования

- Ansible 2.9+
- Python 3
- SSH доступ к управляемым серверам

---

## Часть 1: Создание структуры проекта

### Базовая структура каталогов

```bash
mkdir ansible-environments-project
cd ansible-environments-project
mkdir -p roles playbooks inventories
```

**Назначение каталогов:**

| Каталог | Назначение | Пример содержимого |
|---------|-----------|-------------------|
| `roles/` | Переиспользуемые компоненты | Роль для установки nginx |
| `playbooks/` | Сценарии применения ролей | site.yml, deploy.yml |
| `inventories/` | Списки хостов и переменные | dev/, prod/ |

Четкое разделение ответственности облегчает навигацию по проекту и соответствует стандартам Ansible сообщества.

### Создание окружений

```bash
mkdir -p inventories/{dev,prod}
mkdir -p inventories/dev/{group_vars,host_vars}
mkdir -p inventories/prod/{group_vars,host_vars}
```

**Структура:**

```
inventories/
├── dev/
│   ├── group_vars/    # переменные для групп хостов
│   ├── host_vars/     # переменные для конкретных хостов
│   └── hosts          # список хостов
└── prod/
    ├── group_vars/
    ├── host_vars/
    └── hosts
```

**group_vars и host_vars:**

- **group_vars/all.yml** - применяется ко всем хостам окружения
- **group_vars/webservers.yml** - применяется к группе webservers
- **host_vars/web-01.yml** - применяется к конкретному хосту

---

## Часть 2: Создание Inventory файлов

### Inventory для DEV окружения

```ini
[webservers]
dev-web-01 ansible_host=<DEV_WEB_01_IP>
dev-web-02 ansible_host=<DEV_WEB_02_IP>

[databases]
dev-db-01 ansible_host=<DEV_DB_01_IP>

[dev:children]
webservers
databases

[dev:vars]
ansible_user=ansible
ansible_python_interpreter=/usr/bin/python3
```

Создайте файл:

```bash
nano inventories/dev/hosts
```

Вставьте содержимое выше, заменив `<DEV_WEB_01_IP>` и другие плейсхолдеры на реальные IP адреса.

**Разбор секций:**

**Группа webservers**
```ini
[webservers]
dev-web-01 ansible_host=<DEV_WEB_01_IP>
```
- `dev-web-01` - имя хоста в Ansible
- `ansible_host` - фактический IP для SSH подключения

**Мета-группа dev:children**
```ini
[dev:children]
webservers
databases
```
Объединяет несколько групп, позволяя применять playbook на все окружение: `hosts: dev`

**Переменные группы dev**
```ini
[dev:vars]
ansible_user=ansible
ansible_python_interpreter=/usr/bin/python3
```
Определяет пользователя SSH и интерпретатор Python для всех хостов группы.

### Inventory для PROD окружения

```ini
[webservers]
prod-web-01 ansible_host=<PROD_WEB_01_IP>
prod-web-02 ansible_host=<PROD_WEB_02_IP>
prod-web-03 ansible_host=<PROD_WEB_03_IP>

[databases]
prod-db-01 ansible_host=<PROD_DB_01_IP>
prod-db-02 ansible_host=<PROD_DB_02_IP>

[prod:children]
webservers
databases

[prod:vars]
ansible_user=ansible
ansible_python_interpreter=/usr/bin/python3
```

Создайте файл:

```bash
nano inventories/prod/hosts
```

Production окружение включает дополнительный веб-сервер для обеспечения отказоустойчивости и вторую базу данных для репликации Master-Slave.

### Переменные для DEV окружения

```yaml
---
env_name: development
webserver_nginx_port: 8080
webserver_app_version: "1.0.0-dev"
webserver_enable_debug: true
webserver_max_connections: 50
```

Создайте файл:

```bash
nano inventories/dev/group_vars/all.yml
```

Development окружение использует нестандартный порт 8080, включенное debug логирование и ограниченное количество соединений.

### Переменные для PROD окружения

```yaml
---
env_name: production
webserver_nginx_port: 80
webserver_app_version: "1.0.0"
webserver_enable_debug: false
webserver_max_connections: 200
```

Создайте файл:

```bash
nano inventories/prod/group_vars/all.yml
```

Production окружение использует стандартный порт 80, отключенное debug логирование для оптимизации производительности и увеличенный лимит соединений.

---

## Часть 3: Создание роли webserver

### Структура роли

```bash
mkdir -p roles/webserver/{tasks,templates,handlers,defaults,meta}
```

**Назначение компонентов:**

| Папка | Файл | Назначение |
|-------|------|-----------|
| `tasks/` | main.yml | Основные задачи установки и настройки |
| `templates/` | *.j2 | Шаблоны конфигурационных файлов |
| `handlers/` | main.yml | Обработчики событий |
| `defaults/` | main.yml | Значения переменных по умолчанию |
| `meta/` | main.yml | Метаданные роли |

### Файл tasks/main.yml

```yaml
---
- name: Установка Nginx
  ansible.builtin.package:
    name: nginx
    state: present

- name: Создание конфигурации Nginx
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/sites-available/default
    mode: '0644'
  notify: Перезапуск Nginx

- name: Запуск и включение Nginx
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

Создайте файл:

```bash
nano roles/webserver/tasks/main.yml
```

**Установка Nginx**
```yaml
- name: Установка Nginx
  ansible.builtin.package:
    name: nginx
    state: present
```
Модуль `package` обеспечивает кросс-платформенную установку (apt для Debian, zypper для openSUSE). Параметр `state: present` гарантирует идемпотентность.

**Создание конфигурации**
```yaml
- name: Создание конфигурации Nginx
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/sites-available/default
    mode: '0644'
  notify: Перезапуск Nginx
```
Модуль `template` обрабатывает Jinja2 шаблон, подставляя переменные окружения. Директива `notify` вызывает handler при изменении файла.

**Используем идемпотентный notify**

Прямой перезапуск службы в tasks приводит к перезапуску при каждом выполнении playbook:
```yaml
# Неидемпотентный подход
- service: name=nginx state=restarted
```

Handler с notify перезапускает службу только при фактическом изменении конфигурации:
```yaml
# Идемпотентный подход
- template: ...
  notify: Перезапуск Nginx
```

**Запуск службы**
```yaml
- name: Запуск и включение Nginx
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```
Параметры `state: started` и `enabled: true` обеспечивают запуск службы и добавление в автозагрузку.

### Файл templates/nginx.conf.j2

```jinja2
# Nginx конфигурация для {{ env_name }} окружения
# Сгенерировано Ansible

server {
    listen {{ webserver_nginx_port }};
    server_name _;

    # Версия приложения: {{ webserver_app_version }}
    # Debug режим: {{ webserver_enable_debug }}
    # Максимум соединений: {{ webserver_max_connections }}

    location / {
        root /var/www/html;
        index index.html;
    }

    {% if webserver_enable_debug %}
    # Debug логирование включено
    access_log /var/log/nginx/access.log combined;
    error_log /var/log/nginx/error.log debug;
    {% else %}
    # Минимальное логирование
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log error;
    {% endif %}
}
```

Создайте файл:

```bash
nano roles/webserver/templates/nginx.conf.j2
```

**Синтаксис Jinja2:**

**Подстановка переменных**
```jinja2
listen {{ webserver_nginx_port }};
```
В DEV: `listen 8080;`  
В PROD: `listen 80;`

**Условные блоки**
```jinja2
{% if webserver_enable_debug %}
    error_log /var/log/nginx/error.log debug;
{% else %}
    error_log /var/log/nginx/error.log error;
{% endif %}
```
В DEV: уровень логирования `debug`  
В PROD: уровень логирования `error`

Шаблонизация позволяет использовать один файл для всех окружений, устраняя дублирование конфигураций.

### Файл handlers/main.yml

```yaml
---
- name: Перезапуск Nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

Создайте файл:

```bash
nano roles/webserver/handlers/main.yml
```

**Механизм работы handlers:**

```
Первый запуск playbook:
1. Установка Nginx → OK
2. Создание конфига → ИЗМЕНЕН → notify: Перезапуск Nginx
3. Запуск Nginx → OK
4. В конце playbook: handler "Перезапуск Nginx"

Повторный запуск playbook:
1. Установка Nginx → ПРОПУСК (идемпотентность)
2. Создание конфига → ПРОПУСК (не изменен)
3. Запуск Nginx → ПРОПУСК (уже запущен)
4. Handler не вызывается
```

Если несколько задач вызвали один handler, он выполнится только один раз в конце playbook.

### Файл defaults/main.yml

```yaml
---
webserver_nginx_port: 80
webserver_enable_debug: false
webserver_max_connections: 100
webserver_app_version: "1.0.0"
```

Создайте файл:

```bash
nano roles/webserver/defaults/main.yml
```

**Функция defaults:**

1. Роль функционирует без предварительной настройки переменных
2. Документирует поддерживаемые параметры и их значения
3. Упрощает переиспользование роли в других проектах

**Приоритет переменных:**

```
defaults/main.yml (80)
    ↓
group_vars/all.yml (8080)
    ↓
group_vars/webservers.yml (9090)
    ↓
host_vars/web-01.yml (7777)
    ↓
--extra-vars (6666)

Итоговое значение: 6666
```

**Соглашение об именовании:**

Переменные роли должны содержать префикс имени роли:
```yaml
# Рекомендуемый формат
webserver_nginx_port: 80
webserver_enable_debug: false

# Избегать
nginx_port: 80
enable_debug: false
```

Префикс предотвращает конфликты имен при использовании нескольких ролей:

```yaml
# Конфликт
roles/webserver/defaults/main.yml:
  port: 80

roles/database/defaults/main.yml:
  port: 5432  # Неопределенное поведение

# Разрешение
roles/webserver/defaults/main.yml:
  webserver_port: 80

roles/database/defaults/main.yml:
  database_port: 5432  # Четкое разделение
```

### Файл meta/main.yml

```yaml
---
galaxy_info:
  author: DevOps Student
  description: Роль для установки и настройки Nginx веб-сервера
  company: Learning Project

  license: MIT

  min_ansible_version: "2.9"

  platforms:
    - name: Ubuntu
      versions:
        - focal
        - jammy
    - name: Debian
      versions:
        - bullseye
        - bookworm

  galaxy_tags:
    - web
    - nginx
    - webserver

dependencies: []
```

Создайте файл:

```bash
nano roles/webserver/meta/main.yml
```

**Компоненты метаданных:**

**min_ansible_version**
```yaml
min_ansible_version: "2.9"
```
Ansible валидирует версию перед выполнением. При несоответствии выводится ошибка.

**platforms**
```yaml
platforms:
  - name: Ubuntu
    versions:
      - focal    # 20.04
      - jammy    # 22.04
```
Документирует протестированные платформы для роли.

**dependencies**
```yaml
dependencies: []
```
Список ролей-зависимостей. Ansible автоматически применяет зависимости перед основной ролью.

Пример с зависимостями:
```yaml
dependencies:
  - role: geerlingguy.firewall
  - role: geerlingguy.certbot
```

Последовательность выполнения:
```
1. geerlingguy.firewall
2. geerlingguy.certbot
3. webserver (текущая роль)
```

---

## Часть 4: Создание Playbook

### Главный playbook site.yml

```yaml
---
- name: Настройка веб-серверов
  hosts: webservers
  become: true

  roles:
    - webserver

  tasks:
    - name: Вывод информации об окружении
      ansible.builtin.debug:
        msg: |
          ====================================
          Окружение: {{ env_name }}
          Nginx порт: {{ webserver_nginx_port }}
          Версия приложения: {{ webserver_app_version }}
          Debug режим: {{ webserver_enable_debug }}
          Максимум соединений: {{ webserver_max_connections }}
          ====================================
```

Создайте файл:

```bash
nano playbooks/site.yml
```

**Структура play:**

```yaml
- name: Настройка веб-серверов
  hosts: webservers
  become: true
```
- `hosts: webservers` - целевая группа из inventory
- `become: true` - эскалация привилегий через sudo для всех задач

**Подключение роли:**
```yaml
roles:
  - webserver
```

Ansible выполняет задачи из `roles/webserver/tasks/main.yml`.

**Дополнительные задачи:**
```yaml
tasks:
  - name: Вывод информации об окружении
    ansible.builtin.debug:
      msg: |
        ...
```

Tasks после roles используются для операций специфичных для данного playbook.

**Порядок выполнения:**

```
1. Pre-tasks (если определены)
2. Roles
   - webserver tasks
3. Tasks
   - Вывод информации
4. Handlers (при вызове notify)
   - Перезапуск Nginx
```

---

## Часть 5: Конфигурация Ansible

### Файл ansible.cfg

```ini
[defaults]
inventory = inventories/dev/hosts
roles_path = roles
host_key_checking = False
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo
become_user = root
```

Создайте файл:

```bash
nano ansible.cfg
```

**Секция [defaults]:**

**inventory**
```ini
inventory = inventories/dev/hosts
```
Определяет inventory по умолчанию. Позволяет запускать playbook без флага `-i`:
```bash
ansible-playbook playbooks/site.yml
```

Переопределение для production:
```bash
ansible-playbook -i inventories/prod/hosts playbooks/site.yml
```

**host_key_checking**
```ini
host_key_checking = False
```
Отключает SSH fingerprint verification. Рекомендуется для development окружений и динамической инфраструктуры. В production окружениях с фиксированной инфраструктурой рекомендуется `True`.

**retry_files_enabled**
```ini
retry_files_enabled = False
```
Отключает генерацию `.retry` файлов. Для повторного запуска на failed хостах используйте `--limit`.

**Секция [privilege_escalation]:**

**become**
```ini
become = True
```
Применяет sudo ко всем задачам по умолчанию. Можно отключить для конкретных задач через `become: false`.

**become_method**
```ini
become_method = sudo
```
Метод эскалации привилегий. Альтернативы: `su`, `pbrun`, `pfexec`, `doas`.

**become_user**
```ini
become_user = root
```
Целевой пользователь для эскалации. Может быть переопределен в task через `become_user: www-data`.

---

## Часть 6: Проверка и валидация

### Проверка синтаксиса

```bash
ansible-playbook playbooks/site.yml --syntax-check
```

Валидирует:
- YAML синтаксис
- Существование ролей
- Корректность структуры playbook

Ожидаемый вывод:
```
playbook: playbooks/site.yml
```

### Проверка с ansible-lint

Установка:
```bash
pip install ansible-lint
```

Запуск:
```bash
ansible-lint playbooks/site.yml
```

**Проверяемые аспекты:**

1. Best practices Ansible
2. Deprecated модули
3. Форматирование YAML
4. Соглашения об именовании переменных

**Типичные проблемы:**

**Trailing spaces**
```
yaml[trailing-spaces]: Trailing spaces
playbooks/site.yml:5
```
Решение: удалить пробелы в конце строки.

**Зарезервированные имена**
```
var-naming[no-reserved]: Variables names must not be Ansible reserved names. (environment)
```
Решение: переименовать `environment` → `env_name`

**Отсутствие префикса роли**
```
var-naming[no-role-prefix]: Variables names from within roles should use webserver_ as a prefix. (vars: nginx_port)
```
Решение: переименовать `nginx_port` → `webserver_nginx_port`

### Dry-run

```bash
ansible-playbook playbooks/site.yml --check
```

Выполняет симуляцию без применения изменений. Показывает планируемые изменения на хостах.

---

## Часть 7: Запуск и применение

### Применение на DEV окружение

Последовательность проверок:
```bash
ansible-playbook playbooks/site.yml --syntax-check
ansible-lint playbooks/site.yml
ansible-playbook playbooks/site.yml --check
```

Применение:
```bash
ansible-playbook playbooks/site.yml
```

**Пример вывода:**

```
PLAY [Настройка веб-серверов] *********************************

TASK [Gathering Facts] *********************************
ok: [dev-web-01]
ok: [dev-web-02]

TASK [webserver : Установка Nginx] *********************************
changed: [dev-web-01]
changed: [dev-web-02]

TASK [webserver : Создание конфигурации Nginx] *********************************
changed: [dev-web-01]
changed: [dev-web-02]

TASK [webserver : Запуск и включение Nginx] *********************************
changed: [dev-web-01]
changed: [dev-web-02]

TASK [Вывод информации об окружении] *********************************
ok: [dev-web-01] => {
    "msg": "====================================\nОкружение: development\nNginx порт: 8080\n..."
}

RUNNING HANDLER [webserver : Перезапуск Nginx] *********************************
changed: [dev-web-01]
changed: [dev-web-02]

PLAY RECAP *********************************
dev-web-01    : ok=6    changed=4    unreachable=0    failed=0
dev-web-02    : ok=6    changed=4    unreachable=0    failed=0
```

**Интерпретация PLAY RECAP:**

- `ok=6` - успешно выполненные задачи
- `changed=4` - задачи внесшие изменения
- `unreachable=0` - недоступные хосты
- `failed=0` - задачи завершившиеся ошибкой

### Применение на PROD окружение

```bash
ansible-playbook -i inventories/prod/hosts playbooks/site.yml --check
ansible-playbook -i inventories/prod/hosts playbooks/site.yml
```

**Workflow для production:**

1. Применение и тестирование в dev
2. Валидация с `--check` на prod
3. Применение на prod
4. Верификация работоспособности

### Проверка результата

```bash
# Проверка доступности
curl http://<DEV_WEB_01_IP>:8080
curl http://<PROD_WEB_01_IP>:80

# Валидация конфигурации
ansible webservers -m command -a "nginx -t"

# Проверка статуса службы
ansible webservers -m service -a "name=nginx state=started"
```

---

## Troubleshooting

### Undefined variable

**Ошибка:**
```
fatal: [dev-web-01]: FAILED! => {"msg": "The task includes an option with an undefined variable. The error was: 'webserver_nginx_port' is undefined"}
```

**Решение:**

Проверка загруженных переменных:
```bash
ansible -i inventories/dev/hosts dev-web-01 -m debug -a "var=hostvars[inventory_hostname]"
```

Определение переменной:
```bash
echo "webserver_nginx_port: 8080" >> inventories/dev/group_vars/all.yml
```

### Permission denied

**Ошибка:**
```
fatal: [dev-web-01]: FAILED! => {"changed": false, "msg": "Failed to install packages: E: Could not open lock file"}
```

**Решение:**

Валидация настройки become:
```yaml
- hosts: webservers
  become: true
```

Или в ansible.cfg:
```ini
[privilege_escalation]
become = True
```

### SSH connection failed

**Ошибка:**
```
fatal: [dev-web-01]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh"}
```

**Возможные причины:**

**Некорректный IP адрес**
```bash
ping <DEV_WEB_01_IP>
```

**Отсутствие SSH ключа**
```bash
ssh-copy-id ansible@<DEV_WEB_01_IP>
```

**Неверный пользователь**
```ini
[dev:vars]
ansible_user=ansible
```

### Handler не выполняется

**Причина:** Несоответствие имени в `notify` и handler.

**Валидация:**
```yaml
# tasks/main.yml
notify: Перезапуск Nginx

# handlers/main.yml
- name: Перезапуск Nginx
```

Имена должны совпадать точно, включая регистр и пробелы.

---

## Best Practices

### Структура и организация

**Разделение по функциональности:**
```
playbooks/
├── site.yml          # полное развертывание
├── webservers.yml    # веб-серверы
└── databases.yml     # базы данных
```

**Модульность ролей:**
- Одна роль = один компонент
- Роли независимы от проекта
- Переиспользуемость между проектами

**Соглашение об именовании:**
```yaml
webserver_port: 80
database_port: 5432
```

### Безопасность

**Ansible Vault для секретов:**
```bash
ansible-vault encrypt inventories/prod/group_vars/secrets.yml
```

**Разделение секретов по окружениям:**
```yaml
# dev - простые пароли
db_password: dev123

# prod - зашифрованные пароли
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256...
```

**Валидация перед production:**
```bash
ansible-playbook -i inventories/prod/hosts playbooks/site.yml --check
```

### Тестирование

**Workflow тестирования:**
```
1. ansible-playbook --syntax-check
2. ansible-lint
3. ansible-playbook --check (dev)
4. ansible-playbook (dev)
5. Функциональные тесты (dev)
6. ansible-playbook --check (prod)
7. ansible-playbook (prod)
8. Функциональные тесты (prod)
```

**Идемпотентность:**
```bash
ansible-playbook playbooks/site.yml
ansible-playbook playbooks/site.yml
# Второй запуск: changed=0
```

---

## Полезные команды

### Работа с inventory

```bash
# Список всех хостов
ansible-inventory -i inventories/dev/hosts --list

# Граф групп
ansible-inventory -i inventories/dev/hosts --graph

# Переменные хоста
ansible -i inventories/dev/hosts dev-web-01 -m debug -a "var=hostvars[inventory_hostname]"
```

### Ad-hoc команды

```bash
# Ping хостов
ansible -i inventories/dev/hosts all -m ping

# Выполнение команды
ansible -i inventories/dev/hosts webservers -m command -a "uptime"

# Статус службы
ansible -i inventories/dev/hosts webservers -m service -a "name=nginx state=started"

# Системные факты
ansible -i inventories/dev/hosts dev-web-01 -m setup
```

### Отладка playbook

```bash
# Verbose вывод
ansible-playbook playbooks/site.yml -v
ansible-playbook playbooks/site.yml -vvv

# Фильтрация по тегам
ansible-playbook playbooks/site.yml --tags "install"
ansible-playbook playbooks/site.yml --skip-tags "config"

# Ограничение хостов
ansible-playbook playbooks/site.yml --limit dev-web-01

# Начало с задачи
ansible-playbook playbooks/site.yml --start-at-task "Установка Nginx"
```

### Проверка конфигурации

```bash
# Текущая конфигурация
ansible-config dump

# Измененные настройки
ansible-config dump --only-changed

# Список настроек
ansible-config list
```
