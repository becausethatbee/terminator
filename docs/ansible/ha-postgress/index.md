
# Развертывание HA кластера PostgreSQL

Пошаговое руководство по развертыванию высокодоступного кластера PostgreSQL с Patroni и etcd.

---

## Предварительные требования

### Инфраструктура

Минимальная конфигурация ноды:

| Параметр | Значение |
|----------|----------|
| CPU | 1 core |
| RAM | 2 GB |
| Disk | 20 GB |
| OS | Debian 13 (Trixie) |

Количество нод: 3

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

## Настройка SSH доступа

### Конвертация SSH ключа

Если используется PuTTY ключ (.ppk), конвертируем в OpenSSH:

~~~bash
sudo apt install putty-tools
puttygen your-key.ppk -O private-openssh -o ~/.ssh/cluster_key
chmod 600 ~/.ssh/cluster_key
~~~

### Проверка SSH подключения

~~~bash
ssh -i ~/.ssh/cluster_key user@<NODE1_IP> 'hostname'
ssh -i ~/.ssh/cluster_key user@<NODE2_IP> 'hostname'
ssh -i ~/.ssh/cluster_key user@<NODE3_IP> 'hostname'
~~~

---

## Инициализация Ansible проекта

### Создание структуры

~~~bash
mkdir -p ansible-ha-postgres/{playbooks,roles,inventories/prod,group_vars,host_vars}
cd ansible-ha-postgres
~~~

### Конфигурация Ansible

Файл `ansible.cfg`:

~~~ini
[defaults]
inventory = inventories/prod/hosts
roles_path = roles
host_key_checking = False
retry_files_enabled = False
stdout_callback = default
result_format = yaml
private_key_file = ~/.ssh/cluster_key
remote_user = user
interpreter_python = /usr/bin/python3

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml
~~~

### Inventory файл

Файл `inventories/prod/hosts`:

~~~ini
[ha_nodes]
pg-node1 ansible_host=<NODE1_IP>
pg-node2 ansible_host=<NODE2_IP>
pg-node3 ansible_host=<NODE3_IP>

[etcd_nodes:children]
ha_nodes

[etcd_cluster:children]
ha_nodes

[postgres_cluster:children]
ha_nodes

[patroni_cluster:children]
ha_nodes

[all:vars]
ansible_user=user
ansible_become=true
~~~

Замените плейсхолдеры на реальные IP адреса.

### Group variables

Файл `group_vars/ha_nodes.yml`:

~~~yaml
---
patroni_postgresql_version: 16
patroni_data_dir: /var/lib/postgresql/{{ patroni_postgresql_version }}/main
patroni_bin_dir: /usr/lib/postgresql/{{ patroni_postgresql_version }}/bin

postgresql_superuser_password: "{{ vault_postgresql_superuser_password }}"
postgresql_replication_password: "{{ vault_postgresql_replication_password }}"

patroni_cluster_name: ha_postgres_cluster
patroni_scope: "{{ patroni_cluster_name }}"

patroni_restapi_port: 8008
patroni_listen_port: 5432

patroni_dcs_ttl: 30
patroni_dcs_loop_wait: 10
patroni_dcs_retry_timeout: 10

patroni_replication_user: "replicator"
patroni_superuser_user: "postgres"
~~~

### Ansible Vault для паролей

Создание vault файла:

~~~bash
ansible-vault create group_vars/vault.yml
~~~

Содержимое `group_vars/vault.yml`:

~~~yaml
---
vault_postgresql_superuser_password: "YourSecureSuperPassword"
vault_postgresql_replication_password: "YourSecureReplicaPassword"
~~~

Запуск playbook с vault:

~~~bash
ansible-playbook playbook.yml --ask-vault-pass
~~~

Или создать файл с паролем vault:

~~~bash
echo "your_vault_password" > ~/.vault_pass
chmod 600 ~/.vault_pass
~~~

Обновить `ansible.cfg`:

~~~ini
[defaults]
vault_password_file = ~/.vault_pass
~~~

### Проверка связности

~~~bash
ansible all -m ping
~~~

Ожидаемый результат - SUCCESS для всех трех нод.

---

## Настройка базового окружения

### Playbook для hostname

Файл `playbooks/setup-hostnames.yml`:

~~~yaml
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
~~~

Применение:

~~~bash
ansible-playbook playbooks/setup-hostnames.yml
~~~

Проверка:

