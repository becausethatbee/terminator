# Ansible Ad-hoc команды

Справочник по использованию ad-hoc команд для диагностики систем, проверки пакетов и выполнения административных задач.

---

## Синтаксис

Базовая структура команды:

```bash
ansible [pattern] [options] -m [module] -a "[arguments]"
```

Компоненты:

```
ansible all -i inventory.ini -m ping -b --become-user=root
│       │   │                │      │   │
│       │   │                │      │   └─ Пользователь для эскалации привилегий
│       │   │                │      └───── Использование sudo/become
│       │   │                └──────────── Модуль для выполнения
│       │   └───────────────────────────── Файл inventory
│       └───────────────────────────────── Паттерн хостов
└───────────────────────────────────────── Команда ansible
```

Простейшая проверка доступности:

```bash
ansible all -m ping
```

---

## Проверка пакетов

### Универсальные методы

Модуль package_facts собирает информацию об установленных пакетах:

```bash
ansible all -m package_facts

ansible all -m package_facts -a "manager=auto"
```

Структура вывода:

```json
{
    "ansible_facts": {
        "packages": {
            "nginx": [{
                "name": "nginx",
                "version": "1.18.0",
                "release": "0ubuntu1.4",
                "source": "apt"
            }]
        }
    }
}
```

Проверка через shell:

```bash
ansible all -m shell -a "which nginx && nginx -v 2>&1 || echo 'not installed'"

ansible all -m shell -a "for pkg in nginx git curl; do echo -n \"$pkg: \"; command -v $pkg >/dev/null && echo 'installed' || echo 'not installed'; done"
```

### Debian/Ubuntu (APT)

Проверка статуса пакета:

```bash
ansible all -m shell -a "dpkg -l | grep nginx"

ansible all -m shell -a "dpkg -s nginx"

ansible all -m shell -a "dpkg-query -W -f='\${Status} \${Version}\n' nginx"
```

Информация о пакете:

```bash
ansible all -m shell -a "apt-cache show nginx"

ansible all -m shell -a "dpkg -s nginx | grep Version"

ansible all -m shell -a "dpkg -L nginx"

ansible all -m shell -a "apt-cache depends nginx"
```

Доступные обновления:

```bash
ansible all -m apt -a "update_cache=yes" -b

ansible all -m shell -a "apt list --upgradable 2>/dev/null | grep nginx"
```

Поиск пакетов:

```bash
ansible all -m shell -a "apt-cache search '^nginx'"

ansible all -m shell -a "apt-cache search 'web server'"
```

### RHEL/CentOS/Fedora (YUM/DNF)

Проверка установленного пакета:

```bash
ansible all -m shell -a "rpm -qa | grep nginx"

ansible all -m shell -a "rpm -qi nginx"

ansible all -m shell -a "rpm -q nginx"

ansible all -m shell -a "rpm -q --qf '%{VERSION}-%{RELEASE}\n' nginx"
```

Информация о пакете:

```bash
ansible all -m shell -a "yum info nginx"

ansible all -m shell -a "rpm -ql nginx"

ansible all -m shell -a "rpm -qc nginx"

ansible all -m shell -a "rpm -qR nginx"
```

Проверка обновлений:

```bash
ansible all -m shell -a "yum check-update nginx" -b

ansible all -m shell -a "dnf check-update nginx" -b
```

История установки:

```bash
ansible all -m shell -a "yum history list nginx" -b

ansible all -m shell -a "yum history info last" -b
```

---

## Практические примеры

### Проверка версий

Версия конкретного пакета:

```bash
ansible all -m shell -a "nginx -v 2>&1" -o

ansible all -m shell -a "echo 'Nginx:' && nginx -v 2>&1; echo 'Git:' && git --version; echo 'Python:' && python3 --version"
```

Сравнение версий на хостах:

```bash
ansible all -m shell -a "dpkg -s nginx | grep Version" | grep -E "Version|SUCCESS"
```

### Статус служб

Проверка служб пакетов:

```bash
ansible all -m shell -a "systemctl status nginx" -b

ansible all -m command -a "systemctl is-active nginx" -b

ansible all -m command -a "systemctl is-enabled nginx" -b
```

