# Исправления kubespray justfile

Корректировка команд автоматизации kubespray для надежной работы с Terraform backend и Ansible playbooks.

---

## Исправление команды check

### Проблема

Исходная реализация:
```makefile
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking cluster status..."
    source venv/bin/activate
    CONTROL_IP=$(grep -A 1 "kube_control_plane:" inventory/mycluster/hosts.yaml | grep -v "kube_control_plane:" | head -1 | awk '{print $1}' | tr -d ' ')
    BASTION_IP=$(grep "ansible_ssh_common_args:" inventory/mycluster/hosts.yaml | grep -oP 'ubuntu@\K[0-9.]+' | head -1)
    echo "Connecting to control plane via bastion..."
    ssh -J ubuntu@$BASTION_IP ubuntu@$(grep "$CONTROL_IP:" inventory/mycluster/hosts.yaml -A 1 | grep "ansible_host:" | awk '{print $2}') "kubectl get nodes"
```

**Симптомы:**
- Ошибка парсинга IP из inventory
- `channel 0: open failed: connect failed`
- Переменные остаются пустыми

**Причина:** Сложный парсинг YAML через grep/awk ненадежен, различные форматы inventory ломают логику.

### Решение

Упрощенная реализация с Terraform integration:
```makefile
# Check cluster status
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking cluster status..."
    source venv/bin/activate
    # Get bastion IP from Terraform
    cd ../terraform
    source .env
    BASTION_IP=$(terraform output -json bastion_ip | jq -r '.external_ip')
    echo "Bastion IP: $BASTION_IP"
    echo "Connecting to first control plane node..."
    ssh -J ubuntu@$BASTION_IP ubuntu@10.10.0.10 "kubectl get nodes"
```

**Изменения:**
- Terraform outputs как source of truth для bastion IP
- Hardcoded первая control plane IP (10.10.0.10) - стабильно при использовании Terraform
- Загрузка .env для S3 backend credentials
- Вывод bastion IP для диагностики

**Обоснование:**
- Terraform state содержит актуальные IP адреса
- Первая control plane нода всегда 10.10.0.10 (Terraform subnet allocation)
- jq парсинг JSON надежнее grep парсинга YAML
- source .env необходим для доступа к remote state в S3

### Валидация

Тестирование исправленной команды:
```bash
cd ~/k8s-yandex-cloud/kubespray
just check
```

Ожидаемый вывод:
```
Checking cluster status...
Bastion IP: 158.160.203.219
Connecting to first control plane node...
NAME            STATUS   ROLES           AGE    VERSION
k8s-control-1   Ready    control-plane   3h8m   v1.33.5
k8s-control-2   Ready    control-plane   3h7m   v1.33.5
k8s-control-3   Ready    control-plane   3h7m   v1.33.5
k8s-worker-1    Ready    <none>          3h7m   v1.33.5
...
```

---

## Исправление команды setup-kubeconfig

### Проблема

Исходная реализация:
```makefile
setup-kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Setting up kubeconfig on control plane nodes..."
    source venv/bin/activate
    ansible control_plane -i inventory/mycluster/hosts.yaml --become -m shell -a "mkdir -p /home/ubuntu/.kube"
    ansible control_plane -i inventory/mycluster/hosts.yaml --become -m copy -a "src=/etc/kubernetes/admin.conf dest=/home/ubuntu/.kube/config remote_src=yes owner=ubuntu group=ubuntu mode=0600"
    echo "Kubeconfig configured on all control plane nodes"
```

**Симптомы:**
- Команда выполняется без ошибок
- Kubeconfig не настраивается корректно
- kubectl не работает на control plane нодах

**Причина:** Ad-hoc Ansible команды через `-m` не гарантируют порядок выполнения и не валидируют результат. Отсутствует проверка что kubectl работает после копирования config.

### Решение

Создание dedicated Ansible playbook:

Структура:
```bash
mkdir -p ~/k8s-yandex-cloud/kubespray/playbooks
```

