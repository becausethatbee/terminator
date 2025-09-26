# Ansible Galaxy - Использование готовых ролей

Практическое руководство по использованию готовых ролей из Ansible Galaxy для ускорения разработки инфраструктуры.

## Что такое Ansible Galaxy

**Ansible Galaxy** - публичный репозиторий готовых ролей и коллекций для Ansible.

**Преимущества использования Galaxy:**
- Экономия времени разработки
- Проверенные временем решения
- Активная поддержка сообщества
- Документация и примеры использования
- Тестирование на разных платформах

## Что такое роли в Ansible

**Роль** - организованная структура для группировки связанных задач, переменных, файлов и шаблонов.

**Аналогия с программированием:**

Без ролей (всё в одном файле):
```python
# main.py - 500 строк кода
# Установка базы данных
# Настройка веб-сервера
# Настройка мониторинга
# Деплой приложения
```

С ролями (использование готовых модулей):
```python
# main.py - 10 строк
import database_setup
import web_server
import monitoring
import app_deploy
```

**Пример в Ansible:**

Вариант 1 - БЕЗ роли (всё вручную):
```yaml
# playbook.yml - 200 строк
- name: "Установка веб-сервера"
  hosts: webservers
  tasks:
    - name: "Установить nginx"
      apt:
        name: nginx
        state: present
    
    - name: "Создать конфиг"
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
    
    # ... еще 50 задач
```

Вариант 2 - С РОЛЬЮ (чисто и просто):
```yaml
# playbook.yml - 10 строк
- name: "Установка веб-сервера"
  hosts: webservers
  roles:
    - nginx
```

### Структура роли

```
nginx/              
├── tasks/          # Что делать (шаги установки)
│   └── main.yml    
├── defaults/       # Настройки по умолчанию
│   └── main.yml    
├── templates/      # Шаблоны конфигов
│   ├── nginx.conf.j2
│   └── site.conf.j2
├── files/          # Статические файлы
│   └── ssl-cert.pem
└── handlers/       # Обработчики событий
    └── main.yml    
```

**Основные директории роли:**
- `tasks/` - основные задачи установки и настройки
- `defaults/` - переменные по умолчанию (легко переопределить)
- `vars/` - переменные с высоким приоритетом
- `templates/` - Jinja2 шаблоны конфигурационных файлов
- `files/` - статические файлы для копирования
- `handlers/` - обработчики для перезапуска служб
- `meta/` - метаданные и зависимости

## Поиск ролей в Galaxy

### Поиск через командную строку

Поиск роли для установки Docker:
```bash
ansible-galaxy search docker --author geerlingguy
```

Поиск с фильтром по платформе:
```bash
ansible-galaxy search docker --platforms Debian
```

Результат поиска:
```
Found 2 roles matching your search:
 Name                   Description
 ----                   -----------
 geerlingguy.docker     Docker for Linux.
 geerlingguy.docker_arm Docker setup for Raspberry Pi and ARM-based devices.
```

### Поиск через веб-интерфейс

Перейдите на сайт Galaxy:
```
https://galaxy.ansible.com
```

Функции веб-интерфейса:
- Поиск по ключевым словам
- Фильтрация по платформам
- Сортировка по рейтингу и загрузкам
- Просмотр README и примеров

## Критерии выбора роли

### Проверенные авторы

**Топ авторов качественных ролей:**
- `geerlingguy` (Jeff Geerling) - ~500+ ролей, автор книги "Ansible for DevOps"
- `robertdebock` - ~400+ ролей, очень активный разработчик
- `debops` - целый проект для управления инфраструктурой
- `oefenweb` - голландская команда, качественные роли

**Официальные роли от вендоров:**
- `nginxinc.*` - от NGINX
- `elastic.*` - от Elastic (Elasticsearch)
- `grafana.*` - от Grafana Labs
- `docker.*` - от Docker Inc

### Критерии оценки роли

**На сайте Galaxy проверяйте:**
- Количество загрузок (downloads) - популярность
- Рейтинг (stars) - оценки пользователей
- Дата последнего обновления - активная поддержка
- Поддерживаемые платформы - совместимость с вашей ОС

**На GitHub репозитории проверяйте:**
- Количество звезд - популярность
- Открытые Issues - текущие проблемы
- Дата последнего коммита - активность проекта
- Качество README - наличие документации

