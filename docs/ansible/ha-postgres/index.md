# Развертывание HA кластера PostgreSQL

Руководство по развертыванию высокодоступного кластера PostgreSQL с использованием Patroni и etcd через Ansible.

---

## Требования

### Инфраструктура

| Параметр | Значение |
|----------|----------|
| CPU | 1 core |
| RAM | 2 GB |
| Disk | 20 GB |
| OS | Debian 13 (Trixie) |
| Количество нод | 3 |

### Сетевые порты

| Порт | Назначение |
|------|-----------|
| 2379/tcp | etcd client API |
| 2380/tcp | etcd peer communication |
| 5432/tcp | PostgreSQL |
| 8008/tcp | Patroni REST API |

### Доступы

- SSH ключи настроены для всех нод
- Пользователь с sudo правами без пароля
- Доступ к интернету для установки пакетов

---

## Подготовка SSH доступа

### Конвертация SSH ключа

При использовании PuTTY ключа (.ppk) выполнить конвертацию в формат OpenSSH:

```bash
sudo apt install putty-tools
puttygen your-key.ppk -O private-openssh -o ~/.ssh/cluster_key
chmod 600 ~/.ssh/cluster_key
```

### Проверка подключения

```bash
ssh -i ~/.ssh/cluster_key <USER>@<NODE1_IP> 'hostname'
ssh -i ~/.ssh/cluster_key <USER>@<NODE2_IP> 'hostname'
ssh -i ~/.ssh/cluster_key <USER>@<NODE3_IP> 'hostname'
```

---

## Инициализация проекта Ansible

### Создание структуры каталогов

```bash
mkdir -p ansible-ha-postgres/{playbooks,roles,inventories/prod,group_vars,host_vars}
cd ansible-ha-postgres
```

### Конфигурация Ansible

Создать файл `ansible.cfg`:

```ini
[defaults]
inventory = inventories/prod/hosts
roles_path = roles
host_key_checking = False
retry_files_enabled = False
stdout_callback = default
private_key_file = ~/.ssh/cluster_key
remote_user = <USER>
interpreter_python = /usr/bin/python3

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml
```

### Inventory файл

Создать файл `inventories/prod/hosts`:

```ini
[all:vars]
ansible_user=<USER>
ansible_become=true

patroni_postgresql_version=16

postgresql_superuser_password="<SUPERUSER_PASSWORD>"
postgresql_replication_password="<REPLICATION_PASSWORD>"

etcd_host_list=['<NODE1_IP>:2379', '<NODE2_IP>:2379', '<NODE3_IP>:2379']

[ha_nodes]
pg-node1 ansible_host=<NODE1_IP>
pg-node2 ansible_host=<NODE2_IP>
pg-node3 ansible_host=<NODE3_IP>

[etcd_cluster:children]
ha_nodes

[postgres_cluster:children]
ha_nodes

[patroni_cluster:children]
ha_nodes

[etcd_nodes:children]
ha_nodes
```

Заменить плейсхолдеры:
- `<USER>` - имя пользователя
- `<NODE1_IP>`, `<NODE2_IP>`, `<NODE3_IP>` - IP адреса нод
- `<SUPERUSER_PASSWORD>` - пароль суперпользователя PostgreSQL
- `<REPLICATION_PASSWORD>` - пароль пользователя репликации

### Group variables

Создать файл `group_vars/ha_nodes.yml`:

```yaml
patroni_cluster_name: ha_postgres_cluster
patroni_scope: "{{ patroni_cluster_name }}"

etcd_host_list:
  - pg-node1:2379
  - pg-node2:2379
  - pg-node3:2379

patroni_restapi_port: 8008

patroni_postgresql_version: 16
patroni_data_dir: /var/lib/postgresql/{{ patroni_postgresql_version }}/main
patroni_listen_port: 5432
patroni_primary_slot_name: replication_slot_{{ inventory_hostname | replace('-', '_') }}
```

### Проверка связности

```bash
ansible all -m ping
```

Ожидаемый результат - SUCCESS для всех нод.

---

## Настройка базового окружения

### Установка hostname

Создать файл `playbooks/setup-hostnames.yml`:

```yaml
---
- name: Setup hostnames
  hosts: all
  become: true
  tasks:
    - name: Set hostname
      ansible.builtin.hostname:
        name: "{{ inventory_hostname }}"

    - name: Update /etc/hosts
      ansible.builtin.lineinfile:
        path: /etc/hosts
        regexp: '^127\.0\.1\.1'
        line: "127.0.1.1 {{ inventory_hostname }}"
        state: present
```