Playbook `playbooks/kubeconfig-setup.yml`:
```yaml
---
- name: Setup kubeconfig for ubuntu user on control plane nodes
  hosts: kube_control_plane
  become: true
  tasks:
    - name: Create .kube directory
      ansible.builtin.file:
        path: /home/ubuntu/.kube
        state: directory
        owner: ubuntu
        group: ubuntu
        mode: '0755'

    - name: Copy admin.conf to user kubeconfig
      ansible.builtin.copy:
        src: /etc/kubernetes/admin.conf
        dest: /home/ubuntu/.kube/config
        remote_src: true
        owner: ubuntu
        group: ubuntu
        mode: '0600'

    - name: Verify kubectl works
      ansible.builtin.command: kubectl get nodes
      become: false
      register: kubectl_result
      changed_when: false

    - name: Display cluster status
      ansible.builtin.debug:
        var: kubectl_result.stdout_lines
```

Playbook реализует:
- Идемпотентность через `state: directory` и `copy` module
- Правильные permissions (0755 для директории, 0600 для config)
- Валидация через `kubectl get nodes`
- Вывод результата для подтверждения

Обновление justfile команды:
```makefile
# Setup kubeconfig on control plane nodes
setup-kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Setting up kubeconfig on control plane nodes..."
    source venv/bin/activate
    ansible-playbook -i inventory/mycluster/hosts.yaml playbooks/kubeconfig-setup.yml
```

**Преимущества playbook подхода:**
- Декларативное описание desired state
- Встроенная валидация результата
- Структурированный вывод с timing
- Легко расширяется (добавить tasks)
- Реиспользуемый (можно вызвать отдельно)

### Валидация

Тестирование:
```bash
cd ~/k8s-yandex-cloud/kubespray
just setup-kubeconfig
```

Ожидаемый вывод:
```
Setting up kubeconfig on control plane nodes...

PLAY [Setup kubeconfig for ubuntu user on control plane nodes] *********

TASK [Gathering Facts] *************************************************
ok: [k8s-control-1]
ok: [k8s-control-2]
ok: [k8s-control-3]

TASK [Create .kube directory] ******************************************
changed: [k8s-control-1]
changed: [k8s-control-2]
changed: [k8s-control-3]

TASK [Copy admin.conf to user kubeconfig] ******************************
changed: [k8s-control-1]
changed: [k8s-control-2]
changed: [k8s-control-3]

TASK [Verify kubectl works] ********************************************
ok: [k8s-control-1]
ok: [k8s-control-2]
ok: [k8s-control-3]

TASK [Display cluster status] ******************************************
ok: [k8s-control-1] => {
    "kubectl_result.stdout_lines": [
        "NAME            STATUS   ROLES           AGE    VERSION",
        "k8s-control-1   Ready    control-plane   3h8m   v1.33.5",
        ...
    ]
}

PLAY RECAP *************************************************************
k8s-control-1              : ok=5    changed=2    unreachable=0    failed=0
k8s-control-2              : ok=5    changed=2    unreachable=0    failed=0
k8s-control-3              : ok=5    changed=2    unreachable=0    failed=0
```

Проверка на control plane ноде:
```bash
ssh -J ubuntu@<BASTION_IP> ubuntu@10.10.0.10
kubectl get nodes
```

Должно работать без ошибок.

---

## Полный justfile

Финальная версия с исправлениями:
```makefile
# Kubespray automation commands

default:
    @echo "Kubespray Deployment Commands"
    @echo "=============================="
    @echo ""
    @echo "DEPLOYMENT:"
    @echo "  deploy           Full cluster deployment (~30 min)"
    @echo "  deploy-check     Deploy with syntax check first"
    @echo "  reset            Reset cluster (delete all)"
    @echo ""
    @echo "POST-DEPLOY:"
    @echo "  setup-kubeconfig Configure kubeconfig on control plane nodes"
    @echo "  check            Check cluster status"
    @echo ""
    @echo "MAINTENANCE:"
    @echo "  upgrade          Upgrade cluster"
    @echo "  scale            Scale worker nodes"

# Activate venv and deploy cluster
deploy:
    @echo "Starting kubespray deployment..."
    source venv/bin/activate && \
    ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root cluster.yml

# Check syntax before deploy
deploy-check:
    @echo "Checking playbook syntax..."
    source venv/bin/activate && \
    ansible-playbook -i inventory/mycluster/hosts.yaml --syntax-check cluster.yml && \
    just deploy

# Reset cluster
reset:
    @echo "WARNING: This will destroy the cluster!"
    @echo "Press Ctrl+C to cancel, Enter to continue..."
    @read confirm
    source venv/bin/activate && \
    ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root reset.yml

# Setup kubeconfig on control plane nodes
setup-kubeconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Setting up kubeconfig on control plane nodes..."
    source venv/bin/activate
    ansible-playbook -i inventory/mycluster/hosts.yaml playbooks/kubeconfig-setup.yml

# Check cluster status
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking cluster status..."
    source venv/bin/activate
    cd ../terraform
    source .env
    BASTION_IP=$(terraform output -json bastion_ip | jq -r '.external_ip')
    echo "Bastion IP: $BASTION_IP"
    echo "Connecting to first control plane node..."
    ssh -J ubuntu@$BASTION_IP ubuntu@10.10.0.10 "kubectl get nodes"

# Upgrade cluster
upgrade:
    @echo "Upgrading cluster..."
    source venv/bin/activate && \
    ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root upgrade-cluster.yml

# Scale workers
scale:
    @echo "Scaling cluster..."
    source venv/bin/activate && \
    ansible-playbook -i inventory/mycluster/hosts.yaml --become --become-user=root scale.yml
```

