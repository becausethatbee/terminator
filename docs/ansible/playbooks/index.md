# Ansible: Создание playbooks для управления пакетами и службами

Практическое руководство по созданию Ansible playbook для установки пакетов, управления службами и сбора системных фактов.

## Предварительные требования

- Настроенный Ansible с подключением к удаленному серверу
- SSH-доступ к управляемому серверу
- Права sudo на удаленном сервере

## Структура задания

Создать playbook, который:
1. Устанавливает пакет определенной версии
2. Включает службу в автозапуск (enable)
3. Запускает службу (start)
4. Выводит системный факт ansible_distribution
5. Проверяет корректность установки и работы службы

## Создание playbook

### Структура файла playbook

```yaml
---
- name: "Описание задачи playbook"
  hosts: all
  become: yes
  gather_facts: true
  
  vars:
    # Переменные для гибкости настройки
    
  tasks:
    # Список задач
    
  handlers:
    # Обработчики событий (опционально)
```

## Практический пример: Установка Chrony

### Создание playbook install-chrony.yml

```yaml
---
- name: "Установка Chrony и управление службой синхронизации времени"
  hosts: all
  become: yes
  gather_facts: true
  
  vars:
    chrony_version: "latest"
    chrony_service_name: "chronyd"
    
  tasks:
    - name: "Обновление кэша репозиториев (openSUSE)"
      shell: "zypper --gpg-auto-import-keys refresh"
      when: ansible_os_family == "Suse"
      failed_when: false
      tags: [update]
    
    - name: "Установка Chrony (openSUSE)"
      shell: "zypper install -y chrony"
      when: ansible_os_family == "Suse"
      tags: [install]
    
    - name: "Установка Chrony (Debian/Ubuntu)"
      package:
        name: chrony
        state: present
      when: ansible_os_family == "Debian"
      tags: [install]
    
    - name: "Установка Chrony (Red Hat/CentOS)"
      package:
        name: chrony
        state: present
      when: ansible_os_family == "RedHat"
      tags: [install]
    
    - name: "Включение службы в автозапуск"
      service:
        name: "{{ chrony_service_name }}"
        enabled: yes
      tags: [service]
    
    - name: "Запуск службы"
      service:
        name: "{{ chrony_service_name }}"
        state: started
      tags: [service]
    
    - name: "Вывод системного факта"
      debug:
        msg: |
          Дистрибутив: {{ ansible_distribution }}
          Версия: {{ ansible_distribution_version }}
          Семейство ОС: {{ ansible_os_family }}
      tags: [facts]
    
    - name: "Проверка статуса службы"
      command: "systemctl is-active {{ chrony_service_name }}"
      register: service_status
      changed_when: false
      tags: [verify]
    
    - name: "Результат проверки"
      debug:
        msg: "Служба активна: {{ 'Да' if service_status.stdout == 'active' else 'Нет' }}"
      tags: [verify]
```

## Выполнение playbook

### Проверка синтаксиса
```bash
ansible-playbook --syntax-check install-chrony.yml
```

### Dry run (проверка без изменений)
```bash
ansible-playbook --check install-chrony.yml
```

### Выполнение playbook
```bash
ansible-playbook install-chrony.yml
```

### Выполнение конкретных тегов
```bash
# Только установка пакета
ansible-playbook install-chrony.yml --tags install

# Только управление службой
ansible-playbook install-chrony.yml --tags service

# Только вывод фактов
ansible-playbook install-chrony.yml --tags facts

# Только проверка результата
ansible-playbook install-chrony.yml --tags verify
```

## Проверка результатов

### Проверка через ad-hoc команды
```bash
# Статус службы
ansible all -m shell -a "systemctl status chronyd"

# Автозапуск службы
ansible all -m shell -a "systemctl is-enabled chronyd"

# Проверка синхронизации времени
ansible all -m shell -a "chronyc tracking"
```