**Красные флаги (НЕ используйте роль если):**
- Обновлялась больше года назад
- Много открытых issues без ответов
- Нет README или документации
- Мало загрузок (< 1000)

### Получение информации о роли

Подробная информация через командную строку:
```bash
ansible-galaxy info geerlingguy.docker
```

Вывод содержит:
- Описание роли
- Поддерживаемые платформы
- Зависимости от других ролей
- Минимальную версию Ansible
- Ссылку на GitHub репозиторий

## Установка ролей

### Установка одной роли

Базовая установка роли:
```bash
ansible-galaxy install geerlingguy.docker
```

Результат:
```
Starting galaxy role install process
- downloading role 'docker', owned by geerlingguy
- downloading role from https://github.com/geerlingguy/ansible-role-docker/archive/7.5.5.tar.gz
- extracting geerlingguy.docker to /home/user/.ansible/roles/geerlingguy.docker
- geerlingguy.docker (7.5.5) was installed successfully
```

Установка конкретной версии:
```bash
ansible-galaxy install geerlingguy.docker,7.5.5
```

Установка в конкретную директорию:
```bash
ansible-galaxy install geerlingguy.docker -p ./roles/
```

### Установка через requirements.yml

Создание файла зависимостей для установки нескольких ролей:

```yaml
# requirements.yml
---
roles:
  # Роль из Galaxy с конкретной версией
  - name: geerlingguy.docker
    version: "7.5.5"
  
  # Роль из Git репозитория
  - src: https://github.com/geerlingguy/ansible-role-nginx.git
    name: nginx
    version: master
  
  # Роль из архива
  - src: https://example.com/roles/custom-role.tar.gz
    name: custom_role

collections:
  # Коллекции (новый формат)
  - name: community.general
    version: ">=3.0.0"
```

Установка всех ролей из файла:
```bash
ansible-galaxy install -r requirements.yml
```

Результат установки:
```
Starting galaxy role install process
- geerlingguy.docker (7.5.5) is already installed, skipping.
- downloading role 'nginx', owned by geerlingguy
- extracting geerlingguy.nginx to /home/user/ansible-docker-infrastructure/roles/geerlingguy.nginx
- geerlingguy.nginx (3.2.0) was installed successfully
- downloading role 'certbot', owned by geerlingguy
- extracting geerlingguy.certbot to /home/user/ansible-docker-infrastructure/roles/geerlingguy.certbot
- geerlingguy.certbot (5.4.1) was installed successfully
```

Принудительное обновление существующих ролей:
```bash
ansible-galaxy install -r requirements.yml --force
```

### Просмотр установленных ролей

Список всех установленных ролей:
```bash
ansible-galaxy list
```

Результат:
```
# /home/user/ansible-docker-infrastructure/roles
- geerlingguy.docker, 7.5.5
- geerlingguy.nginx, 3.2.0
- geerlingguy.certbot, 5.4.1
- geerlingguy.git, 3.0.1
```

## Изучение структуры роли

Просмотр структуры установленной роли:
```bash
ls -la roles/geerlingguy.docker/
```

Результат:
```
total 60
drwxrwxr-x  9 user user 4096 Sep 26 16:17 .
drwxrwxr-x 11 user user 4096 Sep 26 16:17 ..
drwxrwxr-x  2 user user 4096 Sep 26 16:17 defaults
drwxrwxr-x  2 user user 4096 Sep 26 16:17 handlers
drwxrwxr-x  2 user user 4096 Sep 26 16:17 meta
drwxrwxr-x  3 user user 4096 Sep 26 16:17 molecule
-rw-r--r--  1 user user 6396 Sep 21 03:52 README.md
drwxrwxr-x  2 user user 4096 Sep 26 16:17 tasks
drwxrwxr-x  2 user user 4096 Sep 26 16:17 vars
```

Просмотр доступных переменных роли:
```bash
cat roles/geerlingguy.docker/defaults/main.yml
```

Результат (пример для роли Docker):
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

**Ключевые переменные роли Docker:**
- `docker_edition` - редакция Docker (ce/ee)
- `docker_packages_state` - состояние пакетов (present/latest)
- `docker_service_state` - состояние службы (started/stopped)
- `docker_users` - пользователи для добавления в группу docker
- `docker_daemon_options` - настройки Docker daemon

