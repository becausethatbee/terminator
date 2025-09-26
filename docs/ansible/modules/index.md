# Ansible: Playbooks с популярными модулями

Подробное руководство по созданию Ansible playbooks с использованием наиболее популярных и важных модулей для автоматизации инфраструктуры.

## Содержание

- [Введение](#введение)
- [Популярные модули Ansible](#популярные-модули-ansible)
- [Создание комплексного playbook](#создание-комплексного-playbook)
- [Примеры использования модулей](#примеры-использования-модулей)
- [Выполнение и отладка playbook](#выполнение-и-отладка-playbook)
- [Полный справочник модулей](#полный-справочник-модулей)

---

## Введение

Ansible модули - это переиспользуемые, самостоятельные скрипты, которые выполняют определенные задачи на управляемых хостах. Модули являются строительными блоками для создания playbooks и автоматизации инфраструктуры.

### Ключевые концепции

**Модуль** - программа, которая выполняет действие на локальной машине, API или удаленном хосте

**Task (Задача)** - определяет действие с использованием модуля

**Play** - набор задач, выполняемых на определенных хостах

**Playbook** - YAML файл, содержащий один или несколько plays

---

## Популярные модули Ansible

### Категории модулей

#### 1. Управление файлами
- `copy` - копирование файлов
- `template` - работа с Jinja2 шаблонами
- `file` - управление файлами и директориями
- `lineinfile` - изменение строк в файлах
- `blockinfile` - управление блоками текста

#### 2. Управление пакетами
- `package` - универсальный менеджер пакетов
- `apt` - пакеты Debian/Ubuntu
- `yum/dnf` - пакеты RHEL/CentOS
- `pip` - Python пакеты
- `npm` - Node.js пакеты

#### 3. Управление службами
- `service` - управление системными службами
- `systemd` - расширенное управление systemd
- `cron` - управление cron задачами

#### 4. Управление пользователями
- `user` - создание и управление пользователями
- `group` - управление группами
- `authorized_key` - SSH ключи

#### 5. Выполнение команд
- `command` - выполнение команд
- `shell` - выполнение через shell
- `script` - выполнение локальных скриптов
- `raw` - выполнение без Python

#### 6. Работа с сетью
- `uri` - HTTP запросы
- `get_url` - загрузка файлов
- `git` - работа с Git репозиториями

#### 7. Облачные модули
- `ec2` - AWS EC2
- `azure_rm` - Microsoft Azure
- `gcp_compute` - Google Cloud
- `digital_ocean` - DigitalOcean

---

## Создание комплексного playbook

### Структура проекта

```
ansible-project/
├── ansible.cfg
├── inventory
├── playbooks/
│   ├── site.yml
│   └── webserver.yml
├── templates/
│   ├── nginx.conf.j2
│   └── app.config.j2
├── files/
│   └── ssl_cert.pem
├── vars/
│   └── main.yml
└── roles/
    └── webserver/
```

### Основной playbook: `site.yml`

```yaml
---
- name: "Полная настройка веб-сервера"
  hosts: webservers
  become: yes
  gather_facts: true
  
  vars_files:
    - vars/main.yml
  
  vars:
    app_name: "myapp"
    app_version: "1.0.0"
    app_port: 8080
    app_user: "appuser"
    app_group: "appgroup"
    app_dir: "/opt/{{ app_name }}"
    log_dir: "/var/log/{{ app_name }}"
    
  tasks:
    # ============================================
    # БЛОК 1: Настройка системы
    # ============================================
    
    - name: "Обновление кэша пакетов (Debian/Ubuntu)"
      apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
      tags: [system, packages]
    
    - name: "Обновление кэша пакетов (RHEL/CentOS)"
      yum:
        update_cache: yes
      when: ansible_os_family == "RedHat"
      tags: [system, packages]
    
    - name: "Обновление кэша пакетов (openSUSE)"
      community.general.zypper:
        update_cache: yes
      when: ansible_os_family == "Suse"
      tags: [system, packages]
    
    - name: "Установка базовых пакетов"
      package:
        name:
          - git
          - curl
          - wget
          - vim
          - htop
          - net-tools
          - nginx
          - python3
          - python3-pip
        state: present
      tags: [system, packages]
    
    # ============================================
    # БЛОК 2: Управление пользователями
    # ============================================
    
    - name: "Создание группы приложения"
      group:
        name: "{{ app_group }}"
        state: present
        system: yes
      tags: [users]
    
    - name: "Создание пользователя приложения"
      user:
        name: "{{ app_user }}"
        group: "{{ app_group }}"
        groups: "sudo"
        shell: /bin/bash
        create_home: yes
        home: "/home/{{ app_user }}"
        comment: "Application service user"
        state: present
      tags: [users]
    
    - name: "Добавление SSH ключа для пользователя"
      authorized_key:
        user: "{{ app_user }}"
        state: present
        key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
      tags: [users, ssh]
    
    # ============================================
    # БЛОК 3: Создание структуры директорий
    # ============================================
    
    - name: "Создание директории приложения"
      file:
        path: "{{ item }}"
        state: directory
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        mode: '0755'
      loop:
        - "{{ app_dir }}"
        - "{{ app_dir }}/config"
        - "{{ app_dir }}/public"
        - "{{ app_dir }}/bin"
        - "{{ log_dir }}"
      tags: [directories]
    
    - name: "Создание символической ссылки для логов"
      file:
        src: "{{ log_dir }}"
        dest: "{{ app_dir }}/logs"
        state: link
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
      tags: [directories]
    
    # ============================================
    # БЛОК 4: Копирование и настройка файлов
    # ============================================
    
    - name: "Копирование конфигурационных файлов"
      copy:
        content: |
          # {{ app_name }} Configuration
          APP_NAME={{ app_name }}
          APP_VERSION={{ app_version }}
          APP_ENV=production
          APP_PORT={{ app_port }}
          APP_USER={{ app_user }}
          LOG_LEVEL=info
          DATABASE_URL=postgresql://user:pass@localhost/{{ app_name }}
        dest: "{{ app_dir }}/config/.env"
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        mode: '0600'
        backup: yes
      tags: [config]
    
    - name: "Создание конфигурации Nginx из шаблона"
      template:
        src: templates/nginx.conf.j2
        dest: "/etc/nginx/sites-available/{{ app_name }}.conf"
        owner: root
        group: root
        mode: '0644'
        validate: 'nginx -t -c %s'
        backup: yes
      notify: 
        - reload nginx
      tags: [nginx, config]
    
    - name: "Активация конфигурации Nginx"
      file:
        src: "/etc/nginx/sites-available/{{ app_name }}.conf"
        dest: "/etc/nginx/sites-enabled/{{ app_name }}.conf"
        state: link
      notify:
        - reload nginx
      tags: [nginx, config]
    
    - name: "Удаление default конфигурации Nginx"
      file:
        path: "/etc/nginx/sites-enabled/default"
        state: absent
      notify:
        - reload nginx
      tags: [nginx, config]
    
    - name: "Копирование SSL сертификата"
      copy:
        src: files/ssl_cert.pem
        dest: "/etc/nginx/ssl/{{ app_name }}.pem"
        owner: root
        group: root
        mode: '0644'
      when: ssl_enabled | default(false)
      tags: [nginx, ssl]
    
    # ============================================
    # БЛОК 5: Работа с Git репозиторием
    # ============================================
    
    - name: "Клонирование репозитория приложения"
      git:
        repo: "https://github.com/example/{{ app_name }}.git"
        dest: "{{ app_dir }}/source"
        version: "{{ app_version }}"
        force: yes
      become_user: "{{ app_user }}"
      tags: [deploy, git]
    
    # ============================================
    # БЛОК 6: Выполнение команд и скриптов
    # ============================================
    
    - name: "Установка Python зависимостей"
      pip:
        requirements: "{{ app_dir }}/source/requirements.txt"
        virtualenv: "{{ app_dir }}/venv"
        virtualenv_command: python3 -m venv
      become_user: "{{ app_user }}"
      tags: [deploy, dependencies]
    
    - name: "Сборка статических файлов"
      shell: |
        source {{ app_dir }}/venv/bin/activate
        python manage.py collectstatic --noinput
      args:
        chdir: "{{ app_dir }}/source"
        executable: /bin/bash
      become_user: "{{ app_user }}"
      tags: [deploy, build]
    
    - name: "Выполнение миграций базы данных"
      command: "{{ app_dir }}/venv/bin/python manage.py migrate --noinput"
      args:
        chdir: "{{ app_dir }}/source"
      become_user: "{{ app_user }}"
      register: migration_result
      changed_when: "'No migrations to apply' not in migration_result.stdout"
      tags: [deploy, database]
    
    - name: "Запуск локального скрипта на удаленном хосте"
      script:
        cmd: scripts/post_deploy.sh
        chdir: "{{ app_dir }}"
      become_user: "{{ app_user }}"
      tags: [deploy, scripts]
    
    # ============================================
    # БЛОК 7: Настройка systemd службы
    # ============================================
    
    - name: "Создание systemd unit файла"
      template:
        src: templates/app.service.j2
        dest: "/etc/systemd/system/{{ app_name }}.service"
        owner: root
        group: root
        mode: '0644'
      notify:
        - reload systemd
        - restart app
      tags: [service, systemd]
    
    - name: "Запуск и включение службы приложения"
      systemd:
        name: "{{ app_name }}"
        state: started
        enabled: yes
        daemon_reload: yes
      tags: [service]
    
    - name: "Запуск и включение Nginx"
      service:
        name: nginx
        state: started
        enabled: yes
      tags: [service, nginx]
    
    # ============================================
    # БЛОК 8: Настройка cron задач
    # ============================================
    
    - name: "Создание cron задачи для очистки логов"
      cron:
        name: "Clean {{ app_name }} logs"
        minute: "0"
        hour: "2"
        job: "find {{ log_dir }} -name '*.log' -mtime +30 -delete"
        user: "{{ app_user }}"
        state: present
      tags: [cron, maintenance]
    
    - name: "Создание cron задачи для резервного копирования"
      cron:
        name: "Backup {{ app_name }} database"
        minute: "0"
        hour: "3"
        weekday: "0"
        job: "{{ app_dir }}/bin/backup.sh"
        user: "{{ app_user }}"
        state: present
      tags: [cron, backup]
    
    # ============================================
    # БЛОК 9: Модификация конфигурационных файлов
    # ============================================
    
    - name: "Добавление строки в конфигурационный файл"
      lineinfile:
        path: "/etc/security/limits.conf"
        line: "{{ app_user }} soft nofile 65536"
        state: present
        backup: yes
      tags: [config, limits]
    
    - name: "Добавление блока конфигурации"
      blockinfile:
        path: "/etc/sysctl.conf"
        block: |
          # {{ app_name }} network tuning
          net.core.somaxconn = 1024
          net.ipv4.tcp_max_syn_backlog = 2048
        marker: "# {mark} ANSIBLE MANAGED BLOCK - {{ app_name }}"
        backup: yes
      notify: reload sysctl
      tags: [config, network]
    
    # ============================================
    # БЛОК 10: Проверка и вывод информации
    # ============================================
    
    - name: "Проверка версии установленных пакетов"
      shell: |
        echo "Nginx: $(nginx -v 2>&1 | head -1)"
        echo "Python: $(python3 --version)"
        echo "Git: $(git --version)"
      register: versions
      changed_when: false
      tags: [verify, info]
    
    - name: "Вывод версий пакетов"
      debug:
        msg: "{{ versions.stdout_lines }}"
      tags: [verify, info]
    
    - name: "Проверка статуса служб"
      command: "systemctl is-active {{ item }}"
      loop:
        - nginx
        - "{{ app_name }}"
      register: service_status
      changed_when: false
      failed_when: false
      tags: [verify, service]
    
    - name: "Вывод статуса служб"
      debug:
        msg: "{{ item.item }}: {{ 'активна' if item.rc == 0 else 'неактивна' }}"
      loop: "{{ service_status.results }}"
      tags: [verify, service]
    
    - name: "Вывод системной информации"
      debug:
        msg: |
          ========================================
          Система: {{ ansible_distribution }} {{ ansible_distribution_version }}
          Архитектура: {{ ansible_architecture }}
          Hostname: {{ ansible_hostname }}
          IP адрес: {{ ansible_default_ipv4.address | default('N/A') }}
          Процессор: {{ ansible_processor[2] | default('N/A') }}
          Память: {{ ansible_memtotal_mb }} MB
          Диски: {{ ansible_devices.keys() | list }}
          ========================================
          Приложение: {{ app_name }} v{{ app_version }}
          Директория: {{ app_dir }}
          Пользователь: {{ app_user }}
          Порт: {{ app_port }}
          ========================================
      tags: [verify, info]
    
    # ============================================
    # БЛОК 11: HTTP проверки
    # ============================================
    
    - name: "Проверка доступности приложения"
      uri:
        url: "http://{{ ansible_default_ipv4.address }}:{{ app_port }}/health"
        method: GET
        status_code: 200
        return_content: yes
      register: health_check
      until: health_check.status == 200
      retries: 5
      delay: 10
      tags: [verify, health]
    
    - name: "Загрузка файла с удаленного сервера"
      get_url:
        url: "https://example.com/data/config.json"
        dest: "{{ app_dir }}/config/remote_config.json"
        mode: '0644'
        owner: "{{ app_user }}"
        group: "{{ app_group }}"
        validate_certs: yes
      when: download_config | default(false)
      tags: [config, download]
  
  # ============================================
  # HANDLERS
  # ============================================
  
  handlers:
    - name: reload nginx
      service:
        name: nginx
        state: reloaded
    
    - name: restart nginx
      service:
        name: nginx
        state: restarted
    
    - name: reload systemd
      systemd:
        daemon_reload: yes
    
    - name: restart app
      systemd:
        name: "{{ app_name }}"
        state: restarted
    
    - name: reload sysctl
      command: sysctl -p
```

### Шаблон Nginx: `templates/nginx.conf.j2`

```jinja
# Nginx configuration for {{ app_name }}
# Generated by Ansible on {{ ansible_date_time.iso8601 }}

upstream {{ app_name }}_backend {
    server 127.0.0.1:{{ app_port }} fail_timeout=0;
}

server {
    listen 80;
    server_name {{ ansible_hostname }} {{ ansible_default_ipv4.address }};
    
    # Логи
    access_log {{ log_dir }}/nginx_access.log;
    error_log {{ log_dir }}/nginx_error.log;
    
    # Максимальный размер загружаемых файлов
    client_max_body_size 100M;
    
    # Статические файлы
    location /static/ {
        alias {{ app_dir }}/public/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias {{ app_dir }}/public/media/;
        expires 30d;
    }
    
    # Проксирование на приложение
    location / {
        proxy_pass http://{{ app_name }}_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Таймауты
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://{{ app_name }}_backend/health;
        access_log off;
    }
}

{% if ssl_enabled | default(false) %}
server {
    listen 443 ssl http2;
    server_name {{ ansible_hostname }};
    
    ssl_certificate /etc/nginx/ssl/{{ app_name }}.pem;
    ssl_certificate_key /etc/nginx/ssl/{{ app_name }}.key;
    
    # Остальная конфигурация аналогична...
}
{% endif %}
```

### Шаблон systemd службы: `templates/app.service.j2`

```ini
[Unit]
Description={{ app_name }} Application Service
After=network.target postgresql.service

[Service]
Type=notify
User={{ app_user }}
Group={{ app_group }}
WorkingDirectory={{ app_dir }}/source
Environment="PATH={{ app_dir }}/venv/bin"
EnvironmentFile={{ app_dir }}/config/.env
ExecStart={{ app_dir }}/venv/bin/gunicorn \
    --workers 4 \
    --bind 0.0.0.0:{{ app_port }} \
    --access-logfile {{ log_dir }}/access.log \
    --error-logfile {{ log_dir }}/error.log \
    --timeout 120 \
    app:application

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## Примеры использования модулей

### 1. Модуль copy

```yaml
# Простое копирование
- name: "Копирование файла"
  copy:
    src: /local/path/file.txt
    dest: /remote/path/file.txt
    owner: user
    group: group
    mode: '0644'

# Копирование с содержимым
- name: "Создание файла с содержимым"
  copy:
    content: |
      Line 1
      Line 2
    dest: /path/to/file.txt
    
# Копирование с резервной копией
- name: "Копирование с бэкапом"
  copy:
    src: config.conf
    dest: /etc/app/config.conf
    backup: yes
```

### 2. Модуль template

```yaml
- name: "Создание конфига из шаблона"
  template:
    src: config.j2
    dest: /etc/app/config.conf
    validate: 'app --test-config %s'
    
# Шаблон config.j2
# Server: {{ ansible_hostname }}
# Port: {{ app_port }}
# {% for host in groups['webservers'] %}
# Backend: {{ host }}
# {% endfor %}
```

### 3. Модуль file

```yaml
# Создание директории
- name: "Создать директорию"
  file:
    path: /opt/app/data
    state: directory
    mode: '0755'

# Создание симлинка
- name: "Создать символическую ссылку"
  file:
    src: /opt/app/v2
    dest: /opt/app/current
    state: link

# Удаление файла
- name: "Удалить файл"
  file:
    path: /tmp/old_file
    state: absent

# Touch файл
- name: "Обновить timestamp"
  file:
    path: /var/log/app.log
    state: touch
```

### 4. Модуль package / apt / yum

```yaml
# Универсальный package
- name: "Установка пакетов"
  package:
    name:
      - nginx
      - git
    state: present

# APT (Debian/Ubuntu)
- name: "Обновление и установка (APT)"
  apt:
    name: nginx
    state: latest
    update_cache: yes
    cache_valid_time: 3600

# YUM/DNF (RHEL/CentOS)
- name: "Установка группы пакетов"
  yum:
    name: "@Development Tools"
    state: present

# Zypper (openSUSE)
- name: "Установка пакетов (openSUSE)"
  community.general.zypper:
    name: nginx
    state: present

- name: "Обновление всех пакетов (openSUSE)"
  community.general.zypper:
    name: '*'
    state: latest
```

### 5. Модуль service / systemd

```yaml
# Service
- name: "Запуск службы"
  service:
    name: nginx
    state: started
    enabled: yes

# Systemd
- name: "Управление systemd"
  systemd:
    name: myapp
    state: restarted
    daemon_reload: yes
    enabled: yes
```

### 6. Модуль user / group

```yaml
# Создание пользователя
- name: "Создать пользователя"
  user:
    name: appuser
    uid: 1001
    group: appgroup
    groups: sudo,docker
    shell: /bin/bash
    create_home: yes
    password: "{{ 'mypassword' | password_hash('sha512') }}"

# Создание группы
- name: "Создать группу"
  group:
    name: appgroup
    gid: 1001
    state: present
```

### 7. Модуль command / shell

```yaml
# Command (безопаснее)
- name: "Выполнить команду"
  command: cat /etc/passwd
  register: result
  changed_when: false

# Shell (с pipe, redirect)
- name: "Сложная команда"
  shell: |
    ps aux | grep nginx | wc -l
  register: nginx_count

# С условиями
- name: "Команда с условием"
  command: /opt/app/install.sh
  args:
    creates: /opt/app/.installed
```

### 8. Модуль git

```yaml
- name: "Клонировать репозиторий"
  git:
    repo: 'https://github.com/user/repo.git'
    dest: /opt/app
    version: main
    force: yes
    depth: 1
```

### 9. Модуль uri

```yaml
# GET запрос
- name: "Проверка API"
  uri:
    url: http://api.example.com/status
    method: GET
    return_content: yes
  register: api_response

# POST запрос
- name: "Отправка данных"
  uri:
    url: http://api.example.com/data
    method: POST
    body_format: json
    body:
      key: value
    status_code: 201
```

### 10. Модуль lineinfile / blockinfile

```yaml
# Изменение строки
- name: "Изменить параметр в файле"
  lineinfile:
    path: /etc/config.conf
    regexp: '^Port='
    line: 'Port=8080'
    backup: yes

# Добавление блока
- name: "Добавить блок конфигурации"
  blockinfile:
    path: /etc/hosts
    block: |
      192.168.1.10 server1
      192.168.1.11 server2
    marker: "# {mark} ANSIBLE MANAGED BLOCK"
```

---

## Выполнение и отладка playbook

### Основные команды

```bash
# Проверка синтаксиса
ansible-playbook playbook.yml --syntax-check

# Dry run (не применять изменения)
ansible-playbook playbook.yml --check

# Dry run с показом diff
ansible-playbook playbook.yml --check --diff

# Выполнение playbook
ansible-playbook playbook.yml

# С подробным выводом
ansible-playbook playbook.yml -v    # verbose
ansible-playbook playbook.yml -vv   # more verbose
ansible-playbook playbook.yml -vvv  # debug
ansible-playbook playbook.yml -vvvv # connection debug
```

### Работа с тегами

```bash
# Выполнить только определенные теги
ansible-playbook playbook.yml --tags "install,config"

# Пропустить определенные теги
ansible-playbook playbook.yml --skip-tags "deploy"

# Список всех тегов
ansible-playbook playbook.yml --list-tags

# Список всех задач
ansible-playbook playbook.yml --list-tasks
```

### Работа с хостами

```bash
# Ограничить выполнение определенными хостами
ansible-playbook playbook.yml --limit "webserver1,webserver2"

# Ограничить группой
ansible-playbook playbook.yml --limit "webservers"

# Список хостов, на которых будет выполнен playbook
ansible-playbook playbook.yml --list-hosts
```

### Передача переменных

```bash
# Передать переменные через командную строку
ansible-playbook playbook.yml -e "app_version=2.0.0"
ansible-playbook playbook.yml -e "app_port=9000 debug_mode=true"

# Передать переменные из JSON
ansible-playbook playbook.yml -e '{"app_port": 9000, "debug": true}'

# Из файла переменных
ansible-playbook playbook.yml -e @vars/production.yml
```

### Пошаговое выполнение

```bash
# Пошаговое выполнение с подтверждением
ansible-playbook playbook.yml --step

# Начать с определенной задачи
ansible-playbook playbook.yml --start-at-task="Установка Nginx"
```

### Отладка

```bash
# Проверка с выводом изменений
ansible-playbook playbook.yml --check --diff

# Детальный вывод переменных
ansible-playbook playbook.yml -vvv | grep -A 10 "TASK"

# Сохранить вывод в файл
ansible-playbook playbook.yml | tee playbook_run.log
```

---

## Полный справочник модулей

### Модули ansible.builtin (Core)

#### Управление файлами

| Модуль | Описание |
|--------|----------|
| `assemble` | Собрать конфигурацию из фрагментов |
| `blockinfile` | Вставить/обновить/удалить блок текста |
| `copy` | Копировать файлы на удаленные хосты |
| `fetch` | Получить файлы с удаленных хостов |
| `file` | Управление файлами и их свойствами |
| `find` | Найти файлы по критериям |
| `lineinfile` | Управление строками в файлах |
| `replace` | Заменить текст в файле по regex |
| `stat` | Получить информацию о файле |
| `template` | Обработать Jinja2 шаблон |
| `unarchive` | Распаковать архив |

#### Управление пакетами

| Модуль | Описание |
|--------|----------|
| `package` | Универсальный менеджер пакетов |
| `apt` | Управление пакетами Debian/Ubuntu |
| `apt_key` | Управление APT ключами |
| `apt_repository` | Управление APT репозиториями |
| `dnf` | Управление пакетами (новый YUM) |
| `yum` | Управление пакетами RHEL/CentOS |
| `yum_repository` | Управление YUM репозиториями |
| `rpm_key` | Управление RPM ключами |
| `pip` | Управление Python пакетами |
| `gem` | Управление Ruby Gems |
| `npm` | Управление Node.js пакетами |

#### Управление службами

| Модуль | Описание |
|--------|----------|
| `service` | Управление системными службами |
| `systemd` | Управление systemd службами |
| `sysvinit` | Управление SysV init скриптами |
| `cron` | Управление cron задачами |
| `at` | Планирование одноразовых задач |

#### Выполнение команд

| Модуль | Описание |
|--------|----------|
| `command` | Выполнение команд на хостах |
| `shell` | Выполнение через shell |
| `script` | Выполнение локального скрипта |
| `raw` | Выполнение без Python |
| `expect` | Выполнение команд с интерактивным вводом |

#### Управление пользователями

| Модуль | Описание |
|--------|----------|
| `user` | Управление пользователями |
| `group` | Управление группами |
| `authorized_key` | Управление SSH authorized_keys |
| `known_hosts` | Управление SSH known_hosts |
| `pamd` | Управление PAM |

#### Работа с сетью

| Модуль | Описание |
|--------|----------|
| `uri` | Взаимодействие с веб-сервисами |
| `get_url` | Загрузка файлов по URL |
| `slurp` | Чтение файла с удаленного хоста |
| `wait_for` | Ожидание условия |
| `wait_for_connection` | Ожидание подключения |

#### Работа с Git

| Модуль | Описание |
|--------|----------|
| `git` | Управление git репозиториями |
| `git_config` | Настройка git конфигурации |
| `github_key` | Управление SSH ключами GitHub |
| `github_webhook` | Управление GitHub webhooks |

#### Системные модули

| Модуль | Описание |
|--------|----------|
| `setup` | Сбор фактов о системе |
| `gather_facts` | Явный сбор фактов |
| `hostname` | Управление hostname |
| `reboot` | Перезагрузка системы |
| `sysctl` | Управление sysctl параметрами |
| `timezone` | Настройка timezone |
| `mount` | Управление точками монтирования |
| `lvg` | Управление LVM Volume Groups |
| `lvol` | Управление LVM Logical Volumes |
| `filesystem` | Создание файловых систем |

#### Управление playbook

| Модуль | Описание |
|--------|----------|
| `debug` | Вывод отладочной информации |
| `assert` | Проверка условий |
| `fail` | Принудительный fail задачи |
| `meta` | Выполнение meta задач |
| `pause` | Пауза выполнения |
| `set_fact` | Установка переменных фактов |
| `set_stats` | Установка статистики |
| `add_host` | Добавление хоста в runtime |
| `group_by` | Группировка хостов |
| `include_vars` | Загрузка переменных |
| `import_playbook` | Импорт другого playbook |
| `import_tasks` | Импорт задач |
| `include_tasks` | Динамическое включение задач |
| `import_role` | Импорт роли |
| `include_role` | Динамическое включение роли |

#### База данных

| Модуль | Описание |
|--------|----------|
| `mysql_db` | Управление MySQL/MariaDB базами |
| `mysql_user` | Управление MySQL пользователями |
| `postgresql_db` | Управление PostgreSQL базами |
| `postgresql_user` | Управление PostgreSQL пользователями |
| `mongodb_user` | Управление MongoDB пользователями |

### Дополнительные коллекции модулей

#### community.general

Более 700+ модулей для различных задач:
- Облачные провайдеры (DigitalOcean, Linode, Hetzner)
- Системы мониторинга (Nagios, Zabbix, Datadog)
- Уведомления (Slack, Telegram, Mail)
- Различные базы данных
- Системы управления конфигурацией

```bash
# Установка
ansible-galaxy collection install community.general

# Использование в playbook
- name: Manage zypper package (openSUSE)
  community.general.zypper:
    name: nginx
    state: present
```

#### community.docker

```bash
# Установка
ansible-galaxy collection install community.docker
```

Модули для работы с Docker:
- `docker_container` - управление контейнерами
- `docker_image` - управление образами
- `docker_network` - управление сетями
- `docker_volume` - управление томами
- `docker_compose` - работа с docker-compose
- `docker_swarm` - управление Docker Swarm

```yaml
# Пример использования
- name: Manage Docker container
  community.docker.docker_container:
    name: web
    image: nginx:latest
    state: started
    ports:
      - "80:80"
```

#### ansible.posix

```bash
# Установка
ansible-galaxy collection install ansible.posix
```

Модули для POSIX систем:
- `acl` - управление ACL
- `firewalld` - управление firewalld
- `selinux` - настройка SELinux
- `sysctl` - управление sysctl
- `mount` - управление точками монтирования
- `authorized_key` - SSH ключи
- `at` - планирование задач

```yaml
# Пример использования
- name: Configure firewalld
  ansible.posix.firewalld:
    service: http
    permanent: yes
    state: enabled
```

#### amazon.aws

```bash
# Установка
ansible-galaxy collection install amazon.aws
```

Модули для AWS:
- `ec2_instance` - управление EC2 инстансами
- `s3_bucket` - управление S3 бакетами
- `rds_instance` - управление RDS
- `cloudformation` - работа с CloudFormation
- `route53` - управление DNS
- `iam_role` - управление IAM ролями

```yaml
# Пример использования
- name: Create EC2 instance
  amazon.aws.ec2_instance:
    name: webserver
    instance_type: t2.micro
    image_id: ami-12345678
    state: running
```

#### azure.azcollection

```bash
# Установка
ansible-galaxy collection install azure.azcollection
```

Модули для Azure:
- `azure_rm_virtualmachine` - управление VM
- `azure_rm_storageaccount` - управление Storage
- `azure_rm_resourcegroup` - управление Resource Groups
- `azure_rm_networksecuritygroup` - управление NSG

```yaml
# Пример использования
- name: Create Azure VM
  azure.azcollection.azure_rm_virtualmachine:
    resource_group: myResourceGroup
    name: myVM
    vm_size: Standard_B1s
```

#### google.cloud

```bash
# Установка
ansible-galaxy collection install google.cloud
```

Модули для Google Cloud:
- `gcp_compute_instance` - управление GCE
- `gcp_storage_bucket` - управление Cloud Storage
- `gcp_sql_instance` - управление Cloud SQL
- `gcp_container_cluster` - управление GKE

```yaml
# Пример использования
- name: Create GCE instance
  google.cloud.gcp_compute_instance:
    name: test-instance
    machine_type: n1-standard-1
    zone: us-central1-a
    state: present
```

#### kubernetes.core

```bash
# Установка
ansible-galaxy collection install kubernetes.core
```

Модули для Kubernetes:
- `k8s` - управление Kubernetes ресурсами
- `helm` - управление Helm charts
- `k8s_info` - получение информации
- `k8s_exec` - выполнение команд в pod

```yaml
# Пример использования
- name: Deploy Kubernetes resource
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Pod
      metadata:
        name: nginx
      spec:
        containers:
          - name: nginx
            image: nginx:latest
```

### Категории модулей по функционалу

**Cloud (Облачные)**
- AWS, Azure, GCP, DigitalOcean, Linode, Vultr, Hetzner

**Network (Сетевые)**
- Cisco, Juniper, Arista, F5, Palo Alto, pfSense

**Monitoring (Мониторинг)**
- Prometheus, Grafana, Zabbix, Nagios, Datadog

**Notification (Уведомления)**
- Slack, Telegram, Discord, Email, PagerDuty

**Storage (Хранилища)**
- NetApp, Pure Storage, Dell EMC, Synology

**Virtualization (Виртуализация)**
- VMware, Proxmox, KVM, VirtualBox, Vagrant

**Container (Контейнеры)**
- Docker, Kubernetes, Podman, LXC

**CI/CD**
- Jenkins, GitLab CI, GitHub Actions, Azure DevOps

### Установка и использование коллекций

#### Поиск коллекций

```bash
# Поиск коллекции в Ansible Galaxy
ansible-galaxy collection list

# Поиск коллекции онлайн
ansible-galaxy collection search docker

# Просмотр информации о коллекции
ansible-galaxy collection info community.docker
```

#### Установка коллекций

```bash
# Установка из Ansible Galaxy
ansible-galaxy collection install community.general

# Установка конкретной версии
ansible-galaxy collection install community.docker:3.4.0

# Установка из requirements.yml
ansible-galaxy collection install -r requirements.yml

# Установка в конкретную директорию
ansible-galaxy collection install community.general -p ./collections
```

#### Файл requirements.yml

```yaml
---
collections:
  # Установка из Galaxy
  - name: community.general
    version: ">=1.0.0"
  
  - name: community.docker
    version: "3.4.0"
  
  - name: ansible.posix
  
  # Установка из Git репозитория
  - name: https://github.com/organization/collection_repo.git
    type: git
    version: main
  
  # Установка из tar.gz файла
  - name: /path/to/collection.tar.gz
    type: file
```

#### Использование коллекций в playbook

```yaml
---
# Способ 1: Указание collections в начале playbook
- name: Example playbook
  hosts: all
  collections:
    - community.general
    - community.docker
  
  tasks:
    - name: Install package using community.general
      pacman:
        name: nginx
        state: present
    
    - name: Manage docker container
      docker_container:
        name: web
        image: nginx

# Способ 2: Использование FQCN (Fully Qualified Collection Name)
- name: Example with FQCN
  hosts: all
  
  tasks:
    - name: Install package
      community.general.pacman:
        name: nginx
        state: present
    
    - name: Manage docker
      community.docker.docker_container:
        name: web
        image: nginx
```

#### Настройка путей к коллекциям

```ini
# ansible.cfg
[defaults]
collections_paths = ~/.ansible/collections:/usr/share/ansible/collections:./collections

# Или через переменную окружения
export ANSIBLE_COLLECTIONS_PATHS=~/.ansible/collections:/usr/share/ansible/collections
```

#### Создание собственной коллекции

```bash
# Инициализация структуры коллекции
ansible-galaxy collection init my_namespace.my_collection

# Структура коллекции
my_namespace/
  my_collection/
    ├── README.md
    ├── galaxy.yml              # Метаданные коллекции
    ├── plugins/
    │   ├── modules/            # Кастомные модули
    │   ├── inventory/          # Inventory плагины
    │   └── lookup/             # Lookup плагины
    ├── roles/                  # Роли
    └── playbooks/              # Playbooks

# Сборка коллекции
ansible-galaxy collection build

# Публикация в Galaxy
ansible-galaxy collection publish my_namespace-my_collection-1.0.0.tar.gz --api-key=YOUR_KEY
```

