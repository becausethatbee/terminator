# Ansible: Установка и управление удаленными серверами

Установка Ansible на Debian 12 и настройка управления удаленными серверами через SSH с использованием аутентификации по ключам.

## Предварительные требования

- Debian 12 на управляющей машине
- SSH доступ к удаленному серверу
- Права sudo на обеих системах

---

## Установка Ansible

### Установка из стандартных репозиториев

Обновление индекса пакетов:

```bash
sudo apt update
```

Установка пакета:

```bash
sudo apt install -y ansible
```

Проверка версии:

```bash
ansible --version
```

### Установка из официального PPA

Установка для получения актуальной версии:

```bash
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

### Установка на других дистрибутивах

CentOS/RHEL:

```bash
sudo yum install epel-release -y
sudo yum install ansible -y
```

openSUSE:

```bash
sudo zypper install ansible
```

---

## Настройка SSH

### Генерация SSH-ключей

```bash
ssh-keygen -t rsa -b 4096 -C "ansible-key"
```

Генерируется пара ключей RSA 4096 бит.

### Копирование публичного ключа

```bash
ssh-copy-id <USERNAME>@<SERVER_IP>
```

Публичный ключ копируется на удаленный сервер.

### Проверка подключения

```bash
ssh <USERNAME>@<SERVER_IP>
```

---

## Конфигурация Ansible

### Inventory файл

Создание `inventory.yml`:

```yaml
all:
  children:
    servers:
      hosts:
        production_server:
          ansible_host: <SERVER_IP>
          ansible_user: <USERNAME>
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
          ansible_python_interpreter: /usr/bin/python3
          
      vars:
        ansible_ssh_common_args: >-
          -o ConnectTimeout=30
          -o ServerAliveInterval=60
          -o ServerAliveCountMax=3
          
  vars:
    ansible_ssh_common_args: -o StrictHostKeyChecking=no
```

Структура определяет группы хостов и параметры подключения.

### Конфигурация для localhost

Создание простого inventory для локального управления:

```bash
echo "localhost ansible_connection=local" > ~/inventory.ini
```

### Файл ansible.cfg

```ini
[defaults]
inventory = inventory.yml
host_key_checking = False
timeout = 30
deprecation_warnings = False
transport = ssh

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -o ConnectTimeout=30 -o ServerAliveInterval=60
pipelining = True
```

Конфигурация определяет поведение Ansible по умолчанию.

---

## Проверка подключения

### Ping тест

Проверка доступности всех хостов:

```bash
ansible all -m ping
```

Проверка конкретного сервера:

```bash
ansible production_server -m ping
```

Успешный результат:

```json
production_server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Проверка localhost

```bash
ansible all -i ~/inventory.ini -m ping
```

---

## Ad-hoc команды

### Системная информация

Дистрибутив:

```bash
ansible production_server -m setup -a "filter=ansible_distribution*"
```

Версия ядра:

```bash
ansible production_server -m command -a "uname -a"
```

Uptime:

```bash
ansible production_server -m command -a "uptime"
```

### Сетевые настройки

Все интерфейсы:

```bash
ansible production_server -m command -a "ip addr show"
```

IP адреса:

```bash
ansible production_server -m shell -a "hostname -I"
```

Внешний IP:

```bash
ansible production_server -m shell -a "curl -s ifconfig.me"
```

Открытые порты:

```bash
ansible production_server -m shell -a "ss -tuln"
```

TCP порты:

```bash
ansible production_server -m shell -a "ss -tln"
```

### Пользователи и процессы

Пользователи с shell:

```bash
ansible production_server -m shell -a "cat /etc/passwd | grep -E '/bin/(bash|sh)$'"
```

Залогиненные пользователи:

```bash
ansible production_server -m command -a "who"
```

Топ процессов по CPU:

```bash
ansible production_server -m shell -a "ps aux --sort=-%cpu | head -10"
```

Docker процессы:

```bash
ansible production_server -m shell -a "ps aux | grep docker"
```

### Использование ресурсов

Память:

```bash
ansible production_server -m command -a "free -h"
```

Дисковое пространство:

```bash
ansible production_server -m command -a "df -h"
```

Загрузка системы:

```bash
ansible production_server -m shell -a "cat /proc/loadavg"
```

### Docker контейнеры

Запущенные контейнеры:

```bash
ansible production_server -m shell -a "docker ps"
```

Все контейнеры:

```bash
ansible production_server -m shell -a "docker ps -a"
```

Статистика ресурсов:

```bash
ansible production_server -m shell -a "docker stats --no-stream"
```

