# Ansible: Ad-hoc команды для проверки пакетов

Полное руководство по использованию ad-hoc команд Ansible для быстрой проверки пакетов, диагностики систем и выполнения разовых задач без создания playbooks.


## Введение в ad-hoc команды


### Что такое ad-hoc команды?

Ad-hoc команды в Ansible - это **быстрые одноразовые команды** для выполнения простых задач без необходимости создания playbook. Они идеальны для:

- Быстрой диагностики систем
- Проверки конфигураций
- Выполнения простых операций
- Тестирования подключений
- Сбора информации о системах

### Когда использовать ad-hoc команды?

**Используйте ad-hoc для:**
- Разовых проверок и диагностики
- Быстрого сбора информации
- Тестирования модулей
- Проверки доступности хостов
- Простых операций на множестве серверов

**Не используйте ad-hoc для:**
- Сложной автоматизации (используйте playbooks)
- Задач, требующих последовательности действий
- Конфигураций, которые нужно повторять
- Задач с обработкой ошибок и условиями

---

## Синтаксис и структура

### Базовый синтаксис

```bash
ansible [паттерн_хостов] [опции] -m [модуль] -a "[аргументы_модуля]"
```

### Структура команды

```
ansible all -i inventory.ini -m ping -b --become-user=root
│       │   │                │      │   │
│       │   │                │      │   └─ Пользователь для повышения привилегий
│       │   │                │      └───── Использовать повышение привилегий (sudo)
│       │   │                └──────────── Модуль для выполнения
│       │   └───────────────────────────── Файл инвентаря
│       └───────────────────────────────── Паттерн хостов (all, webservers, host1)
└───────────────────────────────────────── Команда ansible
```

### Простейший пример

```bash
# Проверка доступности всех хостов
ansible all -m ping

# Вывод:
# host1 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

---

## Проверка пакетов

### 1. Универсальные методы проверки

#### Модуль package_facts

Собирает информацию об установленных пакетах:

```bash
# Базовый сбор информации о пакетах
ansible all -m package_facts

# Сбор с указанием менеджера пакетов
ansible all -m package_facts -a "manager=auto"

# С выводом в JSON
ansible all -m package_facts | jq
```

**Вывод содержит:**
```json
{
    "ansible_facts": {
        "packages": {
            "nginx": [
                {
                    "name": "nginx",
                    "version": "1.18.0",
                    "release": "0ubuntu1.4",
                    "source": "apt"
                }
            ]
        }
    }
}
```

#### Проверка через shell команды

```bash
# Универсальная проверка пакета
ansible all -m shell -a "which nginx && nginx -v 2>&1 || echo 'not installed'"

# Проверка нескольких пакетов
ansible all -m shell -a "for pkg in nginx git curl; do echo -n \"$pkg: \"; command -v $pkg >/dev/null && echo 'installed' || echo 'not installed'; done"

# С sudo
ansible all -m shell -a "dpkg -l | grep nginx || rpm -qa | grep nginx" -b
```

### 2. Debian/Ubuntu (APT)

#### Проверка установлен ли пакет

```bash
# Базовая проверка
ansible all -m shell -a "dpkg -l | grep nginx"

# Проверка статуса пакета
ansible all -m shell -a "dpkg -s nginx"

# Короткий вывод
ansible all -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' nginx"

# Список установленных пакетов
ansible all -m shell -a "dpkg --get-selections | grep -v deinstall"
```

#### Получение информации о пакете

```bash
# Детальная информация
ansible all -m shell -a "apt-cache show nginx"

# Только версия
ansible all -m shell -a "dpkg -s nginx | grep Version"

# Файлы пакета
ansible all -m shell -a "dpkg -L nginx"

# Зависимости
ansible all -m shell -a "apt-cache depends nginx"
```

#### Проверка доступных обновлений

```bash
# Обновить кэш и проверить обновления
ansible all -m apt -a "update_cache=yes" -b

# Проверить доступные обновления для пакета
ansible all -m shell -a "apt list --upgradable 2>/dev/null | grep nginx"

# Показать changelog
ansible all -m shell -a "apt-get changelog nginx 2>/dev/null | head -20"
```

#### Поиск пакетов

```bash
# Поиск пакета по имени
ansible all -m shell -a "apt-cache search '^nginx'"

# Поиск по описанию
ansible all -m shell -a "apt-cache search 'web server'"