---

## Применение исправлений

### Обновление существующего justfile

Если justfile уже существует:
```bash
cd ~/k8s-yandex-cloud/kubespray
nano justfile
```

Замените секции `setup-kubeconfig` и `check` на исправленные версии.

### Создание playbook directory
```bash
mkdir -p ~/k8s-yandex-cloud/kubespray/playbooks
```

Создание kubeconfig-setup.yml playbook (содержимое выше).

### Коммит изменений
```bash
cd ~/k8s-yandex-cloud/kubespray
git add justfile playbooks/kubeconfig-setup.yml
git commit -m "fix: kubespray automation commands

- check: use Terraform outputs for bastion IP
- check: hardcode first control plane IP (10.10.0.10)
- setup-kubeconfig: migrate to dedicated Ansible playbook
- setup-kubeconfig: add kubectl validation step"
```

---

## Troubleshooting

### Terraform output error: credential sources

**Симптомы:**
- `just check` возвращает credential error
- Terraform не может прочитать remote state

**Ошибка:**
```
Error: No valid credential sources found
Please see https://www.terraform.io/docs/language/settings/backends/s3.html
```

**Причина:** .env файл не загружен, AWS credentials отсутствуют для S3 backend.

**Решение:**

Проверка .env в terraform директории:
```bash
cd ~/k8s-yandex-cloud/terraform
cat .env
```

Должен содержать:
```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_ENDPOINT_URL_S3=https://storage.yandexcloud.net
```

Загрузка вручную:
```bash
source .env
terraform output -json bastion_ip
```

**Проверка:**
```bash
just check
```

### Ansible playbook not found

**Симптомы:**
- `just setup-kubeconfig` возвращает file not found
- Playbook отсутствует

**Ошибка:**
```
ERROR! the playbook: playbooks/kubeconfig-setup.yml could not be found
```

**Причина:** Playbook файл не создан или находится в неправильной директории.

**Решение:**

Проверка наличия файла:
```bash
ls -la ~/k8s-yandex-cloud/kubespray/playbooks/
```

Создание если отсутствует:
```bash
mkdir -p ~/k8s-yandex-cloud/kubespray/playbooks
# Создать kubeconfig-setup.yml с содержимым из документации
```

**Проверка:**
```bash
ansible-playbook --syntax-check -i inventory/mycluster/hosts.yaml playbooks/kubeconfig-setup.yml
```

### SSH connection refused через bastion

**Симптомы:**
- `just check` не может подключиться к control plane
- Connection refused или timeout

**Причина:** SSH agent forwarding не настроен или firewall блокирует.

**Решение:**

Проверка SSH connectivity:
```bash
ssh -J ubuntu@<BASTION_IP> ubuntu@10.10.0.10 echo "Connection OK"
```

Добавление SSH key в agent (если нужен):
```bash
eval $(ssh-agent)
ssh-add ~/.ssh/id_rsa
```

Проверка firewall на bastion:
```bash
ssh ubuntu@<BASTION_IP> "sudo iptables -L -n | grep 10.10.0.10"
```

**Проверка:**
```bash
just check
```