## Использование роли в Playbook

### Базовое использование

Простой playbook с использованием роли:

```yaml
# deploy-docker.yml
---
- name: "Установка Docker через Galaxy роль"
  hosts: localhost
  become: yes
  
  roles:
    - geerlingguy.docker
```

Запуск playbook:
```bash
ansible-playbook deploy-docker.yml
```

Роль автоматически выполнит:
1. Определение операционной системы
2. Добавление репозитория Docker
3. Установку Docker Engine и плагинов
4. Настройку docker daemon
5. Запуск службы Docker

### Переопределение переменных в playbook

Использование роли с кастомными настройками:

```yaml
# deploy-docker.yml
---
- name: "Установка Docker с кастомными настройками"
  hosts: localhost
  become: yes
  
  vars:
    # Переопределяем переменные роли
    docker_edition: 'ce'
    docker_install_compose_plugin: true
    
    # Добавляем пользователя в группу docker
    docker_users:
      - "{{ ansible_env.USER }}"
    
    # Настройки Docker daemon
    docker_daemon_options:
      log-driver: "json-file"
      log-opts:
        max-size: "10m"
        max-file: "3"
  
  roles:
    - geerlingguy.docker
```

**Объяснение настроек:**

`docker_users` - добавление пользователя в группу docker:
- Позволяет запускать docker без sudo
- `ansible_env.USER` - текущий пользователь системы

`docker_daemon_options` - настройки демона Docker:
- `log-driver: "json-file"` - формат логов контейнеров
- `max-size: "10m"` - максимальный размер одного лог-файла
- `max-file: "3"` - количество файлов для ротации логов

**Почему важны настройки логов:**
Без ограничений логи контейнеров могут заполнить весь диск. Настройки выше ограничивают:
- Размер одного файла до 10 МБ
- Хранение только 3 последних файлов
- Автоматическую ротацию при достижении лимита

### Переопределение в inventory или group_vars

Организация переменных в group_vars:

```yaml
# group_vars/docker_hosts/docker.yml
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

Упрощенный playbook использует переменные из group_vars:

```yaml
# deploy-docker.yml
---
- name: "Установка Docker"
  hosts: docker_hosts
  become: yes
  
  roles:
    - geerlingguy.docker
```

## Проверка и тестирование

### Проверка синтаксиса playbook

Проверка синтаксиса перед запуском:
```bash
ansible-playbook --syntax-check deploy-docker.yml
```

Успешный результат:
```
playbook: deploy-docker.yml
```

### Dry-run режим

Проверка без реального выполнения:
```bash
ansible-playbook deploy-docker.yml --check
```

Показывает что будет изменено без применения изменений.

### Вывод различий

Показать различия при изменении файлов:
```bash
ansible-playbook deploy-docker.yml --diff
```

### Уровни детализации вывода

Разные уровни подробности выполнения:

```bash
# Базовый вывод
ansible-playbook deploy-docker.yml

# Подробный вывод
ansible-playbook deploy-docker.yml -v

# Очень подробный
ansible-playbook deploy-docker.yml -vv

# Максимально подробный (debug)
ansible-playbook deploy-docker.yml -vvv
```

### Проверка результата

После выполнения playbook проверьте установку:

Для Docker:
```bash
docker --version
systemctl status docker --no-pager
cat /etc/docker/daemon.json
groups $USER
```

Для Git:
```bash
git --version
git lfs version
```

## Пример playbook с ролью Git

### Просмотр переменных роли Git

```bash
cat roles/geerlingguy.git/defaults/main.yml
```

Результат:
```yaml
---
git_install_from_source: false
git_packages:
  - git

git_install_from_source_force_update: false
git_version: "2.26.0"
git_install_path: "/usr"
```

### Создание playbook с Git

```yaml
# deploy-git.yml
---
- name: "Установка Git через Galaxy роль"
  hosts: localhost
  become: yes
  
  vars:
    # Установка из пакетов (быстрее)
    git_install_from_source: false
    
    # Дополнительные пакеты
    git_packages:
      - git
      - git-lfs
  
  roles:
    - geerlingguy.git
