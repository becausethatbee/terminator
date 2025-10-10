# Ansible Playbooks: Популярные модули

Справочник по использованию наиболее востребованных модулей Ansible для автоматизации инфраструктуры.

## Категории модулей

### Управление файлами
- `copy` - копирование файлов
- `template` - обработка Jinja2 шаблонов
- `file` - управление файлами и директориями
- `lineinfile` - изменение строк
- `blockinfile` - управление блоками текста

### Управление пакетами
- `package` - универсальный менеджер
- `apt` - Debian/Ubuntu
- `yum/dnf` - RHEL/CentOS
- `pip` - Python пакеты
- `npm` - Node.js пакеты

### Управление службами
- `service` - управление службами
- `systemd` - расширенное управление systemd
- `cron` - управление cron задачами

### Управление пользователями
- `user` - создание и управление пользователями
- `group` - управление группами
- `authorized_key` - SSH ключи

### Выполнение команд
- `command` - выполнение команд
- `shell` - выполнение через shell
- `script` - выполнение локальных скриптов
- `raw` - выполнение без Python

### Работа с сетью
- `uri` - HTTP запросы
- `get_url` - загрузка файлов
- `git` - работа с Git репозиториями

---

## Структура Playbook

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
    # Задачи
    
  handlers:
    # Handlers
```

---

## Управление пакетами

### Обновление кэша

```yaml
- name: Update cache (Debian)
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 3600
  when: ansible_os_family == "Debian"

- name: Update cache (RHEL)
  ansible.builtin.yum:
    update_cache: yes
  when: ansible_os_family == "RedHat"

- name: Update cache (openSUSE)
  community.general.zypper:
    update_cache: yes
  when: ansible_os_family == "Suse"
```

### Установка пакетов

```yaml
- name: Install base packages
  ansible.builtin.package:
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
```

---

## Управление пользователями

```yaml
- name: Create app group
  ansible.builtin.group:
    name: "{{ app_group }}"
    state: present
    system: yes

- name: Create app user
  ansible.builtin.user:
    name: "{{ app_user }}"
    group: "{{ app_group }}"
    groups: "sudo"
    shell: /bin/bash
    create_home: yes
    home: "/home/{{ app_user }}"
    comment: "Application service user"
    state: present

- name: Add SSH key
  ansible.builtin.authorized_key:
    user: "{{ app_user }}"
    state: present
    key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```

---

## Управление файлами

### Создание директорий

```yaml
- name: Create app directories
  ansible.builtin.file:
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

- name: Create symlink
  ansible.builtin.file:
    src: "{{ log_dir }}"
    dest: "{{ app_dir }}/logs"
    state: link
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
```

### Копирование файлов

```yaml
- name: Copy config file
  ansible.builtin.copy:
    content: |
      APP_NAME={{ app_name }}
      APP_VERSION={{ app_version }}
      APP_ENV=production
      APP_PORT={{ app_port }}
      LOG_LEVEL=info
    dest: "{{ app_dir }}/config/.env"
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    mode: '0600'
    backup: yes

- name: Copy SSL certificate
  ansible.builtin.copy:
    src: files/ssl_cert.pem
    dest: "/etc/nginx/ssl/{{ app_name }}.pem"
    owner: root
    group: root
    mode: '0644'
  when: ssl_enabled | default(false)
```

### Использование шаблонов

```yaml
- name: Create Nginx config
  ansible.builtin.template:
    src: templates/nginx.conf.j2
    dest: "/etc/nginx/sites-available/{{ app_name }}.conf"
    owner: root
    group: root
    mode: '0644'
    validate: 'nginx -t -c %s'
    backup: yes
  notify: reload nginx

- name: Enable Nginx config
  ansible.builtin.file:
    src: "/etc/nginx/sites-available/{{ app_name }}.conf"
    dest: "/etc/nginx/sites-enabled/{{ app_name }}.conf"
    state: link
  notify: reload nginx
```

---

## Git операции

```yaml
- name: Clone repository
  ansible.builtin.git:
    repo: "https://github.com/example/{{ app_name }}.git"
    dest: "{{ app_dir }}/source"
    version: "{{ app_version }}"
    force: yes
  become_user: "{{ app_user }}"
```

---

## Выполнение команд

```yaml
- name: Install Python dependencies
  ansible.builtin.pip:
    requirements: "{{ app_dir }}/source/requirements.txt"
    virtualenv: "{{ app_dir }}/venv"
    virtualenv_command: python3 -m venv
  become_user: "{{ app_user }}"

- name: Build static files
  ansible.builtin.shell: |
    source {{ app_dir }}/venv/bin/activate
    python manage.py collectstatic --noinput
  args:
    chdir: "{{ app_dir }}/source"
    executable: /bin/bash
  become_user: "{{ app_user }}"

- name: Run migrations
  ansible.builtin.command: "{{ app_dir }}/venv/bin/python manage.py migrate --noinput"
  args:
    chdir: "{{ app_dir }}/source"
  become_user: "{{ app_user }}"
  register: migration_result
  changed_when: "'No migrations to apply' not in migration_result.stdout"

- name: Execute local script
  ansible.builtin.script:
    cmd: scripts/post_deploy.sh
    chdir: "{{ app_dir }}"
  become_user: "{{ app_user }}"
```

---

## Systemd службы

```yaml
- name: Create systemd unit
  ansible.builtin.template:
    src: templates/app.service.j2
    dest: "/etc/systemd/system/{{ app_name }}.service"
    owner: root
    group: root
    mode: '0644'
  notify:
    - reload systemd
    - restart app