# Поиск с дополнительной информацией
ansible all -m shell -a "apt-cache search nginx | head -10"
```

### 3. RHEL/CentOS/Fedora (YUM/DNF)

#### Проверка установлен ли пакет

```bash
# Базовая проверка
ansible all -m shell -a "rpm -qa | grep nginx"

# Детальная информация
ansible all -m shell -a "rpm -qi nginx"

# Короткая информация
ansible all -m shell -a "rpm -q nginx"

# Версия и релиз
ansible all -m shell -a "rpm -q --qf '%{VERSION}-%{RELEASE}\n' nginx"

# Проверка подписи
ansible all -m shell -a "rpm -q --qf '%{SIGPGP:pgpsig}\n' nginx"
```

#### Получение информации о пакете

```bash
# Информация из репозитория
ansible all -m shell -a "yum info nginx"

# Список файлов пакета
ansible all -m shell -a "rpm -ql nginx"

# Конфигурационные файлы
ansible all -m shell -a "rpm -qc nginx"

# Документация
ansible all -m shell -a "rpm -qd nginx"

# Скрипты установки
ansible all -m shell -a "rpm -q --scripts nginx"

# Зависимости
ansible all -m shell -a "rpm -qR nginx"

# Provides
ansible all -m shell -a "rpm -q --provides nginx"
```

#### Проверка обновлений

```bash
# Проверить доступные обновления
ansible all -m shell -a "yum check-update nginx" -b

# DNF проверка
ansible all -m shell -a "dnf check-update nginx" -b

# Список всех доступных обновлений
ansible all -m shell -a "yum list updates" -b
```

#### История установки

```bash
# История yum операций
ansible all -m shell -a "yum history list nginx" -b

# Детали конкретной операции
ansible all -m shell -a "yum history info last" -b

# Откат операции (осторожно!)
# ansible all -m shell -a "yum history undo last" -b
```

---

## Практические примеры

### Проверка версий пакетов

```bash
# Версия конкретного пакета на всех хостах
ansible all -m shell -a "nginx -v 2>&1" -o

# Версии нескольких пакетов
ansible all -m shell -a "echo 'Nginx:' && nginx -v 2>&1; echo 'Git:' && git --version; echo 'Python:' && python3 --version"

# С форматированным выводом
ansible all -m shell -a "printf 'Nginx: '; nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+'"

# Сравнение версий на разных хостах
ansible all -m shell -a "dpkg -s nginx | grep Version" | grep -E "Version|SUCCESS"
```

### Проверка статуса служб пакетов

```bash
# Статус службы
ansible all -m shell -a "systemctl status nginx" -b

# Только проверка активности
ansible all -m command -a "systemctl is-active nginx" -b

# Проверка автозапуска
ansible all -m command -a "systemctl is-enabled nginx" -b

# Комплексная проверка
ansible all -m shell -a "systemctl is-active nginx && systemctl is-enabled nginx" -b
```

### Массовая проверка пакетов

```bash
# Проверить список пакетов на всех хостах
ansible all -m shell -a "
for pkg in nginx apache2 mysql-server postgresql redis-server; do
  if dpkg -l | grep -q \"^ii.*$pkg\"; then
    echo \"$pkg: installed ($(dpkg -s $pkg 2>/dev/null | grep Version | awk '{print $2}'))\";
  else
    echo \"$pkg: not installed\";
  fi;
done" -o

# С использованием command
ansible all -m shell -a "dpkg -l | grep -E '^ii.*(nginx|apache|mysql|postgres)' | awk '{print $2, $3}'"
```

### Проверка безопасности пакетов

```bash
# Проверка обновлений безопасности (Ubuntu)
ansible all -m shell -a "apt list --upgradable 2>/dev/null | grep -i security"

# Проверка обновлений безопасности (RHEL/CentOS)
ansible all -m shell -a "yum updateinfo list security" -b

# Неустановленные обновления безопасности
ansible all -m shell -a "yum --security check-update" -b

# Debian security updates
ansible all -m shell -a "apt-get upgrade -s | grep -i security"
```

### Проверка конфигурационных файлов пакетов

```bash
# Список конфигурационных файлов
ansible all -m shell -a "dpkg -L nginx | grep '/etc/'"

# Измененные конфигурационные файлы
ansible all -m shell -a "debsums -c nginx"

# Проверка конфигурации nginx
ansible all -m shell -a "nginx -t" -b