Комплексная проверка:

```bash
ansible all -m shell -a "systemctl is-active nginx && systemctl is-enabled nginx" -b
```

### Массовая проверка

Проверка списка пакетов:

```bash
ansible all -m shell -a "
for pkg in nginx apache2 mysql-server postgresql redis-server; do
  if dpkg -l | grep -q \"^ii.*$pkg\"; then
    echo \"$pkg: installed ($(dpkg -s $pkg 2>/dev/null | grep Version | awk '{print $2}'))\";
  else
    echo \"$pkg: not installed\";
  fi;
done" -o
```

Фильтрация установленных пакетов:

```bash
ansible all -m shell -a "dpkg -l | grep -E '^ii.*(nginx|apache|mysql|postgres)' | awk '{print $2, $3}'"
```

### Security updates

Ubuntu/Debian:

```bash
ansible all -m shell -a "apt list --upgradable 2>/dev/null | grep -i security"

ansible all -m shell -a "apt-get upgrade -s | grep -i security"
```

RHEL/CentOS:

```bash
ansible all -m shell -a "yum updateinfo list security" -b

ansible all -m shell -a "yum --security check-update" -b
```

### Конфигурационные файлы

Список файлов конфигурации:

```bash
ansible all -m shell -a "dpkg -L nginx | grep '/etc/'"

ansible all -m shell -a "debsums -c nginx"
```

Валидация конфигурации:

```bash
ansible all -m shell -a "nginx -t" -b

ansible all -m shell -a "cat /etc/nginx/nginx.conf | head -20"
```

### Поиск по файлам

Определение пакета по файлу:

```bash
ansible all -m shell -a "dpkg -S /usr/sbin/nginx"

ansible all -m shell -a "rpm -qf /usr/sbin/nginx"
```

### Зависимости

Проверка зависимостей:

```bash
ansible all -m shell -a "apt-cache depends nginx | grep Depends"

ansible all -m shell -a "apt-cache rdepends nginx"

ansible all -m shell -a "repoquery --requires nginx"

ansible all -m shell -a "repoquery --whatrequires nginx"
```

### Статистика пакетов

Количество и размер:

```bash
ansible all -m shell -a "dpkg -l | grep '^ii' | wc -l"

ansible all -m shell -a "dpkg -s nginx | grep Installed-Size"
```

Топ больших пакетов:

```bash
ansible all -m shell -a "dpkg-query -W --showformat='\${Installed-Size}\t\${Package}\n' | sort -rn | head -10"
```

Дата установки (RHEL):

```bash
ansible all -m shell -a "rpm -q --qf '%{INSTALLTIME:date}\n' nginx"
```

### Репозитории

Список репозиториев Debian/Ubuntu:

```bash
ansible all -m shell -a "cat /etc/apt/sources.list"

ansible all -m shell -a "grep -r --include '*.list' '^deb ' /etc/apt/"
```

Список репозиториев RHEL/CentOS:

```bash
ansible all -m shell -a "yum repolist"

ansible all -m shell -a "yum repolist -v"
```

openSUSE:

```bash
ansible all -m shell -a "zypper repos"
```

### Логи пакетов

Просмотр логов операций:

```bash
ansible all -m shell -a "grep 'install nginx' /var/log/apt/history.log"

ansible all -m shell -a "grep nginx /var/log/yum.log"

ansible all -m shell -a "tail -50 /var/log/dpkg.log | grep nginx"
```

---

## Опции ansible

### Подключение

| Опция | Описание | Пример |
|-------|----------|--------|
| `--inventory`, `-i` | Путь к inventory | `-i inventory.ini` |
| `--user`, `-u` | Пользователь SSH | `-u admin` |
| `--private-key` | SSH ключ | `--private-key ~/.ssh/id_rsa` |
| `--connection`, `-c` | Тип подключения | `-c ssh` |
| `--timeout`, `-T` | Таймаут (сек) | `-T 30` |
| `--ssh-common-args` | SSH аргументы | `--ssh-common-args '-o StrictHostKeyChecking=no'` |

### Эскалация привилегий