```

Запуск playbook:
```bash
ansible-playbook deploy-git.yml
```

Результат выполнения:
```
PLAY [Установка Git через Galaxy роль] ************************

TASK [geerlingguy.git : Update apt cache (Debian).] ***********
ok: [localhost]

TASK [geerlingguy.git : Ensure git is installed (Debian).] ****
changed: [localhost]

PLAY RECAP ****************************************************
localhost                  : ok=2    changed=1    failed=0
```

## Управление ролями

### Обновление роли

Обновление конкретной роли до последней версии:
```bash
ansible-galaxy install geerlingguy.docker --force
```

Обновление всех ролей из requirements.yml:
```bash
ansible-galaxy install -r requirements.yml --force
```

### Удаление роли

Удаление установленной роли:
```bash
ansible-galaxy remove geerlingguy.docker
```

Результат:
```
- successfully removed geerlingguy.docker
```

### Информация о роли

Получение детальной информации:
```bash
ansible-galaxy info geerlingguy.docker
```

Просмотр зависимостей роли:
```bash
cat roles/geerlingguy.docker/meta/main.yml
```

## Использование нескольких ролей

### Последовательное применение ролей

Применение нескольких ролей по порядку:

```yaml
# deploy-stack.yml
---
- name: "Установка полного стека"
  hosts: webservers
  become: yes
  
  roles:
    - geerlingguy.git
    - geerlingguy.docker
    - geerlingguy.nginx
```

Роли выполняются в указанном порядке:
1. Сначала Git
2. Затем Docker
3. В конце Nginx

### Роли с разными переменными

Применение ролей с индивидуальными настройками:

```yaml
---
- name: "Установка Docker и Nginx"
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

### Условное применение ролей

Применение роли только при выполнении условия:

```yaml
---
- name: "Установка с условиями"
  hosts: all
  become: yes
  
  roles:
    - role: geerlingguy.docker
      when: ansible_os_family == "Debian"
    
    - role: geerlingguy.nginx
      when: inventory_hostname in groups['webservers']
```

## Создание requirements.yml для проекта

Пример полного файла зависимостей проекта:

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

Установка всего проекта одной командой:
```bash
ansible-galaxy install -r requirements.yml
```

## Best Practices

### Версионирование ролей

Всегда указывайте версии в requirements.yml:

```yaml
# Хорошо - зафиксированная версия
- name: geerlingguy.docker
  version: "7.5.5"

# Плохо - может сломаться при обновлении
- name: geerlingguy.docker
```

### Организация проекта

Рекомендуемая структура проекта:

```
ansible-project/
├── inventory/
│   ├── production.yml
│   └── staging.yml
├── group_vars/
│   ├── all/
│   └── webservers/
├── roles/              # Установленные роли
│   ├── geerlingguy.docker/
│   └── geerlingguy.nginx/
├── requirements.yml    # Зависимости
├── site.yml           # Главный playbook
└── README.md
```

### Проверка перед использованием

Перед использованием новой роли:

1. Прочитайте README на GitHub
2. Проверьте примеры использования
3. Изучите defaults/main.yml
4. Посмотрите открытые Issues
5. Проверьте дату последнего обновления

### Тестирование ролей

Тестируйте роли сначала на тестовом окружении:

```yaml
# test.yml
---
- name: "Тестирование роли"
  hosts: test_server
  become: yes
  
  roles:
    - geerlingguy.docker
```

Только после успешного тестирования применяйте на production.

### Документирование использования

Документируйте использованные роли в README проекта:

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

## Команды Ansible Galaxy

Полный справочник команд:

```bash
# Поиск ролей
ansible-galaxy search <keyword>
ansible-galaxy search <keyword> --author <author>
ansible-galaxy search <keyword> --platforms <platform>

# Информация о роли
ansible-galaxy info <author>.<role>

# Установка роли
ansible-galaxy install <author>.<role>
ansible-galaxy install <author>.<role>,<version>
ansible-galaxy install <author>.<role> -p ./roles/

# Установка из файла
ansible-galaxy install -r requirements.yml
ansible-galaxy install -r requirements.yml --force

# Управление ролями
ansible-galaxy list
ansible-galaxy remove <author>.<role>

# Создание своей роли
ansible-galaxy init <role_name>
```