~~~bash
ansible all -m shell -a "hostname"
~~~

### Playbook для /etc/hosts

Файл `playbooks/setup-hosts-file.yml`:

~~~yaml
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
~~~

Замените плейсхолдеры на реальные IP.

Применение:

~~~bash
ansible-playbook playbooks/setup-hosts-file.yml
~~~

Проверка:

~~~bash
ansible all -m shell -a "cat /etc/hosts | grep pg-node"
~~~

### Обновление пакетов

~~~bash
ansible all -m apt -a "update_cache=yes" -b
~~~

---

## Создание ролей Ansible

### Структура роли etcd

~~~bash
mkdir -p roles/etcd/{tasks,templates,handlers,defaults,meta}
~~~

Файл `roles/etcd/defaults/main.yml`:

~~~yaml
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
~~~

Файл `roles/etcd/tasks/main.yml`:

~~~yaml
---
- name: Include firewall tasks
  ansible.builtin.include_tasks: firewall.yml

- name: Include installation tasks
  ansible.builtin.include_tasks: install.yml

- name: Include configuration tasks
  ansible.builtin.include_tasks: configure.yml

- name: Include service tasks
  ansible.builtin.include_tasks: service.yml
~~~

Файл `roles/etcd/tasks/firewall.yml`:

~~~yaml
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
~~~

Файл `roles/etcd/handlers/main.yml`:

~~~yaml
---
- name: Reload systemd
  ansible.builtin.systemd:
    daemon_reload: true

- name: Restart etcd
  ansible.builtin.systemd:
    name: etcd
    state: restarted
~~~

### Структура роли PostgreSQL

~~~bash
mkdir -p roles/postgresql/{tasks,templates,defaults,meta}
~~~

Файл `roles/postgresql/defaults/main.yml`:

~~~yaml
---
postgresql_version: "16"
postgresql_port: 5432
~~~

Файл `roles/postgresql/tasks/main.yml`:

~~~yaml
---
- name: Include repository tasks
  ansible.builtin.include_tasks: repository.yml

- name: Include installation tasks
  ansible.builtin.include_tasks: install.yml

- name: Include firewall tasks
  ansible.builtin.include_tasks: firewall.yml
~~~

### Структура роли Patroni

~~~bash
mkdir -p roles/patroni/{tasks,templates,handlers,defaults,meta}
~~~

Файл `roles/patroni/defaults/main.yml`:

~~~yaml
---
patroni_version: "4.0.7"
patroni_restapi_port: 8008
patroni_listen_port: 5432
patroni_postgresql_version: 16
patroni_data_dir: /var/lib/postgresql/{{ patroni_postgresql_version }}/main
patroni_bin_dir: /usr/lib/postgresql/{{ patroni_postgresql_version }}/bin
patroni_dcs_ttl: 30
patroni_dcs_loop_wait: 10
patroni_dcs_retry_timeout: 10
~~~

Файл `roles/patroni/tasks/main.yml`:

~~~yaml
---
- name: Include installation tasks
  ansible.builtin.include_tasks: install.yml

- name: Include configuration tasks
  ansible.builtin.include_tasks: configure.yml

- name: Include service tasks
  ansible.builtin.include_tasks: service.yml

- name: Include firewall tasks
  ansible.builtin.include_tasks: firewall.yml
~~~

Файл `roles/patroni/templates/patroni.yml.j2`:

~~~yaml
scope: {{ patroni_cluster_name }}
name: {{ inventory_hostname }}

postgresql:
  bin_dir: {{ patroni_bin_dir }}
  data_dir: {{ patroni_data_dir }}
  listen: 0.0.0.0:{{ patroni_listen_port }}
  connect_address: {{ ansible_default_ipv4.address }}:{{ patroni_listen_port }}
  use_pg_rewind: true
  use_slots: true
  parameters:
    listen_addresses: '0.0.0.0'
    port: {{ patroni_listen_port }}
    max_connections: 100
    wal_level: replica
    hot_standby: on
    max_wal_senders: 10
    max_replication_slots: 10
    wal_log_hints: on
  authentication:
    replication:
      username: {{ patroni_replication_user }}
      password: {{ postgresql_replication_password }}
    superuser:
      username: {{ patroni_superuser_user }}
      password: {{ postgresql_superuser_password }}

restapi:
  listen: 0.0.0.0:{{ patroni_restapi_port }}
  connect_address: {{ ansible_default_ipv4.address }}:{{ patroni_restapi_port }}

