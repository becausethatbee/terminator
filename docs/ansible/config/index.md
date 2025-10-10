# Deployment Node.js + Express через Ansible

Автоматизация установки Node.js и развертывания Express приложения на Debian 12 с использованием Ansible.

---

## Создание пользователя

Добавление пользователя с привилегиями sudo:

```bash
sudo adduser <SSH_USER>
sudo usermod -aG sudo <SSH_USER>
```

| Команда | Назначение |
|---------|------------|
| adduser | Создание пользователя |
| usermod -aG sudo | Добавление в группу sudo |

---

## Настройка SSH

Генерация ключа:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/<PRIVATE_KEY_FILE>
```

Копирование публичного ключа:

```bash
ssh-copy-id -i ~/.ssh/<PRIVATE_KEY_FILE>.pub <SSH_USER>@<SERVER_IP>
```

| Команда | Назначение |
|---------|------------|
| ssh-keygen | Генерация SSH-ключа |
| ssh-copy-id | Копирование публичного ключа на сервер |

---

## Структура проекта

Создание директорий:

```bash
mkdir -p ~/ansible_project
cd ~/ansible_project
```

| Команда | Назначение |
|---------|------------|
| mkdir -p | Создание каталога с родительскими |
| cd | Переход в каталог |

---

## Inventory

Файл `inventory.yml`:

```yaml
all:
  hosts:
    <SERVER_NAME>:
      ansible_host: <SERVER_IP>
      ansible_user: <SSH_USER>
      ansible_ssh_private_key_file: ~/.ssh/<PRIVATE_KEY_FILE>
```

| Параметр | Назначение |
|----------|------------|
| ansible_host | IP-адрес или DNS сервера |
| ansible_user | SSH-пользователь |
| ansible_ssh_private_key_file | Путь к приватному ключу |

---

## Playbook

Файл `install_node_express.yml`:

```yaml
---
- name: Install Node.js and Express app
  hosts: <SERVER_NAME>
  become: yes
  vars:
    node_version: "18.x"
    app_dir: "/home/<SSH_USER>/express_app"

  tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: yes

    - name: Install dependencies
      ansible.builtin.apt:
        name:
          - curl
          - build-essential
        state: present

    - name: Add NodeSource repo
      ansible.builtin.shell: curl -fsSL https://deb.nodesource.com/setup_{{ node_version }} | bash -
      args:
        executable: /bin/bash

    - name: Install Node.js
      ansible.builtin.apt:
        name: nodejs
        state: present

    - name: Create app directory
      ansible.builtin.file:
        path: "{{ app_dir }}"
        state: directory
        owner: "<SSH_USER>"
        group: "<SSH_USER>"

    - name: Initialize npm project
      community.general.npm:
        path: "{{ app_dir }}"
        state: present

    - name: Install Express
      community.general.npm:
        name: express
        path: "{{ app_dir }}"
        state: present

    - name: Create Express server
      ansible.builtin.copy:
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
      community.general.npm:
        name: pm2
        global: yes

    - name: Start Express app with PM2
      ansible.builtin.shell: pm2 start {{ app_dir }}/server.js --name express_app
      args:
        executable: /bin/bash

    - name: Save PM2 process list
      ansible.builtin.shell: pm2 save
      args:
        executable: /bin/bash
```

| Параметр | Назначение |
|----------|------------|
| hosts | Целевая группа серверов |
| become | Эскалация привилегий |
| node_version | Версия Node.js |
| app_dir | Директория приложения |
| tasks | Список задач playbook |

---

## Выполнение

Проверка соединения:

```bash
ansible all -i inventory.yml -m ping
```

Запуск playbook:

```bash
ansible-playbook -i inventory.yml install_node_express.yml
```

| Команда | Назначение |
|---------|------------|
| ansible all -m ping | Проверка доступности хостов |
| ansible-playbook | Запуск playbook |

---

## Переменные

| Переменная | Назначение |
|------------|------------|
| <SERVER_NAME> | Имя хоста для playbook |
| <SERVER_IP> | IP-адрес или DNS сервера |
| <SSH_USER> | SSH-пользователь |
| <PRIVATE_KEY_FILE> | Приватный SSH-ключ |
| node_version | Версия Node.js |
| app_dir | Директория приложения Express |