| Опция | Описание | Пример |
|-------|----------|--------|
| `--become`, `-b` | Использование sudo | `-b` |
| `--become-user` | Целевой пользователь | `--become-user=root` |
| `--become-method` | Метод эскалации | `--become-method=sudo` |
| `--ask-become-pass`, `-K` | Запрос пароля sudo | `-K` |
| `--ask-pass`, `-k` | Запрос пароля SSH | `-k` |

### Выполнение модулей

| Опция | Описание | Пример |
|-------|----------|--------|
| `--module-name`, `-m` | Имя модуля | `-m ping` |
| `--args`, `-a` | Аргументы модуля | `-a "name=nginx state=present"` |
| `--module-path`, `-M` | Путь к кастомным модулям | `-M ./modules` |

### Вывод

| Опция | Описание | Пример |
|-------|----------|--------|
| `--verbose`, `-v` | Подробность вывода | `-v`, `-vv`, `-vvv`, `-vvvv` |
| `--one-line`, `-o` | Однострочный вывод | `-o` |
| `--tree`, `-t` | Сохранение вывода | `-t /tmp/output` |

### Производительность

| Опция | Описание | Пример |
|-------|----------|--------|
| `--forks`, `-f` | Параллельные процессы | `-f 10` |
| `--poll`, `-P` | Интервал опроса async | `-P 15` |
| `--background`, `-B` | Фоновое выполнение | `-B 3600` |

### Фильтрация

| Опция | Описание | Пример |
|-------|----------|--------|
| `--limit`, `-l` | Ограничение хостов | `-l webservers` |
| `--list-hosts` | Список хостов | `--list-hosts` |

### Дополнительные

| Опция | Описание | Пример |
|-------|----------|--------|
| `--check` | Dry run | `--check` |
| `--diff` | Показать изменения | `--diff` |
| `--extra-vars`, `-e` | Переменные | `-e "var=value"` |
| `--vault-id` | Vault ID | `--vault-id prod@prompt` |
| `--vault-password-file` | Файл пароля vault | `--vault-password-file .vault_pass` |

---

## Модули для ad-hoc

### Проверка системы

```bash
ansible all -m ping

ansible all -m setup

ansible all -m setup -a "filter=ansible_distribution*"

ansible all -m setup -a "filter=ansible_memtotal_mb"
```

### Выполнение команд

```bash
ansible all -m command -a "uptime"

ansible all -m shell -a "ps aux | grep nginx"

ansible all -m raw -a "uptime"

ansible all -m script -a "/path/to/script.sh"
```

### Управление пакетами

```bash
ansible all -m package -a "name=nginx state=present" -b

ansible all -m apt -a "name=nginx state=latest update_cache=yes" -b

ansible all -m yum -a "name=nginx state=present" -b

ansible all -m pip -a "name=flask state=present"
```

### Управление службами

```bash
ansible all -m service -a "name=nginx state=started enabled=yes" -b

ansible all -m systemd -a "name=nginx state=restarted daemon_reload=yes" -b
```

### Управление файлами

```bash
ansible all -m copy -a "src=/local/file dest=/remote/file mode=0644" -b

ansible all -m file -a "path=/tmp/test state=directory mode=0755" -b

ansible all -m template -a "src=template.j2 dest=/etc/config" -b

ansible all -m fetch -a "src=/remote/file dest=/local/path"

ansible all -m stat -a "path=/etc/nginx/nginx.conf"
```

### Управление пользователями

```bash
ansible all -m user -a "name=testuser state=present" -b

ansible all -m group -a "name=testgroup state=present" -b

ansible all -m authorized_key -a "user=ubuntu key='{{ lookup('file', '~/.ssh/id_rsa.pub') }}' state=present"
```

### Git операции

```bash
ansible all -m git -a "repo=https://github.com/user/repo.git dest=/opt/app version=main"
```

### Архивы

```bash
ansible all -m unarchive -a "src=/local/archive.tar.gz dest=/remote/path" -b

ansible all -m archive -a "path=/var/log/*.log dest=/tmp/logs.tar.gz" -b
```

### Сетевые операции