# Показать конфигурацию
ansible all -m shell -a "cat /etc/nginx/nginx.conf | head -20"
```

### Поиск пакета по файлу

```bash
# Какой пакет содержит файл (Debian/Ubuntu)
ansible all -m shell -a "dpkg -S /usr/sbin/nginx"

# RHEL/CentOS
ansible all -m shell -a "rpm -qf /usr/sbin/nginx"

# Поиск по команде
ansible all -m shell -a "which nginx | xargs dpkg -S"
```

### Проверка зависимостей

```bash
# Зависимости пакета (Debian)
ansible all -m shell -a "apt-cache depends nginx | grep Depends"

# Обратные зависимости
ansible all -m shell -a "apt-cache rdepends nginx"

# RHEL/CentOS зависимости
ansible all -m shell -a "repoquery --requires nginx"

# Что требует данный пакет
ansible all -m shell -a "repoquery --whatrequires nginx"
```

### Статистика по пакетам

```bash
# Количество установленных пакетов
ansible all -m shell -a "dpkg -l | grep '^ii' | wc -l"

# Размер пакета
ansible all -m shell -a "dpkg -s nginx | grep Installed-Size"

# Топ 10 больших пакетов
ansible all -m shell -a "dpkg-query -W --showformat='\${Installed-Size}\t\${Package}\n' | sort -rn | head -10"

# Дата установки (RHEL/CentOS)
ansible all -m shell -a "rpm -q --qf '%{INSTALLTIME:date}\n' nginx"
```

### Проверка репозиториев

```bash
# Список репозиториев (Debian/Ubuntu)
ansible all -m shell -a "cat /etc/apt/sources.list"

# Активные репозитории
ansible all -m shell -a "grep -r --include '*.list' '^deb ' /etc/apt/"

# Список репозиториев (RHEL/CentOS)
ansible all -m shell -a "yum repolist"

# Детальная информация о репозиториях
ansible all -m shell -a "yum repolist -v"

# openSUSE репозитории
ansible all -m shell -a "zypper repos"
```

### Работа с логами пакетов

```bash
# Логи apt
ansible all -m shell -a "grep 'install nginx' /var/log/apt/history.log"

# Логи yum
ansible all -m shell -a "grep nginx /var/log/yum.log"

# Последние установки
ansible all -m shell -a "tail -50 /var/log/dpkg.log | grep nginx"
```

---

## Полный справочник опций

### Основные опции ansible

#### Опции подключения

| Опция | Короткая | Описание | Пример |
|-------|----------|----------|--------|
| `--inventory` | `-i` | Путь к файлу инвентаря | `-i inventory.ini` |
| `--user` | `-u` | Пользователь для подключения | `-u admin` |
| `--private-key` | `--key-file` | Путь к приватному SSH ключу | `--private-key ~/.ssh/id_rsa` |
| `--connection` | `-c` | Тип подключения | `-c ssh`, `-c local` |
| `--timeout` | `-T` | Таймаут подключения (сек) | `-T 30` |
| `--ssh-common-args` | | Дополнительные SSH аргументы | `--ssh-common-args '-o StrictHostKeyChecking=no'` |
| `--ssh-extra-args` | | Дополнительные SSH опции | `--ssh-extra-args '-o UserKnownHostsFile=/dev/null'` |

#### Повышение привилегий

| Опция | Короткая | Описание | Пример |
|-------|----------|----------|--------|
| `--become` | `-b` | Использовать become (sudo) | `-b` |
| `--become-user` | | Пользователь для become | `--become-user=root` |
| `--become-method` | | Метод become | `--become-method=sudo` |
| `--ask-become-pass` | `-K` | Запросить пароль become | `-K` |
| `--ask-pass` | `-k` | Запросить пароль SSH | `-k` |

#### Выполнение модулей

| Опция | Короткая | Описание | Пример |
|-------|----------|----------|--------|
| `--module-name` | `-m` | Имя модуля для выполнения | `-m ping` |
| `--args` | `-a` | Аргументы модуля | `-a "name=nginx state=present"` |
| `--module-path` | `-M` | Путь к кастомным модулям | `-M ./my_modules` |

#### Вывод и отладка

| Опция | Короткая | Описание | Пример |
|-------|----------|----------|--------|
| `--verbose` | `-v` | Подробный вывод | `-v`, `-vv`, `-vvv`, `-vvvv` |
| `--one-line` | `-o` | Однострочный вывод | `-o` |
| `--tree` | `-t` | Сохранить вывод в директории | `-t /tmp/output` |

#### Производительность

| Опция | Короткая | Описание | Пример |
|-------|----------|----------|--------|
| `--forks` | `-f` | Количество параллельных процессов | `-f 10` |
| `--poll` | `-P` | Интервал опроса для async задач | `-P 15` |
| `--background` | `-B` | Фоновое выполнение (сек) | `-B 3600` |

#### Фильтрация хостов

| Опция | Короткая | Описание | Пример |
|-------|----------|----------|--------|
| `--limit` | `-l` | Ограничить выполнение хостами | `-l webservers` |
| `--list-hosts` | | Показать список хостов | `--list-hosts` |

#### Дополнительные опции

| Опция | Описание | Пример |
|-------|----------|--------|
| `--check` | Dry run (не применять изменения) | `--check` |
| `--diff` | Показать различия при изменениях | `--diff` |
| `--extra-vars` | Дополнительные переменные | `-e "var=value"` |
| `--vault-id` | ID для ansible-vault | `--vault-id prod@prompt` |
| `--vault-password-file` | Файл с паролем vault | `--vault-password-file .vault_pass` |

### Полный список модулей для ad-hoc

#### Проверка системы

```bash
# Ping модуль
ansible all -m ping

