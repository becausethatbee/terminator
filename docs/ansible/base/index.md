# Ansible: Базовое подключение к удаленному серверу и ad-hoc команды

Практическое руководство по настройке Ansible для управления одним удаленным сервером с использованием SSH-ключей и выполнением простых административных задач.

## Предварительные требования

- Локальная машина с установленным Ansible
- Удаленный сервер с SSH доступом
- SSH-ключи для аутентификации

## Шаг 1: Установка Ansible

### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install ansible -y
```

### CentOS/RHEL:
```bash
sudo yum install epel-release -y
sudo yum install ansible -y
```

### openSUSE:
```bash
sudo zypper install ansible
```

### Проверка установки:
```bash
ansible --version
```

## Шаг 2: Подготовка SSH-подключения

### Создание SSH-ключей (если не созданы):
```bash
ssh-keygen -t rsa -b 4096 -C "ansible-key-for-server"
```

### Копирование публичного ключа на сервер:
```bash
ssh-copy-id user@server-ip
```

### Проверка подключения:
```bash
ssh user@server-ip
```

## Шаг 3: Создание inventory файла

Создайте файл `inventory.yml` с конфигурацией вашего сервера:

```yaml
# inventory.yml
all:
  children:
    servers:
      hosts:
        production_server:
          ansible_host: YOUR_SERVER_IP
          ansible_user: USERNAME
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
          ansible_python_interpreter: /usr/bin/python3
          
      vars:
        ansible_ssh_common_args: >-
          -o ConnectTimeout=30
          -o ServerAliveInterval=60
          -o ServerAliveCountMax=3
          
  vars:
    # Только для обучения! В продакшене используйте StrictHostKeyChecking=yes
    ansible_ssh_common_args: -o StrictHostKeyChecking=no
```

## Шаг 4: Базовая конфигурация Ansible

Создайте файл `ansible.cfg` в директории проекта:

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

## Шаг 5: Проверка подключения

### Ping тест:
```bash
ansible all -m ping
```

**Ожидаемый результат:**
```json
production_server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Подключение к конкретному серверу:
```bash
ansible production_server -m ping
```

## Шаг 6: Ad-hoc команды для системного администрирования

### Системная информация

#### Информация об операционной системе:
```bash
ansible production_server -m setup -a "filter=ansible_distribution*"
```

#### Версия ядра и архитектура:
```bash
ansible production_server -m command -a "uname -a"
```

#### Время работы сервера:
```bash
ansible production_server -m command -a "uptime"
```

### Сетевые настройки

#### Проверка IP-адресов:
```bash
# Все сетевые интерфейсы
ansible production_server -m command -a "ip addr show"

# Краткая информация об IP
ansible production_server -m shell -a "hostname -I"

# Внешний IP адрес
ansible production_server -m shell -a "curl -s ifconfig.me"
```

#### Открытые порты:
```bash
# Все открытые порты
ansible production_server -m shell -a "ss -tuln"

# Только TCP порты в режиме прослушивания
ansible production_server -m shell -a "ss -tln"
```

### Пользователи и процессы

#### Список пользователей системы:
```bash
# Все пользователи
ansible production_server -m shell -a "cat /etc/passwd"

# Только пользователи с shell
ansible production_server -m shell -a "cat /etc/passwd | grep -E '/bin/(bash|sh)$'"

# Залогиненные пользователи
ansible production_server -m command -a "who"
```

#### Системные процессы:
```bash
# Топ процессов по использованию CPU
ansible production_server -m shell -a "ps aux --sort=-%cpu | head -10"

# Процессы Docker
ansible production_server -m shell -a "ps aux | grep docker"
```

### Использование ресурсов

#### Память:
```bash
ansible production_server -m command -a "free -h"
```

#### Дисковое пространство:
```bash
ansible production_server -m command -a "df -h"
```

#### Загрузка системы:
```bash
ansible production_server -m shell -a "cat /proc/loadavg"
```