Применить:

```bash
ansible-playbook playbooks/setup-hostnames.yml
```

Проверить результат:

```bash
ansible all -m shell -a "hostname"
```

### Настройка /etc/hosts

Создать файл `playbooks/setup-hosts-file.yml`:

```yaml
---
- name: Configure /etc/hosts for cluster
  hosts: all
  become: true
  tasks:
    - name: Add cluster nodes to /etc/hosts
      ansible.builtin.blockinfile:
        path: /etc/hosts
        block: |
          <NODE1_IP> pg-node1
          <NODE2_IP> pg-node2
          <NODE3_IP> pg-node3
        marker: "# {mark} ANSIBLE MANAGED BLOCK - HA Cluster"
```

Заменить `<NODE1_IP>`, `<NODE2_IP>`, `<NODE3_IP>` на реальные IP адреса.

Применить:

```bash
ansible-playbook playbooks/setup-hosts-file.yml
```

Проверить результат:

```bash
ansible all -m shell -a "cat /etc/hosts | grep pg-node"
```

### Обновление пакетов

```bash
ansible all -m apt -a "update_cache=yes" -b
```

---

## Роль etcd

### Создание структуры роли

```bash
mkdir -p roles/etcd/{tasks,templates,handlers,defaults,meta}
```

### Файл defaults

Создать файл `roles/etcd/defaults/main.yml`:

```yaml
---
etcd_version: "3.5.17"
etcd_user: etcd
etcd_group: etcd
etcd_data_dir: /var/lib/etcd
etcd_wal_dir: /var/lib/etcd/wal
etcd_listen_client_urls: "http://0.0.0.0:2379"
etcd_listen_peer_urls: "http://0.0.0.0:2380"
etcd_initial_cluster_state: "new"
etcd_initial_cluster_token: "etcd-cluster-ha"
etcd_election_timeout: 5000
etcd_heartbeat_interval: 1000
```

### Файл meta

Создать файл `roles/etcd/meta/main.yml`:

```yaml
---
galaxy_info:
  author: DevOps Team
  description: etcd cluster installation and configuration
  license: MIT
  min_ansible_version: "2.15"
  platforms:
    - name: Debian
      versions:
        - bookworm
        - trixie

dependencies: []
```

### Файл handlers

Создать файл `roles/etcd/handlers/main.yml`:

```yaml
---
- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true

- name: Restart etcd
  ansible.builtin.systemd:
    name: etcd
    state: restarted
```

### Главный файл tasks

Создать файл `roles/etcd/tasks/main.yml`:

```yaml
---
- name: Include firewall tasks
  ansible.builtin.include_tasks: firewall.yml

- name: Include installation tasks
  ansible.builtin.include_tasks: install.yml

- name: Include configuration tasks
  ansible.builtin.include_tasks: configure.yml

- name: Include service tasks
  ansible.builtin.include_tasks: service.yml
```

### Файл firewall tasks

Создать файл `roles/etcd/tasks/firewall.yml`:

```yaml
---
- name: Allow etcd client port
  community.general.ufw:
    rule: allow
    port: '2379'
    proto: tcp

- name: Allow etcd peer port
  community.general.ufw:
    rule: allow
    port: '2380'
    proto: tcp

- name: Reload UFW
  community.general.ufw:
    state: reloaded
```

### Файл install tasks

Создать файл `roles/etcd/tasks/install.yml`:

```yaml
---
- name: Create etcd user
  ansible.builtin.user:
    name: "{{ etcd_user }}"
    system: true
    shell: /bin/false
    create_home: false

- name: Create etcd directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ etcd_user }}"
    group: "{{ etcd_group }}"
    mode: '0755'
  loop:
    - "{{ etcd_data_dir }}"
    - "{{ etcd_wal_dir }}"
    - /etc/etcd
    - /var/log/etcd

- name: Download etcd binary
  ansible.builtin.get_url:
    url: "https://github.com/etcd-io/etcd/releases/download/v{{ etcd_version }}/etcd-v{{ etcd_version }}-linux-amd64.tar.gz"
    dest: "/tmp/etcd-v{{ etcd_version }}-linux-amd64.tar.gz"
    mode: '0644'

- name: Extract etcd archive
  ansible.builtin.unarchive:
    src: "/tmp/etcd-v{{ etcd_version }}-linux-amd64.tar.gz"
    dest: /tmp
    remote_src: true

- name: Copy etcd binaries
  ansible.builtin.copy:
    src: "/tmp/etcd-v{{ etcd_version }}-linux-amd64/{{ item }}"
    dest: "/usr/local/bin/{{ item }}"
    owner: root
    group: root
    mode: '0755'
    remote_src: true
  loop:
    - etcd
    - etcdctl

- name: Cleanup temporary files
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop:
    - "/tmp/etcd-v{{ etcd_version }}-linux-amd64.tar.gz"
    - "/tmp/etcd-v{{ etcd_version }}-linux-amd64"
```