Логи контейнера:

```bash
ansible production_server -m shell -a "docker logs <CONTAINER_NAME> --tail 20"
```

Информация Docker:

```bash
ansible production_server -m shell -a "docker system df"
```

### Логи и мониторинг

Системные логи:

```bash
ansible production_server -m shell -a "tail -20 /var/log/messages"
```

Логи аутентификации:

```bash
ansible production_server -m shell -a "tail -20 /var/log/auth.log"
```

Статус службы:

```bash
ansible production_server -m shell -a "systemctl status docker"
```

Активные службы:

```bash
ansible production_server -m shell -a "systemctl list-units --type=service --state=running"
```

---

## Практические примеры

### Комплексная диагностика

```bash
ansible production_server -m shell -a "echo 'System Info:' && uname -a && echo 'Uptime:' && uptime && echo 'Memory:' && free -h && echo 'Disk:' && df -h / && echo 'Docker:' && docker ps"
```

### Мониторинг Docker

```bash
ansible production_server -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

### Последние попытки входа

```bash
ansible production_server -m shell -a "last -10"
```

### Fail2ban статус

```bash
ansible production_server -m shell -a "fail2ban-client status sshd" --ignore-errors
```

---

## Опции ad-hoc команд

| Опция | Описание |
|-------|----------|
| `-m module_name` | Модуль для выполнения |
| `-a "arguments"` | Аргументы модуля |
| `-i inventory` | Путь к inventory файлу |
| `--become` | Эскалация привилегий |
| `--limit host_name` | Ограничение хостов |
| `--ignore-errors` | Игнорирование ошибок |
| `-v, -vv, -vvv` | Уровень детализации |

Примеры использования опций:

```bash
ansible production_server -m shell -a "netstat -tulpn" --become
```

```bash
ansible production_server -m ping -vvv
```

```bash
ansible production_server -m shell -a "service nginx status" --ignore-errors
```

---

## Основные модули

| Модуль | Описание | Пример |
|--------|----------|--------|
| `ping` | Проверка доступности | `ansible all -m ping` |
| `command` | Выполнение команд | `ansible all -m command -a "uptime"` |
| `shell` | Выполнение через shell | `ansible all -m shell -a "ps aux \| grep nginx"` |
| `setup` | Сбор фактов | `ansible all -m setup` |
| `copy` | Копирование файлов | `ansible all -m copy -a "src=/path dest=/path"` |
| `file` | Управление файлами | `ansible all -m file -a "path=/path state=touch"` |
| `service` | Управление службами | `ansible all -m service -a "name=nginx state=started"` |

---

## Troubleshooting

### Permission denied (publickey)

**Ошибка:**
```
Permission denied (publickey)
```

**Причина:** SSH-ключ не добавлен в ssh-agent.

**Решение:**

Проверка загруженных ключей:

```bash
ssh-add -l
```

Добавление ключа:

```bash
ssh-add ~/.ssh/id_rsa
```

### Host unreachable

**Ошибка:**
```
Host unreachable
```

**Причина:** Сервер недоступен по сети.

**Решение:**

Проверка доступности:

```bash
ping <SERVER_IP>
```

Проверка SSH порта:

```bash
telnet <SERVER_IP> 22
```

### Failed to import Python library

**Ошибка:**
```
Failed to import Python library
```

**Причина:** Отсутствуют необходимые Python библиотеки.

**Решение:**

```bash
ansible production_server -m shell -a "pip3 install requests docker" --become
```

---

## Best Practices

- Использовать SSH-ключи вместо паролей
- Настроить ansible.cfg для проекта
- Применять группы хостов в inventory
- Использовать модуль command для простых команд без shell
- Включить pipelining для ускорения выполнения
- Отключить host_key_checking для автоматизации
- Использовать --check для dry-run режима
- Применять --limit для тестирования на подмножестве хостов

---

## Полезные команды

### Информация о хосте

```bash
ansible <HOST> -m setup
```

### Список хостов

```bash
ansible all --list-hosts
```

### Сбор фактов

```bash
ansible <HOST> -m setup -a "filter=ansible_os_family"
```

### Копирование файлов

```bash
ansible <HOST> -m copy -a "src=/local/path dest=/remote/path"
```

### Управление службами

```bash
ansible <HOST> -m service -a "name=nginx state=restarted" --become
```

### Установка пакетов

```bash
ansible <HOST> -m apt -a "name=nginx state=present" --become
```

### Выполнение с повышенными привилегиями

```bash
ansible <HOST> -m command -a "systemctl restart nginx" --become
```