# Setup (сбор фактов)
ansible all -m setup

# Сбор определенных фактов
ansible all -m setup -a "filter=ansible_distribution*"

# Фильтрация фактов
ansible all -m setup -a "filter=ansible_memtotal_mb"
```

#### Выполнение команд

```bash
# Command (без shell)
ansible all -m command -a "uptime"

# Shell (с shell функциями)
ansible all -m shell -a "ps aux | grep nginx"

# Raw (без Python)
ansible all -m raw -a "uptime"

# Script (локальный скрипт)
ansible all -m script -a "/path/to/script.sh"
```

#### Управление пакетами

```bash
# Package (универсальный)
ansible all -m package -a "name=nginx state=present" -b

# APT
ansible all -m apt -a "name=nginx state=latest update_cache=yes" -b

# YUM
ansible all -m yum -a "name=nginx state=present" -b

# DNF
ansible all -m dnf -a "name=nginx state=latest" -b

# Pip
ansible all -m pip -a "name=flask state=present"
```

#### Управление службами

```bash
# Service
ansible all -m service -a "name=nginx state=started enabled=yes" -b

# Systemd
ansible all -m systemd -a "name=nginx state=restarted daemon_reload=yes" -b
```

#### Управление файлами

```bash
# Copy
ansible all -m copy -a "src=/local/file dest=/remote/file mode=0644" -b

# File
ansible all -m file -a "path=/tmp/test state=directory mode=0755" -b

# Template
ansible all -m template -a "src=template.j2 dest=/etc/config" -b

# Fetch
ansible all -m fetch -a "src=/remote/file dest=/local/path"

# Stat
ansible all -m stat -a "path=/etc/nginx/nginx.conf"
```

#### Управление пользователями

```bash
# User
ansible all -m user -a "name=testuser state=present" -b

# Group
ansible all -m group -a "name=testgroup state=present" -b

# Authorized_key
ansible all -m authorized_key -a "user=ubuntu key='{{ lookup('file', '~/.ssh/id_rsa.pub') }}' state=present"
```

#### Работа с Git

```bash
# Clone репозитория
ansible all -m git -a "repo=https://github.com/user/repo.git dest=/opt/app version=main"
```

#### Работа с архивами

```bash
# Unarchive (распаковка)
ansible all -m unarchive -a "src=/local/archive.tar.gz dest=/remote/path" -b

# Archive (создание архива)
ansible all -m archive -a "path=/var/log/*.log dest=/tmp/logs.tar.gz" -b
```

#### Сетевые операции

```bash
# URI (HTTP запросы)
ansible all -m uri -a "url=http://example.com/api method=GET"

# Get_url (загрузка файлов)
ansible all -m get_url -a "url=https://example.com/file.tar.gz dest=/tmp/"

# Wait_for (ожидание)
ansible all -m wait_for -a "host=localhost port=80 state=started timeout=60"
```

#### Cron задачи

```bash
# Добавить cron задачу
ansible all -m cron -a "name='backup' minute=0 hour=2 job='/opt/backup.sh'" -b