```bash
ansible all -m uri -a "url=http://example.com/api method=GET"

ansible all -m get_url -a "url=https://example.com/file.tar.gz dest=/tmp/"

ansible all -m wait_for -a "host=localhost port=80 state=started timeout=60"
```

### Cron

```bash
ansible all -m cron -a "name='backup' minute=0 hour=2 job='/opt/backup.sh'" -b

ansible all -m cron -a "name='backup' state=absent" -b
```

### Системные операции

```bash
ansible all -m reboot -a "reboot_timeout=600" -b

ansible all -m hostname -a "name=newhost" -b

ansible all -m sysctl -a "name=vm.swappiness value=10" -b

ansible all -m timezone -a "name=Europe/Moscow" -b
```

---

## Паттерны хостов

```bash
ansible all -m ping

ansible host1 -m ping

ansible webservers -m ping

ansible 'webservers:dbservers' -m ping

ansible 'webservers:&production' -m ping

ansible 'webservers:!staging' -m ping

ansible 'web[1:5]' -m ping

ansible '~web.*' -m ping

ansible 'webservers:&production:!web01' -m ping
```

---

## Переменные окружения

```bash
export ANSIBLE_INVENTORY=./inventory
export ANSIBLE_CONFIG=./ansible.cfg
export ANSIBLE_REMOTE_USER=admin
export ANSIBLE_BECOME=true
export ANSIBLE_BECOME_USER=root
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_TIMEOUT=30
export ANSIBLE_FORKS=10
export ANSIBLE_STDOUT_CALLBACK=yaml
export ANSIBLE_LOG_PATH=./ansible.log
```

---

## Практические комбинации

Проверка с логированием:

```bash
ansible all -m shell -a "dpkg -l | grep nginx" -o -vv | tee check.log
```

Параллельное выполнение:

```bash
ansible all -m shell -a "apt update" -b -f 50
```

С таймаутом:

```bash
ansible all -m shell -a "curl -s http://api.com" -T 10 --retries 3
```

Ограничение хостов:

```bash
ansible webservers -m package_facts --limit "web0[1-3]"
```

Передача переменных:

```bash
ansible all -m shell -a "echo {{ custom_var }}" -e "custom_var=test"
```

Асинхронное выполнение:

```bash
ansible all -m shell -a "apt dist-upgrade -y" -B 3600 -P 60 -b
```

Сохранение вывода по хостам:

```bash
ansible all -m setup --tree /tmp/facts/
```

С vault:

```bash
ansible all -m shell -a "cat /secure/file" --vault-password-file .vault_pass -b
```

---

## Best Practices

### Производительность

Увеличение параллелизма:

```bash
ansible all -m shell -a "command" -f 50
```

Краткий вывод:

```bash
ansible all -m ping -o
```

Кэширование фактов:

```bash
ansible all -m setup --tree /tmp/facts/
```

### Безопасность

Без логирования чувствительных данных:

```bash
ansible all -m shell -a "echo $PASSWORD" --no-log
```

Использование vault:

```bash
ansible all -m shell -a "command" --vault-password-file .vault_pass
```

Проверка перед выполнением:

```bash
ansible all -m command -a "rm -rf /important" --check
```

### Отладка

Детальный вывод:

```bash
ansible all -m shell -a "command" -vvv
```

Dry run:

```bash
ansible all -m apt -a "name=nginx state=latest" --check -b
```

### Организация

Алиасы для частых команд:

```bash
alias ansible-check='ansible all -m ping -o'
alias ansible-facts='ansible all -m setup -a "filter=ansible_distribution*"'
```

Скрипты для повторяющихся задач:

```bash
cat > check_package.sh << 'EOF'
#!/bin/bash
ansible all -m shell -a "dpkg -s $1 | grep Version" -o
EOF
chmod +x check_package.sh
```

### Обработка ошибок

Игнорирование ошибок:

```bash
ansible all -m shell -a "command_that_might_fail" --ignore-errors
```

Проверка кода возврата:

```bash
ansible all -m shell -a "test -f /etc/nginx/nginx.conf && echo exists || echo missing"
```

Условное выполнение:

```bash
ansible all -m shell -a "[ -f /etc/nginx/nginx.conf ] && nginx -t"
```