- name: Start and enable service
  ansible.builtin.systemd:
    name: "{{ app_name }}"
    state: started
    enabled: yes
    daemon_reload: yes

- name: Start Nginx
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: yes
```

---

## Cron задачи

```yaml
- name: Create cron for log cleanup
  ansible.builtin.cron:
    name: "Clean {{ app_name }} logs"
    minute: "0"
    hour: "2"
    job: "find {{ log_dir }} -name '*.log' -mtime +30 -delete"
    user: "{{ app_user }}"
    state: present

- name: Create backup cron
  ansible.builtin.cron:
    name: "Backup {{ app_name }} database"
    minute: "0"
    hour: "3"
    weekday: "0"
    job: "{{ app_dir }}/bin/backup.sh"
    user: "{{ app_user }}"
    state: present
```

---

## Модификация файлов

```yaml
- name: Add line to limits.conf
  ansible.builtin.lineinfile:
    path: "/etc/security/limits.conf"
    line: "{{ app_user }} soft nofile 65536"
    state: present
    backup: yes

- name: Add config block
  ansible.builtin.blockinfile:
    path: "/etc/sysctl.conf"
    block: |
      # {{ app_name }} network tuning
      net.core.somaxconn = 1024
      net.ipv4.tcp_max_syn_backlog = 2048
    marker: "# {mark} ANSIBLE MANAGED BLOCK - {{ app_name }}"
    backup: yes
  notify: reload sysctl
```

---

## Проверка и отладка

```yaml
- name: Check package versions
  ansible.builtin.shell: |
    echo "Nginx: $(nginx -v 2>&1 | head -1)"
    echo "Python: $(python3 --version)"
    echo "Git: $(git --version)"
  register: versions
  changed_when: false

- name: Display versions
  ansible.builtin.debug:
    msg: "{{ versions.stdout_lines }}"

- name: Check service status
  ansible.builtin.command: "systemctl is-active {{ item }}"
  loop:
    - nginx
    - "{{ app_name }}"
  register: service_status
  changed_when: false
  failed_when: false

- name: Display service status
  ansible.builtin.debug:
    msg: "{{ item.item }}: {{ 'активна' if item.rc == 0 else 'неактивна' }}"
  loop: "{{ service_status.results }}"
```

---

## HTTP проверки

```yaml
- name: Check app availability
  ansible.builtin.uri:
    url: "http://{{ ansible_default_ipv4.address }}:{{ app_port }}/health"
    method: GET
    status_code: 200
    return_content: yes
  register: health_check
  until: health_check.status == 200
  retries: 5
  delay: 10

- name: Download remote file
  ansible.builtin.get_url:
    url: "https://example.com/data/config.json"
    dest: "{{ app_dir }}/config/remote_config.json"
    mode: '0644'
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    validate_certs: yes
  when: download_config | default(false)
```

---

## Handlers

```yaml
handlers:
  - name: reload nginx
    ansible.builtin.service:
      name: nginx
      state: reloaded
  
  - name: restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted
  
  - name: reload systemd
    ansible.builtin.systemd:
      daemon_reload: yes
  
  - name: restart app
    ansible.builtin.systemd:
      name: "{{ app_name }}"
      state: restarted
  
  - name: reload sysctl
    ansible.builtin.command: sysctl -p
```

---

## Запуск Playbook

```bash
# Проверка синтаксиса
ansible-playbook playbook.yml --syntax-check

# Dry run
ansible-playbook playbook.yml --check

# Dry run с diff
ansible-playbook playbook.yml --check --diff

# Выполнение
ansible-playbook playbook.yml

# С verbose
ansible-playbook playbook.yml -v
ansible-playbook playbook.yml -vv
ansible-playbook playbook.yml -vvv

# С тегами
ansible-playbook playbook.yml --tags "install,config"

# Пропустить теги
ansible-playbook playbook.yml --skip-tags "deploy"

# Список тегов
ansible-playbook playbook.yml --list-tags

# Ограничить хосты
ansible-playbook playbook.yml --limit "webserver1,webserver2"

# Передать переменные
ansible-playbook playbook.yml -e "app_version=2.0.0"

# Пошаговое выполнение
ansible-playbook playbook.yml --step
```

---

## Справочник модулей

### Core модули (ansible.builtin)

| Модуль | Назначение |
|--------|----------|
| `copy` | Копирование файлов |
| `template` | Обработка шаблонов |
| `file` | Управление файлами |
| `lineinfile` | Управление строками |
| `blockinfile` | Управление блоками |
| `apt` | Управление APT |
| `yum` | Управление YUM |
| `dnf` | Управление DNF |
| `pip` | Управление pip |
| `npm` | Управление npm |
| `service` | Управление службами |
| `systemd` | Управление systemd |
| `cron` | Управление cron |
| `user` | Управление пользователями |
| `group` | Управление группами |
| `authorized_key` | SSH ключи |
| `command` | Выполнение команд |
| `shell` | Shell команды |
| `script` | Локальные скрипты |
| `raw` | Выполнение без Python |
| `uri` | HTTP запросы |
| `get_url` | Загрузка файлов |
| `git` | Git операции |
| `setup` | Сбор фактов |
| `debug` | Отладка |
| `assert` | Проверка условий |
| `fail` | Принудительный fail |

### Коллекции

#### community.general

```bash
ansible-galaxy collection install community.general
```

#### community.docker

```bash
ansible-galaxy collection install community.docker
```

#### ansible.posix

```bash
ansible-galaxy collection install ansible.posix
```