## Ключевые концепции

### Переменные в playbooks

| Переменная | Описание |
|------------|----------|
| `vars` | Переменные, определенные в playbook |
| `{{ variable_name }}` | Синтаксис подстановки переменных |
| `register` | Сохранение результата выполнения задачи |
| `when` | Условное выполнение задач |

### Модули для управления службами

| Модуль | Назначение |
|--------|-----------|
| `service` | Управление службами (start, stop, enable, disable) |
| `systemd` | Расширенное управление systemd службами |
| `command` | Выполнение произвольных команд |
| `shell` | Выполнение команд через shell |

### Модули для установки пакетов

| Модуль | Назначение |
|--------|-----------|
| `package` | Универсальная установка пакетов |
| `apt` | Управление пакетами Debian/Ubuntu |
| `yum` | Управление пакетами Red Hat/CentOS |
| `zypper` | Управление пакетами openSUSE |

### Системные факты Ansible

| Факт | Описание |
|------|---------|
| `ansible_distribution` | Название дистрибутива Linux |
| `ansible_distribution_version` | Версия дистрибутива |
| `ansible_os_family` | Семейство ОС (Debian, RedHat, Suse) |
| `ansible_architecture` | Архитектура системы |
| `ansible_hostname` | Имя хоста |
| `ansible_date_time` | Информация о дате и времени |

### Теги в playbooks

| Назначение | Пример использования |
|------------|---------------------|
| Группировка задач | `tags: [install, config]` |
| Частичное выполнение | `--tags install` |
| Исключение задач | `--skip-tags config` |
| Отладка | `--tags debug` |

## Обработка ошибок

### Управление ошибками

| Параметр | Назначение |
|----------|-----------|
| `failed_when` | Определение условий ошибки |
| `ignore_errors` | Игнорирование ошибок |
| `changed_when` | Определение изменений |
| `--ignore-errors` | Игнорирование ошибок через CLI |

### Примеры обработки
```yaml
- name: "Команда, которая может завершиться ошибкой"
  command: "some-command"
  failed_when: false
  
- name: "Команда только для проверки"
  command: "systemctl status service"
  changed_when: false
  
- name: "Условная обработка ошибок"
  shell: "service restart nginx"
  failed_when: result.rc not in [0, 1]
  register: result
```

## Условное выполнение

### Использование условий when

```yaml
- name: "Задача только для Ubuntu"
  apt:
    name: package
    state: present
  when: ansible_distribution == "Ubuntu"

- name: "Задача для семейства Debian"
  package:
    name: package
    state: present
  when: ansible_os_family == "Debian"

- name: "Задача на основе результата"
  service:
    name: nginx
    state: restarted
  when: config_changed.changed
```

## Отладка и тестирование

### Полезные команды для отладки

| Команда | Назначение |
|---------|-----------|
| `ansible-playbook --list-tasks playbook.yml` | Список задач в playbook |
| `ansible-playbook --list-tags playbook.yml` | Список тегов |
| `ansible-playbook -vvv playbook.yml` | Детальный вывод |
| `ansible-playbook --step playbook.yml` | Пошаговое выполнение |

### Тестирование изменений
```bash
# Проверка без выполнения
ansible-playbook --check playbook.yml

# Показать различия
ansible-playbook --check --diff playbook.yml

# Ограничить выполнение одним хостом
ansible-playbook --limit hostname playbook.yml
```

## Лучшие практики

### Структура playbook
- Используйте описательные имена для задач
- Группируйте связанные задачи тегами
- Добавляйте переменные для гибкости
- Обрабатывайте ошибки там, где это нужно

### Переменные
- Выносите настройки в переменные
- Используйте значения по умолчанию
- Документируйте назначение переменных

### Идемпотентность
- Playbook должен давать одинаковый результат при многократном запуске
- Используйте `changed_when` для корректного отображения изменений
- Проверяйте состояние перед изменениями