# Удалить cron задачу
ansible all -m cron -a "name='backup' state=absent" -b
```

#### Системные операции

```bash
# Reboot
ansible all -m reboot -a "reboot_timeout=600" -b

# Hostname
ansible all -m hostname -a "name=newhost" -b

# Sysctl
ansible all -m sysctl -a "name=vm.swappiness value=10" -b

# Timezone
ansible all -m timezone -a "name=Europe/Moscow" -b
```

### Паттерны выбора хостов

```bash
# Все хосты
ansible all -m ping

# Конкретный хост
ansible host1 -m ping

# Группа хостов
ansible webservers -m ping

# Несколько групп
ansible 'webservers:dbservers' -m ping

# Пересечение групп (AND)
ansible 'webservers:&production' -m ping

# Исключение групп (NOT)
ansible 'webservers:!staging' -m ping

# Диапазон хостов
ansible 'web[1:5]' -m ping

# Регулярное выражение
ansible '~web.*' -m ping

# Комбинирование
ansible 'webservers:&production:!web01' -m ping
```

### Переменные окружения

```bash
# Inventory
export ANSIBLE_INVENTORY=./inventory

# Конфигурация
export ANSIBLE_CONFIG=./ansible.cfg

# Пользователь
export ANSIBLE_REMOTE_USER=admin

# Становиться пользователем
export ANSIBLE_BECOME=true
export ANSIBLE_BECOME_USER=root

# SSH опции
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_TIMEOUT=30

# Forks
export ANSIBLE_FORKS=10

# Вывод
export ANSIBLE_STDOUT_CALLBACK=yaml
export ANSIBLE_LOAD_CALLBACK_PLUGINS=true

# Логирование
export ANSIBLE_LOG_PATH=./ansible.log
```

### Практические комбинации

```bash
# Проверка с детальным выводом и сохранением в файл
ansible all -m shell -a "dpkg -l | grep nginx" -o -vv | tee check.log

# Параллельное выполнение на многих хостах
ansible all -m shell -a "apt update" -b -f 50

# С таймаутом и повторами
ansible all -m shell -a "curl -s http://api.com" -T 10 --retries 3

# Проверка только определенных хостов
ansible webservers -m package_facts --limit "web0[1-3]"

# С передачей переменных
ansible all -m shell -a "echo {{ custom_var }}" -e "custom_var=test"

# Асинхронное выполнение длительных команд
ansible all -m shell -a "apt dist-upgrade -y" -B 3600 -P 60 -b

# Сохранение вывода в файлы по хостам
ansible all -m setup --tree /tmp/facts/

# С использованием vault пароля
ansible all -m shell -a "cat /secure/file" --vault-password-file .vault_pass -b
```

---

## Лучшие практики

### 1. Производительность

```bash
# Увеличить параллелизм
ansible all -m shell -a "command" -f 50

# Использовать -o для краткого вывода
ansible all -m ping -o

# Кэширование фактов
ansible all -m setup --tree /tmp/facts/
```

### 2. Безопасность

```bash
# Не логировать чувствительные данные
ansible all -m shell -a "echo $PASSWORD" --no-log

# Использовать vault для паролей
ansible all -m shell -a "command" --vault-password-file .vault_pass

# Проверка перед выполнением
ansible all -m command -a "rm -rf /important" --check
```

### 3. Отладка

```bash
# Детальный вывод
ansible all -m shell -a "command" -vvv

# Проверка синтаксиса (для модулей с args)
ansible all -m debug -a "msg='test'" --syntax-check

# Dry run
ansible all -m apt -a "name=nginx state=latest" --check -b
```

### 4. Организация

```bash
# Использовать алиасы
alias ansible-check='ansible all -m ping -o'
alias ansible-facts='ansible all -m setup -a "filter=ansible_distribution*"'

# Сохранять часто используемые команды в скрипты
cat > check_package.sh << 'EOF'
#!/bin/bash
ansible all -m shell -a "dpkg -s $1 | grep Version" -o
EOF
chmod +x check_package.sh
```

### 5. Обработка ошибок

```bash
# Игнорировать ошибки
ansible all -m shell -a "command_that_might_fail" --ignore-errors

# Проверка возвращаемого кода
ansible all -m shell -a "test -f /etc/nginx/nginx.conf && echo exists || echo missing"

# Условное выполнение
ansible all -m shell -a "[ -f /etc/nginx/nginx.conf ] && nginx -t"
```