etcd3:
  hosts: {% for host in groups['etcd_nodes'] %}{{ hostvars[host].ansible_host }}:2379{% if not loop.last %},{% endif %}{% endfor %}

dcs:
  retry_timeout: {{ patroni_dcs_retry_timeout }}
  loop_wait: {{ patroni_dcs_loop_wait }}
  ttl: {{ patroni_dcs_ttl }}

bootstrap:
  dcs:
    postgresql:
      use_pg_rewind: true
      use_slots: true
  initdb:
    - encoding: UTF8
    - data-checksums
    - auth-local: trust
    - auth-host: md5
~~~

---

## Playbooks для развертывания

### Playbook для etcd

Файл `playbooks/deploy-etcd.yml`:

~~~yaml
---
- name: Deploy etcd cluster
  hosts: etcd_cluster
  become: true
  roles:
    - etcd
~~~

### Playbook для PostgreSQL

Файл `playbooks/deploy-postgresql.yml`:

~~~yaml
---
- name: Deploy PostgreSQL
  hosts: postgres_cluster
  become: true
  roles:
    - postgresql
~~~

### Playbook для Patroni

Файл `playbooks/deploy-patroni.yml`:

~~~yaml
---
- name: Deploy Patroni HA Cluster
  hosts: patroni_cluster
  become: true
  roles:
    - patroni
~~~

### Главный playbook

Файл `playbooks/deploy-ha-cluster.yml`:

~~~yaml
---
- name: Deploy etcd cluster
  ansible.builtin.import_playbook: deploy-etcd.yml

- name: Deploy PostgreSQL
  ansible.builtin.import_playbook: deploy-postgresql.yml

- name: Deploy Patroni HA Manager
  ansible.builtin.import_playbook: deploy-patroni.yml
~~~

---

## Развертывание кластера

### Создание Makefile

Файл `Makefile`:

~~~makefile
.PHONY: help deploy-all status

help:
	@echo "Available commands:"
	@echo "  make deploy-all   - Deploy full HA cluster"
	@echo "  make status       - Show cluster status"
	@echo "  make lint         - Run ansible-lint"

deploy-all:
	ansible-playbook playbooks/deploy-ha-cluster.yml

status:
	ansible pg-node1 -m shell -a "patronictl -c /etc/patroni/patroni.yml list"

lint:
	ansible-lint
~~~

### Полное развертывание

~~~bash
make deploy-all
~~~

Процесс займет 5-10 минут.

### Проверка результата

~~~bash
make status
~~~

Ожидаемый результат:

~~~
+ Cluster: ha_postgres_cluster +-----------+
| Member   | Host    | Role    | State     | TL | Lag in MB |
+----------+---------+---------+-----------+----+-----------+
| pg-node1 | <IP1>   | Leader  | running   |  1 |           |
| pg-node2 | <IP2>   | Replica | streaming |  1 |         0 |
| pg-node3 | <IP3>   | Replica | streaming |  1 |         0 |
+----------+---------+---------+-----------+----+-----------+
~~~

---

## Проверка работоспособности

### Создание тестовой таблицы

Подключение к Leader:

~~~bash
ansible pg-node1 -m shell -a "sudo -u postgres psql -c \"CREATE TABLE test (id SERIAL, data TEXT);\""
~~~

Вставка данных:

~~~bash
ansible pg-node1 -m shell -a "sudo -u postgres psql -c \"INSERT INTO test (data) VALUES ('Test data');\""
~~~

### Проверка репликации

Проверка на Replica:

~~~bash
ansible pg-node2 -m shell -a "sudo -u postgres psql -c \"SELECT * FROM test;\""
~~~

Данные должны присутствовать на всех нодах.

---

## Тестирование отказоустойчивости

### Автоматический failover

Остановка Leader:

~~~bash
ansible pg-node1 -m systemd -a "name=patroni state=stopped" -b
~~~

Ожидание переизбрания (15 секунд):

~~~bash
sleep 15
~~~

Проверка нового Leader:

~~~bash
make status
~~~

Восстановление ноды:

~~~bash
ansible pg-node1 -m systemd -a "name=patroni state=started" -b
~~~

### Плановое переключение

~~~bash
ansible pg-node1 -m shell -a "patronictl -c /etc/patroni/patroni.yml switchover --leader <current> --candidate <target> --force"
~~~