### Файл configure tasks

Создать файл `roles/etcd/tasks/configure.yml`:

```yaml
---
- name: Generate etcd configuration
  ansible.builtin.template:
    src: etcd.conf.j2
    dest: /etc/etcd/etcd.conf
    owner: "{{ etcd_user }}"
    group: "{{ etcd_group }}"
    mode: '0644'
  notify: restart etcd
```

### Файл service tasks

Создать файл `roles/etcd/tasks/service.yml`:

```yaml
---
- name: Create etcd systemd service
  ansible.builtin.template:
    src: etcd.service.j2
    dest: /etc/systemd/system/etcd.service
    owner: root
    group: root
    mode: '0644'
  notify: reload systemd

- name: Enable and start etcd service
  ansible.builtin.systemd:
    name: etcd
    enabled: true
    state: started
    daemon_reload: true
```

### Template systemd service

Создать файл `roles/etcd/templates/etcd.service.j2`:

```ini
[Unit]
Description=etcd - highly-available key value store
Documentation=https://etcd.io/docs/
After=network.target

[Service]
Type=notify
User={{ etcd_user }}
Group={{ etcd_group }}
EnvironmentFile=/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

### Template конфигурации etcd

Создать файл `roles/etcd/templates/etcd.conf.j2`:

```bash
ETCD_NAME={{ inventory_hostname }}
ETCD_DATA_DIR={{ etcd_data_dir }}
ETCD_WAL_DIR={{ etcd_wal_dir }}
ETCD_LISTEN_PEER_URLS={{ etcd_listen_peer_urls }}
ETCD_LISTEN_CLIENT_URLS={{ etcd_listen_client_urls }}
ETCD_INITIAL_ADVERTISE_PEER_URLS=http://{{ ansible_default_ipv4.address }}:2380
ETCD_ADVERTISE_CLIENT_URLS=http://{{ ansible_default_ipv4.address }}:2379
ETCD_INITIAL_CLUSTER_TOKEN={{ etcd_initial_cluster_token }}
ETCD_INITIAL_CLUSTER_STATE={{ etcd_initial_cluster_state }}
ETCD_INITIAL_CLUSTER={% for host in groups['etcd_cluster'] %}{{ hostvars[host].inventory_hostname }}=http://{{ hostvars[host].ansible_default_ipv4.address }}:2380{% if not loop.last %},{% endif %}{% endfor %}

ETCD_ELECTION_TIMEOUT={{ etcd_election_timeout }}
ETCD_HEARTBEAT_INTERVAL={{ etcd_heartbeat_interval }}
ETCD_ENABLE_V2=true
```

---

## Роль PostgreSQL

### Создание структуры роли

```bash
mkdir -p roles/postgresql/{tasks,templates,defaults,meta}
```

### Файл defaults

Создать файл `roles/postgresql/defaults/main.yml`:

```yaml
---
postgresql_version: "16"
postgresql_user: postgres
postgresql_group: postgres
postgresql_data_dir: /var/lib/postgresql/{{ postgresql_version }}/main
postgresql_config_dir: /etc/postgresql/{{ postgresql_version }}/main
postgresql_port: 5432
postgresql_max_connections: 100
postgresql_shared_buffers: "256MB"
postgresql_effective_cache_size: "1GB"
postgresql_maintenance_work_mem: "64MB"
postgresql_wal_level: "replica"
postgresql_max_wal_senders: 10
postgresql_max_replication_slots: 10
```

### Файл meta

Создать файл `roles/postgresql/meta/main.yml`:

```yaml
---
galaxy_info:
  author: DevOps Team
  description: PostgreSQL installation and configuration for Patroni
  license: MIT
  min_ansible_version: "2.15"
  platforms:
    - name: Debian
      versions:
        - bookworm
        - trixie

dependencies: []
```

### Главный файл tasks

Создать файл `roles/postgresql/tasks/main.yml`:

```yaml
---
- name: Include repository tasks
  ansible.builtin.include_tasks: repository.yml

- name: Include installation tasks
  ansible.builtin.include_tasks: install.yml

- name: Include firewall tasks
  ansible.builtin.include_tasks: firewall.yml
