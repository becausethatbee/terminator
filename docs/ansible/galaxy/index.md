# Ansible Galaxy

Репозиторий готовых ролей и коллекций для Ansible с механизмом установки и управления зависимостями.

## Функциональность

- Централизованное хранилище ролей
- Система управления версиями
- Документация и примеры использования
- Интеграция с GitHub
- Проверка совместимости с платформами

---

## Структура роли

```
nginx/              
├── tasks/          # Задачи установки и настройки
│   └── main.yml    
├── defaults/       # Переменные по умолчанию
│   └── main.yml    
├── templates/      # Jinja2 шаблоны
│   ├── nginx.conf.j2
│   └── site.conf.j2
├── files/          # Статические файлы
│   └── ssl-cert.pem
└── handlers/       # Handlers для перезапуска служб
    └── main.yml    
```

Основные директории:

| Директория | Назначение |
|------------|------------|
| `tasks/` | Задачи установки и настройки |
| `defaults/` | Переменные по умолчанию |
| `vars/` | Переменные с высоким приоритетом |
| `templates/` | Jinja2 шаблоны |
| `files/` | Статические файлы |
| `handlers/` | Handlers для перезапуска служб |
| `meta/` | Метаданные и зависимости |

---

## Поиск ролей

### CLI поиск

Поиск Docker роли:

```bash
ansible-galaxy search docker --author geerlingguy
```

Поиск с фильтром платформы:

```bash
ansible-galaxy search docker --platforms Debian
```

### Веб-интерфейс

```
https://galaxy.ansible.com
```

Функции:
- Поиск по ключевым словам
- Фильтрация по платформам
- Сортировка по рейтингу
- Просмотр документации

---

## Критерии выбора роли

### Проверенные авторы

| Автор | Описание |
|-------|----------|
| `geerlingguy` | ~500+ ролей, автор "Ansible for DevOps" |
| `robertdebock` | ~400+ ролей |
| `debops` | Проект для управления инфраструктурой |
| `oefenweb` | Голландская команда |

Официальные роли вендоров:

| Namespace | Вендор |
|-----------|--------|
| `nginxinc.*` | NGINX |
| `elastic.*` | Elastic |
| `grafana.*` | Grafana Labs |
| `docker.*` | Docker Inc |

### Метрики оценки

Galaxy:
- Downloads - популярность
- Stars - рейтинг пользователей
- Дата последнего обновления
- Поддерживаемые платформы

GitHub:
- Stars - популярность
- Issues - текущие проблемы
- Дата последнего коммита
- README качество

Красные флаги (не использовать если):
- Обновлений > года
- Много открытых issues без ответов
- Отсутствие документации
- Загрузок < 1000

---

## Установка ролей

### Одиночная установка

Базовая установка:

```bash
ansible-galaxy install geerlingguy.docker
```

Конкретная версия:

```bash
ansible-galaxy install geerlingguy.docker,7.5.5
```

Установка в директорию:

```bash
ansible-galaxy install geerlingguy.docker -p ./roles/
```

### Установка через requirements.yml

Файл зависимостей:

```yaml
# requirements.yml
---
roles:
  - name: geerlingguy.docker
    version: "7.5.5"
  
  - src: https://github.com/geerlingguy/ansible-role-nginx.git
    name: nginx
    version: master
  
  - src: https://example.com/roles/custom-role.tar.gz
    name: custom_role

collections:
  - name: community.general
    version: ">=3.0.0"
```

Установка:

```bash
ansible-galaxy install -r requirements.yml
```

Принудительное обновление:

```bash
ansible-galaxy install -r requirements.yml --force
```

### Просмотр установленных

Список ролей:

```bash
ansible-galaxy list
```

---

## Изучение роли

Структура директорий:

```bash
ls -la roles/geerlingguy.docker/
```

Просмотр переменных:

```bash
cat roles/geerlingguy.docker/defaults/main.yml
```

Пример переменных Docker роли:

```yaml
---
docker_edition: 'ce'
docker_packages:
  - "docker-{{ docker_edition }}"
  - "docker-{{ docker_edition }}-cli"
  - "containerd.io"
  - docker-buildx-plugin
docker_packages_state: present

docker_service_manage: true
docker_service_state: started
docker_service_enabled: true

docker_install_compose_plugin: true
docker_compose_package: docker-compose-plugin

docker_users: []

docker_daemon_options: {}
```

Ключевые переменные:

| Переменная | Назначение |
|------------|------------|
| `docker_edition` | Редакция Docker (ce/ee) |
| `docker_packages_state` | Состояние пакетов |
| `docker_service_state` | Состояние службы |
| `docker_users` | Пользователи для группы docker |
| `docker_daemon_options` | Настройки daemon |

---

## Использование роли

### Базовое использование

Файл `deploy-docker.yml`:

```yaml
---
- name: Install Docker
  hosts: localhost
  become: yes
  
  roles:
    - geerlingguy.docker
```

Запуск:

```bash
ansible-playbook deploy-docker.yml
```

### Переопределение переменных

Playbook с кастомными настройками:

```yaml
---
- name: Install Docker
  hosts: localhost
  become: yes
  
  vars:
    docker_edition: 'ce'
    docker_install_compose_plugin: true
    
    docker_users:
      - "{{ ansible_env.USER }}"
    
    docker_daemon_options:
      log-driver: "json-file"
      log-opts:
        max-size: "10m"
        max-file: "3"
  
  roles:
    - geerlingguy.docker
```

Настройки daemon:

