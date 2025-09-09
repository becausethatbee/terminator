# Руководство по установке Node.js + Express на Debian 12 с использованием Ansible

---

## Шаг 1. Создание пользователя и предоставление привилегий sudo

```bash
sudo adduser <SSH_USER>
sudo usermod -aG sudo <SSH_USER>
```

| Команда | Назначение |
|---------|------------|
| adduser <SSH_USER> | Создает нового пользователя на сервере |
| usermod -aG sudo <SSH_USER> | Добавляет пользователя в группу sudo для выполнения команд с правами администратора |

> `<SSH_USER>` — переменная, которую следует заменить на имя пользователя.

---

## Шаг 2. Генерация SSH-ключа и настройка безпарольного доступа

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/<PRIVATE_KEY_FILE>
ssh-copy-id -i ~/.ssh/<PRIVATE_KEY_FILE>.pub <SSH_USER>@<SERVER_IP>
```

| Команда | Назначение |
|---------|------------|
| ssh-keygen | Генерация нового SSH-ключа |
| ssh-copy-id | Копирование публичного ключа на сервер для безпарольного подключения |

> `<PRIVATE_KEY_FILE>` — имя файла ключа; `<SERVER_IP>` — IP или DNS сервера.

---

## Шаг 3. Создание каталога проекта и файла инвентаря

```bash
mkdir -p ~/ansible_project
cd ~/ansible_project
```

| Команда | Назначение |
|---------|------------|
| mkdir -p ~/ansible_project | Создает каталог для проекта Ansible |
| cd ~/ansible_project | Переход в каталог проекта |

### Инвентарь inventory.yml

```yaml
all:
  hosts:
    <SERVER_NAME>:
      ansible_host: <SERVER_IP>
      ansible_user: <SSH_USER>
      ansible_ssh_private_key_file: ~/.ssh/<PRIVATE_KEY_FILE>
```

| Параметр | Назначение |
|-----------|------------|
| <SERVER_NAME> | Имя хоста в Ansible |
| ansible_host | IP-адрес или DNS сервера |
| ansible_user | SSH-пользователь |
| ansible_ssh_private_key_file | Путь к приватному ключу для подключения |

---

## Шаг 4. Создание playbook install_node_express.yml

### Полный файл для копирования и автоматического применения

```bash
cat > install_node_express.yml << 'EOF'
---
- name: Install Node.js and Express app
  hosts: <SERVER_NAME>
  become: yes
  vars:
    node_version: "18.x"
    app_dir: "/home/<SSH_USER>/express_app"

  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install dependencies
      apt:
        name:
          - curl
          - build-essential
        state: present

    - name: Add NodeSource repo
      shell: curl -fsSL https://deb.nodesource.com/setup_{{ node_version }} | bash -
      args:
        executable: /bin/bash

    - name: Install Node.js
      apt:
        name: nodejs
        state: present

    - name: Create app directory
      file:
        path: "{{ app_dir }}"
        state: directory
        owner: "<SSH_USER>"
        group: "<SSH_USER>"

    - name: Initialize npm project
      npm:
        path: "{{ app_dir }}"
        state: present

    - name: Install Express
      npm:
        name: express
        path: "{{ app_dir }}"
        state: present

    - name: Create Express server
      copy:
        dest: "{{ app_dir }}/server.js"
        content: |
          const express = require('express');
          const app = express();
          const PORT = 3000;

          app.get('/', (req, res) => {
              res.send('Hello from Express!');
          });

          app.listen(PORT, () => {
              console.log(`Server running on port ${PORT}`);
          });

    - name: Install PM2 globally
      npm:
        name: pm2
        global: yes

    - name: Start Express app with PM2
      shell: pm2 start {{ app_dir }}/server.js --name express_app
      args:
        executable: /bin/bash

    - name: Save PM2 process list
      shell: pm2 save
      args:
        executable: /bin/bash
EOF
```

| Параметр | Назначение |
|-----------|------------|
| hosts | Целевая группа серверов |
| become: yes | Выполнение задач с привилегиями sudo |
| node_version | Версия Node.js, устанавливаемая через NodeSource |
| app_dir | Путь к директории приложения Express |
| tasks | Список задач playbook |
| apt | Установка пакетов Debian/Ubuntu |
| shell | Выполнение shell-команд |
| file | Создание директорий и установка прав |
| npm | Установка Node.js пакетов |
| copy | Копирование файлов на сервер |
| PM2 | Менеджер процессов Node.js |

---

## Шаг 5. Проверка соединения и запуск playbook

```bash
ansible all -i inventory.yml -m ping
ansible-playbook -i inventory.yml install_node_express.yml
```

| Команда | Назначение |
|---------|------------|
| ansible all -i inventory.yml -m ping | Проверка доступности всех хостов из инвентаря |
| ansible-playbook -i inventory.yml install_node_express.yml | Запуск playbook для установки Node.js и Express |

---

## Пояснения к переменным Ansible

| Переменная | Назначение |
|------------|------------|
| <SERVER_NAME> | Имя хоста для playbook |
| <SERVER_IP> | IP-адрес или DNS сервера |
| <SSH_USER> | SSH-пользователь для подключения |
| <PRIVATE_KEY_FILE> | Приватный SSH-ключ для безпарольного подключения |
| node_version | Версия Node.js, устанавливаемая через NodeSource |
| app_dir | Директория приложения Express |