```

### Файл repository tasks

Создать файл `roles/postgresql/tasks/repository.yml`:

```yaml
---
- name: Install required packages
  ansible.builtin.apt:
    name:
      - gnupg
      - lsb-release
      - wget
      - ca-certificates
    state: present
    update_cache: true

- name: Download PostgreSQL GPG key
  ansible.builtin.get_url:
    url: https://www.postgresql.org/media/keys/ACCC4CF8.asc
    dest: /tmp/pgdg.asc
    mode: '0644'

- name: Add PostgreSQL GPG key to keyring
  ansible.builtin.shell: |
    gpg --dearmor < /tmp/pgdg.asc > /etc/apt/trusted.gpg.d/pgdg.gpg
    chmod 644 /etc/apt/trusted.gpg.d/pgdg.gpg
  args:
    creates: /etc/apt/trusted.gpg.d/pgdg.gpg

- name: Add PostgreSQL repository
  ansible.builtin.apt_repository:
    repo: "deb http://apt.postgresql.org/pub/repos/apt {{ ansible_distribution_release }}-pgdg main"
    state: present
    filename: pgdg

- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
```

### Файл install tasks

Создать файл `roles/postgresql/tasks/install.yml`:

```yaml
---
- name: Install PostgreSQL packages
  ansible.builtin.apt:
    name:
      - postgresql-{{ postgresql_version }}
      - postgresql-client-{{ postgresql_version }}
      - postgresql-contrib-{{ postgresql_version }}
      - python3-psycopg2
    state: present

- name: Stop and disable PostgreSQL service
  ansible.builtin.systemd:
    name: postgresql
    state: stopped
    enabled: false

- name: Remove PostgreSQL default cluster
  ansible.builtin.shell: |
    pg_dropcluster --stop {{ postgresql_version }} main || true
  args:
    removes: "{{ postgresql_data_dir }}"

- name: Create postgres user directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ postgresql_user }}"
    group: "{{ postgresql_group }}"
    mode: '0700'
  loop:
    - /var/lib/postgresql
    - /var/lib/postgresql/{{ postgresql_version }}
```

Команда `pg_dropcluster` удаляет дефолтный кластер PostgreSQL, созданный при установке пакета. Необходимо для полного контроля кластера через Patroni.

### Файл firewall tasks

Создать файл `roles/postgresql/tasks/firewall.yml`:

```yaml
---
- name: Allow PostgreSQL port
  community.general.ufw:
    rule: allow
    port: '{{ postgresql_port }}'
    proto: tcp

- name: Reload UFW
  community.general.ufw:
    state: reloaded
```

---

## Роль Patroni

### Создание структуры роли

```bash
mkdir -p roles/patroni/{tasks,templates,handlers,defaults,meta}
```

### Файл defaults

Создать файл `roles/patroni/defaults/main.yml`:

```yaml
---
patroni_version: "4.0.4"
patroni_scope: "postgres-ha"
patroni_cluster_name: "postgres-ha"
patroni_namespace: "/service/"

patroni_restapi_port: 8008
patroni_listen_port: 5432

patroni_postgresql_version: 16
patroni_data_dir: /var/lib/postgresql/{{ patroni_postgresql_version }}/main
patroni_bin_dir: /usr/lib/postgresql/{{ patroni_postgresql_version }}/bin

patroni_replication_user: "replicator"
patroni_replication_password: "replicator_password"
patroni_superuser_user: "postgres"
patroni_superuser_password: "postgres_password"

patroni_dcs_ttl: 30
patroni_dcs_loop_wait: 10
patroni_dcs_retry_timeout: 10
```

### Файл meta

Создать файл `roles/patroni/meta/main.yml`:

```yaml
---
galaxy_info:
  author: DevOps Team
  description: Patroni HA orchestrator for PostgreSQL
  license: MIT
  min_ansible_version: "2.15"
  platforms:
    - name: Debian
      versions:
        - bookworm
        - trixie

dependencies: []
```

### Файл handlers

Создать файл `roles/patroni/handlers/main.yml`:

```yaml
---
- name: Reload systemd daemon
  ansible.builtin.systemd_service:
    daemon_reload: true

- name: Restart patroni
  ansible.builtin.systemd_service:
    name: patroni
    state: restarted
```

### Главный файл tasks

Создать файл `roles/patroni/tasks/main.yml`:

```yaml
---
- name: Include installation tasks
  ansible.builtin.include_tasks: install.yml

- name: Include configuration tasks
  ansible.builtin.include_tasks: configure.yml