| Параметр | Назначение |
|----------|------------|
| `log-driver` | Формат логов контейнеров |
| `max-size` | Максимальный размер лог-файла |
| `max-file` | Количество файлов для ротации |

### Переменные в group_vars

Файл `group_vars/docker_hosts/docker.yml`:

```yaml
---
docker_edition: 'ce'
docker_install_compose_plugin: true

docker_users:
  - deploy
  - developer

docker_daemon_options:
  log-driver: "json-file"
  log-opts:
    max-size: "10m"
    max-file: "3"
  storage-driver: "overlay2"
```

Playbook использует переменные автоматически:

```yaml
---
- name: Install Docker
  hosts: docker_hosts
  become: yes
  
  roles:
    - geerlingguy.docker
```

---

## Валидация

### Проверка синтаксиса

```bash
ansible-playbook --syntax-check deploy-docker.yml
```

### Dry-run

```bash
ansible-playbook deploy-docker.yml --check
```

### Diff

```bash
ansible-playbook deploy-docker.yml --diff
```

### Verbose

```bash
ansible-playbook deploy-docker.yml -v
ansible-playbook deploy-docker.yml -vv
ansible-playbook deploy-docker.yml -vvv
```

### Проверка установки

Docker:

```bash
docker --version
systemctl status docker --no-pager
cat /etc/docker/daemon.json
groups $USER
```

Git:

```bash
git --version
git lfs version
```

---

## Управление ролями

### Обновление

Обновление роли:

```bash
ansible-galaxy install geerlingguy.docker --force
```

Обновление всех:

```bash
ansible-galaxy install -r requirements.yml --force
```

### Удаление

```bash
ansible-galaxy remove geerlingguy.docker
```

### Информация

```bash
ansible-galaxy info geerlingguy.docker
```

Зависимости роли:

```bash
cat roles/geerlingguy.docker/meta/main.yml
```

---

## Использование нескольких ролей

### Последовательное применение

```yaml
---
- name: Install full stack
  hosts: webservers
  become: yes
  
  roles:
    - geerlingguy.git
    - geerlingguy.docker
    - geerlingguy.nginx
```

### Роли с переменными

```yaml
---
- name: Install Docker and Nginx
  hosts: localhost
  become: yes
  
  roles:
    - role: geerlingguy.docker
      vars:
        docker_edition: 'ce'
        docker_users:
          - "{{ ansible_env.USER }}"
    
    - role: geerlingguy.nginx
      vars:
        nginx_remove_default_vhost: true
        nginx_vhosts:
          - listen: "80"
            server_name: "localhost"
```

### Условное применение

```yaml
---
- name: Install with conditions
  hosts: all
  become: yes
  
  roles:
    - role: geerlingguy.docker
      when: ansible_os_family == "Debian"
    
    - role: geerlingguy.nginx
      when: inventory_hostname in groups['webservers']
```

---

## Файл requirements.yml

Полный пример:

```yaml
# requirements.yml
---
roles:
  # Инфраструктура
  - name: geerlingguy.docker
    version: "7.5.5"
  
  - name: geerlingguy.git
    version: "3.0.1"
  
  # Веб-серверы
  - name: geerlingguy.nginx
    version: "3.2.0"
  
  # Базы данных
  - name: geerlingguy.postgresql
  
  - name: geerlingguy.redis
  
  # Мониторинг
  - src: https://github.com/cloudalchemy/ansible-prometheus.git
    name: prometheus
    version: "v4.0.0"

collections:
  - name: community.general
    version: ">=8.0.0"
  
  - name: ansible.posix
```

Установка:

```bash
ansible-galaxy install -r requirements.yml
```

---

## Best Practices

### Версионирование

Фиксация версий:

```yaml
# Правильно
- name: geerlingguy.docker
  version: "7.5.5"

# Неправильно
- name: geerlingguy.docker
```

### Структура проекта

```
ansible-project/
├── inventory/
│   ├── production.yml
│   └── staging.yml
├── group_vars/
│   ├── all/
│   └── webservers/
├── roles/
│   ├── geerlingguy.docker/
│   └── geerlingguy.nginx/
├── requirements.yml
├── site.yml
└── README.md
```

### Проверка перед использованием

Чеклист:
1. Прочитать README на GitHub
2. Проверить примеры использования
3. Изучить defaults/main.yml
4. Посмотреть открытые Issues
5. Проверить дату последнего обновления

### Тестирование

Тест на staging:

```yaml
---
- name: Test role
  hosts: test_server
  become: yes
  
  roles:
    - geerlingguy.docker
```

### Документирование

README проекта:

```markdown
# Используемые роли

## geerlingguy.docker (7.5.5)
- Установка Docker CE
- Настройка логирования
- Добавление пользователей в группу

## geerlingguy.nginx (3.2.0)
- Установка Nginx
- Настройка виртуальных хостов
```

---

## Команды Galaxy

Справочник:

```bash
# Поиск
ansible-galaxy search <keyword>
ansible-galaxy search <keyword> --author <author>
ansible-galaxy search <keyword> --platforms <platform>

# Информация
ansible-galaxy info <author>.<role>

# Установка
ansible-galaxy install <author>.<role>
ansible-galaxy install <author>.<role>,<version>
ansible-galaxy install <author>.<role> -p ./roles/

# Из файла
ansible-galaxy install -r requirements.yml
ansible-galaxy install -r requirements.yml --force

# Управление
ansible-galaxy list
ansible-galaxy remove <author>.<role>

# Создание
ansible-galaxy init <role_name>
```