### Kubectl get nodes: connection refused

**Симптомы:**
- Playbook выполнен успешно
- kubectl возвращает connection refused на control plane

**Ошибка:**
```
The connection to the server localhost:8080 was refused
```

**Причина:** Kubeconfig не настроен или неправильные permissions.

**Решение:**

Проверка на control plane ноде:
```bash
ssh -J ubuntu@<BASTION_IP> ubuntu@10.10.0.10
ls -la ~/.kube/config
cat ~/.kube/config | grep server:
```

Server должен указывать на API server (не localhost:8080).

Ручная настройка:
```bash
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown ubuntu:ubuntu ~/.kube/config
chmod 600 ~/.kube/config
```

**Проверка:**
```bash
kubectl get nodes
```

---

## Best Practices

**Justfile Commands:**
- Использовать `#!/usr/bin/env bash` и `set -euo pipefail` для shell scripts
- Выводить diagnostic информацию (echo "Step X...")
- Проверять prerequisites перед выполнением
- Документировать команды в default target
- Группировать related команды логически

**Ansible Integration:**
- Предпочитать playbooks вместо ad-hoc команд для сложных операций
- Использовать `changed_when: false` для idempotent checks
- Добавлять validation tasks после critical operations
- Структурировать playbooks в отдельной директории
- Тестировать playbooks через --syntax-check

**Terraform Integration:**
- Использовать Terraform outputs как source of truth для IPs
- Загружать credentials через source .env
- Обрабатывать JSON outputs через jq
- Документировать зависимости между Terraform и Ansible
- Версионировать outputs в remote state

**SSH Connectivity:**
- Использовать ProxyJump (-J) для bastion access
- Добавлять diagnostic вывод (bastion IP, target IP)
- Тестировать connectivity перед автоматизацией
- Документировать network topology
- Использовать SSH config для упрощения

**Error Handling:**
- Добавлять validation после critical steps
- Выводить meaningful error messages
- Использовать exit codes для script chaining
- Документировать troubleshooting steps
- Тестировать edge cases

---

## Интеграция с workflow

### Post-deployment workflow

После `terraform apply`:
```bash
cd ~/k8s-yandex-cloud/terraform
just apply-auto

cd ~/k8s-yandex-cloud/kubespray
just deploy           # Deploy кластера (~30 min)
just setup-kubeconfig # Настройка kubectl на control plane
just check            # Валидация что всё работает
```

### Regular maintenance

Проверка статуса кластера:
```bash
cd ~/k8s-yandex-cloud/kubespray
just check
```

Обновление кластера:
```bash
just upgrade
```

Масштабирование workers:
```bash
# Обновить inventory с новыми worker нодами
just scale
```

### Disaster recovery

Полное пересоздание:
```bash
cd ~/k8s-yandex-cloud/kubespray
just reset  # Удаление K8s

cd ~/k8s-yandex-cloud/terraform
just destroy-auto  # Удаление инфраструктуры

just apply-auto    # Пересоздание инфраструктуры

cd ~/k8s-yandex-cloud/kubespray
just deploy        # Пересоздание кластера
just setup-kubeconfig
just check
```

---

## Полезные команды

### Justfile Management
```bash
# Список доступных команд
just --list

# Выполнение команды
just <command>

# Dry-run (показать что будет выполнено)
just --dry-run <command>

# Verbose вывод
just --verbose <command>
```

### Debugging Justfile
```bash
# Проверка синтаксиса
just --evaluate

# Показать переменные
just --show <command>

# Запуск с debug
just --debug <command>
```

### Testing Playbooks
```bash
# Syntax check
ansible-playbook --syntax-check playbooks/kubeconfig-setup.yml

# Check mode (dry-run)
ansible-playbook -i inventory/mycluster/hosts.yaml --check playbooks/kubeconfig-setup.yml

# Diff mode
ansible-playbook -i inventory/mycluster/hosts.yaml --diff playbooks/kubeconfig-setup.yml

# Limit to specific hosts
ansible-playbook -i inventory/mycluster/hosts.yaml --limit k8s-control-1 playbooks/kubeconfig-setup.yml

# Verbose output
ansible-playbook -i inventory/mycluster/hosts.yaml -vvv playbooks/kubeconfig-setup.yml
```