- name: Include service tasks
  ansible.builtin.include_tasks: service.yml

- name: Include firewall tasks
  ansible.builtin.include_tasks: firewall.yml
```

### Файл install tasks

Создать файл `roles/patroni/tasks/install.yml`:

```yaml
---
- name: Install Patroni and dependencies
  ansible.builtin.apt:
    name:
      - patroni
      - python3-pip
      - python3-etcd
      - python3-psycopg2
    state: present

- name: Create Patroni directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: postgres
    group: postgres
    mode: '0755'
  loop:
    - /etc/patroni
    - /var/log/patroni
```

### Файл configure tasks

Создать файл `roles/patroni/tasks/configure.yml`:

```yaml
---
- name: Configure Patroni
  ansible.builtin.template:
    src: patroni.yml.j2
    dest: /etc/patroni/patroni.yml
    owner: postgres
    group: postgres
    mode: '0640'
  notify: Restart patroni

- name: Copy pg_hba.conf template
  ansible.builtin.template:
    src: pg_hba.conf.j2
    dest: /etc/patroni/pg_hba.conf.j2
    owner: postgres
    group: postgres
    mode: '0644'
```

### Файл service tasks

Создать файл `roles/patroni/tasks/service.yml`:

```yaml
---
- name: Deploy patroni systemd service
  ansible.builtin.template:
    src: patroni.service.j2
    dest: /etc/systemd/system/patroni.service
    mode: '0644'
  notify:
    - Reload systemd daemon
    - Restart patroni

- name: Enable and start patroni service
  ansible.builtin.systemd_service:
    name: patroni
    enabled: true
    state: started
```

### Файл firewall tasks

Создать файл `roles/patroni/tasks/firewall.yml`:

```yaml
---
- name: Allow Patroni REST API port
  community.general.ufw:
    rule: allow
    port: "{{ patroni_restapi_port }}"
    proto: tcp

- name: Allow PostgreSQL port
  community.general.ufw:
    rule: allow
    port: "{{ patroni_listen_port }}"
    proto: tcp
```

### Template systemd service

Создать файл `roles/patroni/templates/patroni.service.j2`:

```ini
[Unit]
Description=Patroni: HA cluster
After=network.target etcd.service

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/usr/bin/patroni /etc/patroni/patroni.yml
KillMode=process
TimeoutSec=300
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

### Template конфигурации Patroni

Создать файл `roles/patroni/templates/patroni.yml.j2`:

```yaml
scope: ha_postgres_cluster
name: {{ inventory_hostname }}

postgresql:
  bin_dir: /usr/lib/postgresql/16/bin
  data_dir: /var/lib/postgresql/16/main
  listen: 0.0.0.0:5432
  connect_address: {{ ansible_default_ipv4.address }}:5432

  use_pg_rewind: true
  use_slots: true

  parameters:
    listen_addresses: '0.0.0.0'
    port: 5432
    max_connections: 100
    wal_level: replica
    hot_standby: on
    max_wal_senders: 10
    max_replication_slots: 10
    wal_log_hints: on
    synchronous_standby_names: ''

  create_replica_method:
    - basebackup

  authentication:
    replication:
      username: replicator
      password: <REPLICATION_PASSWORD>
    superuser:
      username: postgres
      password: <SUPERUSER_PASSWORD>

restapi:
  listen: 0.0.0.0:8008
  connect_address: {{ ansible_default_ipv4.address }}:8008

etcd3:
  hosts: ['{{ groups["etcd_nodes"][0] }}:2379', '{{ groups["etcd_nodes"][1] }}:2379', '{{ groups["etcd_nodes"][2] }}:2379']

dcs:
  retry_timeout: 10
  loop_wait: 10
  ttl: 30

bootstrap:
  language: en
  locale: en_US.UTF-8
  timezone: Europe/Riga

  dcs:
    postgresql:
      use_pg_rewind: true
      use_slots: true

  initdb:
    - encoding: UTF8
    - data-checksums
    - auth-local: trust
    - auth-host: md5
```

Заменить `<REPLICATION_PASSWORD>` и `<SUPERUSER_PASSWORD>` на значения из inventory или использовать переменные Ansible.

### Template pg_hba.conf

Создать файл `roles/patroni/templates/pg_hba.conf.j2`:

```
local   all             all                                     trust

host    all             all             127.0.0.1/32            md5

host    replication     replicator      <SUBNET>/24             md5
host    replication     replicator      127.0.0.1/32            md5
host    replication     replicator      ::1/128                 md5

host    all             postgres        <SUBNET>/24             md5
host    all             postgres        127.0.0.1/32            md5
host    all             postgres        ::1/128                 md5

host    all             all             <SUBNET>/24             md5
```