### Docker контейнеры

#### Список запущенных контейнеров:
```bash
ansible production_server -m shell -a "docker ps"
```

#### Все контейнеры (включая остановленные):
```bash
ansible production_server -m shell -a "docker ps -a"
```

#### Статистика использования ресурсов контейнерами:
```bash
ansible production_server -m shell -a "docker stats --no-stream"
```

#### Логи конкретного контейнера:
```bash
ansible production_server -m shell -a "docker logs nginx_container --tail 20"
```

#### Информация о Docker системе:
```bash
ansible production_server -m shell -a "docker system df"
```

### Логи и мониторинг

#### Системные логи:
```bash
# Последние записи в syslog
ansible production_server -m shell -a "tail -20 /var/log/messages"

# Логи аутентификации
ansible production_server -m shell -a "tail -20 /var/log/auth.log"
```

#### Статус служб:
```bash
# Статус конкретной службы
ansible production_server -m shell -a "systemctl status docker"

# Список активных служб
ansible production_server -m shell -a "systemctl list-units --type=service --state=running"
```

## Практические примеры использования

### Быстрая диагностика сервера:
```bash
# Комплексная проверка одной командой
ansible production_server -m shell -a "echo 'System Info:' && uname -a && echo 'Uptime:' && uptime && echo 'Memory:' && free -h && echo 'Disk:' && df -h / && echo 'Docker:' && docker ps"
```

### Мониторинг Docker контейнеров:
```bash
# Проверка здоровья всех контейнеров
ansible production_server -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

### Проверка безопасности:
```bash
# Последние попытки входа
ansible production_server -m shell -a "last -10"

# Заблокированные IP (если установлен fail2ban)
ansible production_server -m shell -a "fail2ban-client status sshd" --ignore-errors
```

## Полезные опции для ad-hoc команд

### Основные параметры:

- `-m module_name` - указать модуль Ansible
- `-a "arguments"` - аргументы для модуля
- `--become` - выполнить с правами sudo
- `--limit host_name` - ограничить выполнение конкретным хостом
- `--ignore-errors` - игнорировать ошибки и продолжить
- `-v, -vv, -vvv` - уровень детализации вывода

### Примеры с дополнительными опциями:
```bash
# Выполнение с повышенными правами
ansible production_server -m shell -a "netstat -tulpn" --become

# Детальный вывод для отладки
ansible production_server -m ping -vvv

# Игнорирование ошибок
ansible production_server -m shell -a "service nginx status" --ignore-errors
```

## Основные модули Ansible для ad-hoc команд

| Модуль | Описание | Пример использования |
|--------|----------|---------------------|
| `ping` | Проверка доступности | `ansible all -m ping` |
| `command` | Выполнение простых команд | `ansible all -m command -a "uptime"` |
| `shell` | Выполнение через shell | `ansible all -m shell -a "ps aux | grep nginx"` |
| `setup` | Сбор системных фактов | `ansible all -m setup` |
| `copy` | Копирование файлов | `ansible all -m copy -a "src=/path/file dest=/path/file"` |
| `file` | Управление файлами/папками | `ansible all -m file -a "path=/path/file state=touch"` |
| `service` | Управление службами | `ansible all -m service -a "name=nginx state=started"` |

## Troubleshooting

### Частые проблемы и решения:

#### Проблема: "Permission denied (publickey)"
**Решение:**
```bash
# Проверьте SSH ключи
ssh-add -l
# Добавьте ключ, если необходимо
ssh-add ~/.ssh/id_rsa
```

#### Проблема: "Host unreachable" или "Connection timeout"
**Решение:**
```bash
# Проверьте сетевую доступность
ping your-server-ip
# Проверьте SSH порт
telnet your-server-ip 22
```

#### Проблема: "Failed to import required Python library"
**Решение:**
```bash
# Установите необходимые Python пакеты на удаленном сервере
ansible production_server -m shell -a "pip3 install requests docker" --become
```