Заменить `<SUBNET>` на подсеть кластера (например, 192.168.1.0).

---

## Playbooks развертывания

### Playbook etcd

Создать файл `playbooks/deploy-etcd.yml`:

```yaml
---
- name: Deploy etcd cluster
  hosts: etcd_cluster
  become: true
  roles:
    - etcd
```

### Playbook PostgreSQL

Создать файл `playbooks/deploy-postgresql.yml`:

```yaml
---
- name: Deploy PostgreSQL
  hosts: postgres_cluster
  become: true
  roles:
    - postgresql
```

### Playbook Patroni

Создать файл `playbooks/deploy-patroni.yml`:

```yaml
---
- name: Deploy Patroni HA Cluster
  hosts: patroni_cluster
  become: true
  roles:
    - patroni
```

### Главный playbook

Создать файл `playbooks/deploy-ha-cluster.yml`:

```yaml
---
- name: Deploy etcd cluster
  ansible.builtin.import_playbook: deploy-etcd.yml

- name: Deploy PostgreSQL
  ansible.builtin.import_playbook: deploy-postgresql.yml

- name: Deploy Patroni HA Manager
  ansible.builtin.import_playbook: deploy-patroni.yml
```

---

## Makefile

Создать файл `Makefile`:

```makefile
.PHONY: help lint syntax-check ping install-etcd install-postgresql install-patroni deploy-all test-cluster backup clean switchover create-test-table insert-test-data check-replication update-packages setup-ssh

GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

help: ## Показать справку
	@echo "$(GREEN)Ansible HA Cluster Management$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'

lint: ## Проверка кода ansible-lint
	@echo "$(GREEN)Running ansible-lint...$(NC)"
	@ansible-lint || (echo "$(RED)Lint failed!$(NC)" && exit 1)
	@echo "$(GREEN)Lint passed!$(NC)"

syntax-check: ## Проверка синтаксиса всех playbooks
	@echo "$(GREEN)Checking syntax...$(NC)"
	@for file in playbooks/*.yml; do \
		echo "Checking $$file..."; \
		ansible-playbook $$file --syntax-check || exit 1; \
	done
	@echo "$(GREEN)All playbooks syntax is valid!$(NC)"

ping: ## Проверка доступности всех хостов
	@echo "$(GREEN)Pinging all hosts...$(NC)"
	@ansible all -m ping

status: ## Показать статус кластера
	@echo "$(GREEN)Cluster Status:$(NC)"
	@ansible pg-node1 -m shell -a "patronictl -c /etc/patroni/patroni.yml list"

etcd-status: ## Показать статус etcd кластера
	@echo "$(GREEN)etcd Cluster Status:$(NC)"
	@ansible pg-node1 -m shell -a "etcdctl --endpoints=http://<NODE1_IP>:2379,http://<NODE2_IP>:2379,http://<NODE3_IP>:2379 endpoint status --write-out=table"

install-etcd: lint ## Установить etcd кластер
	@echo "$(GREEN)Installing etcd cluster...$(NC)"
	@ansible-playbook playbooks/deploy-etcd.yml

install-postgresql: lint ## Установить PostgreSQL
	@echo "$(GREEN)Installing PostgreSQL...$(NC)"
	@ansible-playbook playbooks/deploy-postgresql.yml

install-patroni: lint ## Установить Patroni
	@echo "$(GREEN)Installing Patroni...$(NC)"
	@ansible-playbook playbooks/deploy-patroni.yml

deploy-all: lint ## Развернуть весь кластер (etcd + PostgreSQL + Patroni)
	@echo "$(GREEN)Deploying full HA cluster...$(NC)"
	@ansible-playbook playbooks/deploy-ha-cluster.yml
	@echo "$(GREEN)Deployment complete!$(NC)"
	@make status

setup-hosts: ## Настроить hostname и /etc/hosts на всех нодах
	@echo "$(GREEN)Setting up hostnames and hosts file...$(NC)"
	@ansible-playbook playbooks/setup-hostnames.yml
	@ansible-playbook playbooks/setup-hosts-file.yml

test-cluster: ## Тестирование отказоустойчивости кластера
	@echo "$(GREEN)Testing cluster failover...$(NC)"
	@echo "Current status:"
	@ansible pg-node1 -m shell -a "patronictl -c /etc/patroni/patroni.yml list"
	@echo "\n$(YELLOW)Stopping leader for failover test...$(NC)"
	@read -p "Press Enter to continue..."
	@ansible pg-node1 -m systemd -a "name=patroni state=stopped" -b || true
	@sleep 15
	@echo "$(GREEN)New cluster status:$(NC)"
	@ansible pg-node2 -m shell -a "patronictl -c /etc/patroni/patroni.yml list" || true
	@echo "\n$(YELLOW)Restoring pg-node1...$(NC)"
	@ansible pg-node1 -m systemd -a "name=patroni state=started" -b
	@sleep 10
	@make status

backup: ## Создать backup конфигураций
	@echo "$(GREEN)Creating backup...$(NC)"
	@mkdir -p backups/$$(date +%Y%m%d_%H%M%S)
	@tar -czf backups/$$(date +%Y%m%d_%H%M%S)/ansible-ha-postgres.tar.gz \
		--exclude='backups' --exclude='.ansible' \
		. 2>/dev/null || true
	@echo "$(GREEN)Backup created in backups/$$(date +%Y%m%d_%H%M%S)/$(NC)"

clean: ## Очистить временные файлы
	@echo "$(GREEN)Cleaning temporary files...$(NC)"
	@find . -name "*.retry" -delete
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete!$(NC)"

validate: lint syntax-check ping ## Полная валидация проекта
	@echo "$(GREEN)All validations passed!$(NC)"

services-status: ## Проверить статус всех сервисов на нодах
	@echo "$(GREEN)Services Status:$(NC)"
	@ansible all -m shell -a "systemctl is-active etcd patroni" -b

logs-etcd: ## Показать логи etcd с первой ноды
	@ansible pg-node1 -m shell -a "journalctl -u etcd -n 50 --no-pager" -b

logs-patroni: ## Показать логи patroni с первой ноды
	@ansible pg-node1 -m shell -a "journalctl -u patroni -n 50 --no-pager" -b

version: ## Показать версии установленного ПО
	@echo "$(GREEN)Software Versions:$(NC)"
	@ansible all -m shell -a "etcdctl version | head -1" 2>/dev/null || true
	@ansible all -m shell -a "patronictl version" 2>/dev/null || true
	@ansible all -m shell -a "psql --version" 2>/dev/null || true

create-test-table: ## Создать тестовую таблицу
	@echo "$(GREEN)Creating test table...$(NC)"
	@ansible pg-node1 -m shell -a "sudo -u postgres psql -c \"CREATE TABLE IF NOT EXISTS test (id SERIAL, data TEXT);\"" -b

insert-test-data: ## Вставить тестовые данные
	@echo "$(GREEN)Inserting test data...$(NC)"
	@ansible pg-node1 -m shell -a "sudo -u postgres psql -c \"INSERT INTO test (data) VALUES ('Test data at $$(date)');\"" -b

check-replication: ## Проверить репликацию на всех нодах
	@echo "$(GREEN)Checking replication on all nodes...$(NC)"
	@echo "$(YELLOW)Node 1:$(NC)"
	@ansible pg-node1 -m shell -a "sudo -u postgres psql -c \"SELECT * FROM test;\"" -b || true
	@echo "$(YELLOW)Node 2:$(NC)"
	@ansible pg-node2 -m shell -a "sudo -u postgres psql -c \"SELECT * FROM test;\"" -b || true
	@echo "$(YELLOW)Node 3:$(NC)"
	@ansible pg-node3 -m shell -a "sudo -u postgres psql -c \"SELECT * FROM test;\"" -b || true

switchover: ## Плановое переключение Leader
	@echo "$(GREEN)Performing switchover...$(NC)"
	@echo "$(YELLOW)Current cluster status:$(NC)"
	@ansible pg-node1 -m shell -a "patronictl -c /etc/patroni/patroni.yml list" || true
	@echo ""
	@echo "$(YELLOW)Enter current leader name (e.g., pg-node1):$(NC)"
	@read -p "" LEADER; \
	echo "$(YELLOW)Enter target candidate name (e.g., pg-node2):$(NC)"; \
	read -p "" CANDIDATE; \
	echo "Switching from $$LEADER to $$CANDIDATE..."; \
	ansible pg-node1 -m shell -a "patronictl -c /etc/patroni/patroni.yml switchover --leader $$LEADER --candidate $$CANDIDATE --force" || true
	@sleep 5
	@echo "$(GREEN)New cluster status:$(NC)"
	@make status

update-packages: ## Обновить пакеты на всех нодах
	@echo "$(GREEN)Updating packages on all nodes...$(NC)"
	@ansible all -m apt -a "update_cache=yes" -b

setup-ssh: ## Проверить SSH подключение к нодам
	@echo "$(GREEN)Setting up SSH access...$(NC)"
	@echo "$(YELLOW)Testing SSH connection to all nodes...$(NC)"
	@ansible all -m shell -a "hostname"
```

### Использование Makefile

Makefile предоставляет удобные команды для управления кластером.

Просмотр всех доступных команд:

```bash
make help
```

Основные команды:

| Команда | Описание |
|---------|----------|
| `make help` | Показать справку |
| `make deploy-all` | Развернуть полный HA кластер |
| `make install-etcd` | Установить только etcd кластер |
| `make install-postgresql` | Установить только PostgreSQL |
| `make install-patroni` | Установить только Patroni |
| `make status` | Показать статус кластера Patroni |
| `make etcd-status` | Показать статус etcd кластера |
| `make services-status` | Проверить статус всех сервисов |
| `make logs-patroni` | Показать логи Patroni |
| `make logs-etcd` | Показать логи etcd |
| `make version` | Показать версии установленного ПО |
| `make test-cluster` | Тестирование отказоустойчивости |
| `make switchover` | Плановое переключение Leader |
| `make create-test-table` | Создать тестовую таблицу |
| `make insert-test-data` | Вставить тестовые данные |
| `make check-replication` | Проверить репликацию на всех нодах |
| `make setup-hosts` | Настроить hostname и /etc/hosts |
| `make update-packages` | Обновить пакеты на всех нодах |
| `make setup-ssh` | Проверить SSH подключение |
| `make backup` | Создать backup конфигураций |
| `make validate` | Полная валидация проекта |
| `make lint` | Проверка кода ansible-lint |
| `make syntax-check` | Проверка синтаксиса playbooks |
| `make ping` | Проверка доступности хостов |
| `make clean` | Очистить временные файлы |

---

## Развертывание

**Примечание:** Начиная с этого момента, Makefile уже создан и можно использовать команды `make` для управления кластером.

### Полное развертывание кластера

```bash
make deploy-all
```

Процесс занимает 5-10 минут в зависимости от сети и производительности нод.

### Проверка статуса

```bash
make status
```

Ожидаемый результат:

```
+ Cluster: ha_postgres_cluster +-----------+
| Member   | Host        | Role    | State     | TL | Lag in MB |
+----------+-------------+---------+-----------+----+-----------+
| pg-node1 | <NODE1_IP>  | Leader  | running   |  1 |           |
| pg-node2 | <NODE2_IP>  | Replica | streaming |  1 |         0 |
| pg-node3 | <NODE3_IP>  | Replica | streaming |  1 |         0 |
+----------+-------------+---------+-----------+----+-----------+
```

---

## Проверка репликации

### Создание тестовой таблицы

```bash
make create-test-table
```

### Вставка тестовых данных

```bash
make insert-test-data
```

### Проверка репликации на всех нодах

```bash
make check-replication
```

Данные должны присутствовать на всех нодах кластера.

---

## Тестирование отказоустойчивости

### Автоматизированный тест

Для автоматизированного тестирования failover использовать:

```bash
make test-cluster
```

Команда выполнит:
- Показ текущего статуса
- Остановку Leader
- Ожидание переизбрания (15 секунд)
- Проверку нового Leader
- Восстановление остановленной ноды

### Ручной тест автоматического failover

Остановить Leader:

```bash
ansible pg-node1 -m systemd -a "name=patroni state=stopped" -b
```

Ожидать переизбрания нового Leader (15-20 секунд):

```bash
sleep 20
```

Проверить новый Leader:

```bash
make status
```

Восстановить остановленную ноду:

```bash
ansible pg-node1 -m systemd -a "name=patroni state=started" -b
```

Нода автоматически присоединится к кластеру как Replica.

### Плановое переключение

Выполнить плановый switchover:

```bash
make switchover
```

Команда запросит ввести:
- Имя текущего Leader (например, pg-node1)
- Имя целевого кандидата (например, pg-node2)

После выполнения будет показан обновленный статус кластера.

---

## Диагностика

Для диагностики кластера использовать команды из Makefile:

Проверка статуса кластера Patroni:

```bash
make status
```

Проверка статуса etcd:

```bash
make etcd-status
```

Проверка статуса всех сервисов:

```bash
make services-status
```

Просмотр логов Patroni:

```bash
make logs-patroni
```

Просмотр логов etcd:

```bash
make logs-etcd
```

Просмотр версий установленного ПО:

```bash
make version
```
