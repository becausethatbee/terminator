# Ansible: Настройка Callback плагинов

Полное руководство по настройке и использованию callback плагинов Ansible для расширенного контроля вывода, логирования и интеграции с внешними системами.


## Введение в Callback плагины

### Что такое Callback плагины?

**Callback плагины** - это компоненты Ansible, которые позволяют:

- Настраивать формат вывода playbook
- Логировать выполнение в различные backend системы
- Отправлять уведомления в Slack, email и другие системы
- Профилировать производительность задач
- Интегрироваться с системами мониторинга
- Кастомизировать отображение результатов

### Зачем использовать Callback плагины?

**Без Callback плагинов:**
```
PLAY [webservers] **************************************************************

TASK [Gathering Facts] *********************************************************
ok: [web1]
ok: [web2]

TASK [Install nginx] ***********************************************************
changed: [web1]
changed: [web2]

PLAY RECAP *********************************************************************
web1                       : ok=2    changed=1    unreachable=0    failed=0
web2                       : ok=2    changed=1    unreachable=0    failed=0
```

**С YAML callback плагином:**
```yaml
PLAY [webservers]

TASK [Gathering Facts]
  ok: [web1]
  ok: [web2]

TASK [Install nginx]
  changed: [web1]
    msg: "Successfully installed nginx 1.18.0"
  changed: [web2]
    msg: "Successfully installed nginx 1.18.0"

PLAY RECAP
  web1:
    ok: 2
    changed: 1
    unreachable: 0
    failed: 0
  web2:
    ok: 2
    changed: 1
    unreachable: 0
    failed: 0
```

### Как работают Callback плагины?

```
Ansible Playbook
      ↓
   Events
(начало play, начало задачи, успех, ошибка, и т.д.)
      ↓
Callback Plugin
      ↓
Custom Actions
(вывод, логирование, уведомления)
```

---

## Типы Callback плагинов

### 1. Stdout Callbacks (Вывод)

Управляют тем, что вы видите в терминале при выполнении playbook.

**Основные характеристики:**
- Изменяют формат вывода в консоль
- Может быть активен **только один** stdout callback одновременно
- Настраиваются через `stdout_callback` в ansible.cfg

**Примеры:**
- `default` - стандартный вывод Ansible
- `yaml` - структурированный YAML вывод
- `json` - JSON формат
- `minimal` - минимальный вывод

### 2. Notification Callbacks (Уведомления)

Отправляют информацию во внешние системы.

**Основные характеристики:**
- Работают параллельно со stdout callbacks
- Можно активировать **несколько** одновременно
- Настраиваются через `callbacks_enabled` в ansible.cfg

**Примеры:**
- `mail` - отправка email
- `slack` - уведомления в Slack
- `log_plays` - логирование в файл
- `junit` - создание JUnit XML отчетов

### 3. Aggregate Callbacks (Агрегация)

Собирают и агрегируют информацию о выполнении.

**Основные характеристики:**
- Собирают метрики и статистику
- Профилируют производительность
- Работают в фоне

**Примеры:**
- `profile_tasks` - профилирование времени выполнения задач
- `timer` - общее время выполнения playbook
- `cgroup_perf_recap` - профилирование системных ресурсов

---

## Настройка через ansible.cfg

### Базовая конфигурация

```ini
[defaults]
# ============================================
# STDOUT CALLBACK (только один активен)
# ============================================
stdout_callback = yaml
# Альтернативы: default, minimal, json, oneline, debug

# Использовать stdout_callback для ad-hoc команд
bin_ansible_callbacks = True

# ============================================
# NOTIFICATION/AGGREGATE CALLBACKS (можно несколько)
# ============================================
callbacks_enabled = profile_tasks, timer, log_plays

# ============================================
# НАСТРОЙКИ ВЫВОДА
# ============================================
# Показывать пропущенные хосты
display_skipped_hosts = False

# Показывать успешные хосты
display_ok_hosts = True

# Показывать stderr при ошибках
display_failed_stderr = True

# Цветной вывод
force_color = True
nocolor = False

# Использовать символы unicode
ansible_force_color = True

# ============================================
# ПУТИ К CALLBACK ПЛАГИНАМ
# ============================================
callback_plugins = ~/.ansible/plugins/callback:/usr/share/ansible/plugins/callback

# Whitelist для callback плагинов
callback_whitelist = profile_tasks, timer, mail, slack
```

### Расширенная конфигурация

```ini
[defaults]
stdout_callback = yaml
callbacks_enabled = profile_tasks, timer, log_plays, cgroup_perf_recap
bin_ansible_callbacks = True
display_skipped_hosts = False
display_ok_hosts = True
force_color = True

# ============================================
# НАСТРОЙКИ PROFILE_TASKS
# ============================================
[callback_profile_tasks]
task_output_limit = 20
sort_order = descending

# ============================================
# НАСТРОЙКИ TIMER
# ============================================
[callback_timer]
format_string = "Playbook execution took {days} days, {hours} hours, {minutes} minutes, {seconds} seconds"

# ============================================
# НАСТРОЙКИ LOG_PLAYS
# ============================================
[callback_log_plays]
log_folder = /var/log/ansible/playbooks
log_date_format = %Y-%m-%d_%H-%M-%S

# ============================================
# НАСТРОЙКИ MAIL
# ============================================
[callback_mail]
smtp_host = smtp.gmail.com
smtp_port = 587
smtp_user = ansible@example.com
smtp_password = password
mail_to = admin@example.com
mail_from = ansible@example.com

# ============================================
# НАСТРОЙКИ SLACK
# ============================================
[callback_slack]
webhook_url = https://hooks.slack.com/services/YOUR/WEBHOOK/URL
channel = #ansible
username = Ansible Bot
```

---

## Встроенные Callback плагины

### 1. Default (Стандартный)

Стандартный вывод Ansible по умолчанию.

```ini
[defaults]
stdout_callback = default
```

**Вывод:**
```
PLAY [webservers] **************************************************************

TASK [Gathering Facts] *********************************************************
ok: [web1]

TASK [Install nginx] ***********************************************************
changed: [web1]

PLAY RECAP *********************************************************************
web1                       : ok=2    changed=1    unreachable=0    failed=0
```

### 2. YAML

Структурированный YAML вывод для лучшей читаемости.

```ini
[defaults]
stdout_callback = yaml
bin_ansible_callbacks = True
```

**Вывод:**
```yaml
PLAY [webservers]

TASK [Gathering Facts]
  ok: [web1]
    ansible_facts:
      ansible_distribution: Ubuntu
      ansible_distribution_version: "20.04"

TASK [Install nginx]
  changed: [web1]
    msg: Package installed successfully
```

**Использование через CLI:**
```bash
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook playbook.yml
```

### 3. JSON

JSON формат для программной обработки.

```ini
[defaults]
stdout_callback = json
```

**Вывод:**
```json
{
  "plays": [
    {
      "play": {
        "name": "webservers",
        "id": "..."
      },
      "tasks": [
        {
          "task": {
            "name": "Install nginx",
            "id": "..."
          },
          "hosts": {
            "web1": {
              "changed": true,
              "msg": "Package installed"
            }
          }
        }
      ]
    }
  ]
}
```

### 4. Minimal

Минимальный вывод - только важная информация.

```ini
[defaults]
stdout_callback = minimal
```

**Вывод:**
```
web1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 5. Oneline

Однострочный вывод для каждой задачи.

```ini
[defaults]
stdout_callback = oneline
```

**Вывод:**
```
web1 | SUCCESS | rc=0 | (stdout) pong
web1 | CHANGED | rc=0 | (stdout) Package installed
```

### 6. Profile_tasks

Профилирование времени выполнения задач.

```ini
[defaults]
callbacks_enabled = profile_tasks

[callback_profile_tasks]
task_output_limit = 20
sort_order = descending
```

**Вывод:**
```
PLAY RECAP *********************************************************************
web1                       : ok=5    changed=3    unreachable=0    failed=0

Tuesday 26 September 2025  14:30:15 +0300 (0:00:02.455)
===============================================================================
Install nginx --------------------------------------------------------- 12.45s
Configure nginx ------------------------------------------------------- 3.22s
Start nginx service --------------------------------------------------- 2.18s
Update apt cache ------------------------------------------------------ 1.85s
Gather facts ---------------------------------------------------------- 1.05s
```

### 7. Timer

Общее время выполнения playbook.

```ini
[defaults]
callbacks_enabled = timer
```

**Вывод:**
```
PLAY RECAP *********************************************************************
web1                       : ok=5    changed=3    unreachable=0    failed=0

Playbook run took 0 days, 0 hours, 2 minutes, 15 seconds
```

### 8. Actionable

Показывает только задачи, которые внесли изменения или завершились с ошибкой.

```ini
[defaults]
stdout_callback = actionable
display_skipped_hosts = False
display_ok_hosts = False
```

**Вывод (показывает только changed/failed):**
```
PLAY [webservers]

TASK [Install nginx]
changed: [web1]

PLAY RECAP *********************************************************************
web1                       : ok=5    changed=1    unreachable=0    failed=0
```

### 9. Debug

Расширенный вывод для отладки.

```ini
[defaults]
stdout_callback = debug
```

**Вывод включает:**
- Все переменные задачи
- Return values модулей
- Детальную информацию об ошибках

### 10. Selective

Показывает только выбранные задачи по regex паттерну.

```ini
[defaults]
stdout_callback = selective

[callback_selective]
task_name_regex = "Install|Configure"
```

---

## Создание собственного Callback

### Когда создавать собственный Callback?

Создавайте собственный callback плагин когда:
- Нужен специфический формат вывода для вашей команды
- Требуется интеграция с внутренними системами компании
- Необходимо логирование в нестандартный backend
- Нужна отправка уведомлений в системы, для которых нет готового плагина
- Требуется сбор специфических метрик или статистики

### Что нужно для создания Callback?

**Минимальные требования:**
1. **Python файл** в директории `callback_plugins/`
2. **Наследование от CallbackBase** - базовый класс для всех callback
3. **Метаданные плагина** - CALLBACK_VERSION, CALLBACK_TYPE, CALLBACK_NAME
4. **DOCUMENTATION блок** - описание плагина в формате YAML
5. **Реализация методов** - хотя бы один метод обработки событий

**Структура директорий:**
```
project/
├── ansible.cfg
├── playbook.yml
└── callback_plugins/
    └── my_callback.py
```

**Типы callback по CALLBACK_TYPE:**
- `stdout` - изменяет вывод в консоль (только один активен)
- `notification` - отправляет уведомления (можно несколько)
- `aggregate` - собирает статистику (можно несколько)

**Основные методы событий:**
- `v2_playbook_on_start()` - начало playbook
- `v2_playbook_on_task_start()` - начало задачи
- `v2_runner_on_ok()` - успешное выполнение
- `v2_runner_on_failed()` - ошибка выполнения
- `v2_playbook_on_stats()` - финальная статистика

### Базовая структура

```python
# callback_plugins/custom_callback.py

# Импорты для совместимости с Python 2 и 3
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

# Импорт базового класса для callback плагинов
from ansible.plugins.callback import CallbackBase
from datetime import datetime
import json

# DOCUMENTATION блок - обязательный для всех плагинов
# Используется командой ansible-doc для показа справки
DOCUMENTATION = '''
    callback: custom_callback
    type: stdout
    short_description: Custom callback plugin
    version_added: "2.0"
    description:
        - This callback plugin provides custom output format
    requirements:
      - Enable in configuration
'''

class CallbackModule(CallbackBase):
    """
    Кастомный callback plugin для улучшенного вывода
    """
    
    # Версия callback API (всегда 2.0 для современных версий)
    CALLBACK_VERSION = 2.0
    
    # Тип плагина: stdout, notification или aggregate
    CALLBACK_TYPE = 'stdout'
    
    # Уникальное имя плагина
    CALLBACK_NAME = 'custom_callback'
    
    def __init__(self):
        """Инициализация плагина"""
        # Вызов конструктора родительского класса обязателен
        super(CallbackModule, self).__init__()
        # Сохраняем время старта для подсчета длительности
        self.start_time = datetime.now()
    
    def v2_playbook_on_start(self, playbook):
        """
        Вызывается в начале playbook
        
        Args:
            playbook: объект playbook с метаданными
        """
        # Вывод баннера
        self._display.banner("PLAYBOOK START")
        # Получаем имя файла playbook
        self._display.display(f"Starting playbook: {playbook._file_name}")
        self._display.display(f"Time: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    def v2_playbook_on_play_start(self, play):
        """
        Вызывается в начале каждого play
        
        Args:
            play: объект play
        """
        # Получаем имя play и убираем лишние пробелы
        name = play.get_name().strip()
        self._display.banner(f"PLAY: {name}")
    
    def v2_playbook_on_task_start(self, task, is_conditional):
        """
        Вызывается в начале каждой задачи
        
        Args:
            task: объект задачи
            is_conditional: True если задача имеет условие when
        """
        # Получаем имя задачи
        task_name = task.get_name().strip()
        # Форматируем текущее время
        timestamp = datetime.now().strftime('%H:%M:%S')
        # Выводим с цветом
        self._display.display(f"[{timestamp}] TASK: {task_name}", color='bright blue')
    
    def v2_runner_on_ok(self, result):
        """
        Вызывается при успешном выполнении задачи
        
        Args:
            result: объект результата выполнения
        """
        # Извлекаем имя хоста
        host = result._host.get_name()
        # Извлекаем имя задачи
        task_name = result._task.get_name()
        
        # Определяем статус - изменилось ли что-то
        if result._result.get('changed', False):
            status = "CHANGED"
            color = 'yellow'
        else:
            status = "OK"
            color = 'green'
        
        # Формируем сообщение
        msg = f"  [{status}] {host}: {task_name}"
        
        # Добавляем дополнительную информацию если есть
        if 'msg' in result._result:
            msg += f"\n    Message: {result._result['msg']}"
        
        # Выводим с соответствующим цветом
        self._display.display(msg, color=color)
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        """
        Вызывается при ошибке выполнения задачи
        
        Args:
            result: объект результата
            ignore_errors: True если ошибки игнорируются
        """
        host = result._host.get_name()
        task_name = result._task.get_name()
        
        msg = f"  [FAILED] {host}: {task_name}"
        
        # Добавляем сообщение об ошибке если есть
        if 'msg' in result._result:
            msg += f"\n    Error: {result._result['msg']}"
        
        # Если ошибки игнорируются - желтый цвет, иначе красный
        if ignore_errors:
            msg += "\n    (ignored)"
            color = 'yellow'
        else:
            color = 'red'
        
        self._display.display(msg, color=color)
    
    def v2_runner_on_skipped(self, result):
        """
        Вызывается при пропуске задачи (when условие не выполнено)
        
        Args:
            result: объект результата
        """
        host = result._host.get_name()
        task_name = result._task.get_name()
        
        self._display.display(
            f"  [SKIPPED] {host}: {task_name}",
            color='cyan'
        )
    
    def v2_runner_on_unreachable(self, result):
        """
        Вызывается когда хост недоступен
        
        Args:
            result: объект результата
        """
        host = result._host.get_name()
        
        self._display.display(
            f"  [UNREACHABLE] {host}: Host is unreachable",
            color='bright red'
        )
    
    def v2_playbook_on_stats(self, stats):
        """
        Вызывается в конце playbook - итоговая статистика
        
        Args:
            stats: объект со статистикой выполнения
        """
        # Вычисляем время выполнения
        end_time = datetime.now()
        duration = end_time - self.start_time
        
        self._display.banner("PLAY RECAP")
        
        # Получаем список обработанных хостов
        hosts = sorted(stats.processed.keys())
        for host in hosts:
            # Получаем статистику по хосту
            summary = stats.summarize(host)
            
            # Форматируем вывод
            msg = (
                f"{host:30} : "
                f"ok={summary['ok']:4} "
                f"changed={summary['changed']:4} "
                f"unreachable={summary['unreachable']:4} "
                f"failed={summary['failures']:4} "
                f"skipped={summary['skipped']:4}"
            )
            
            # Определяем цвет по результатам
            if summary['failures'] > 0 or summary['unreachable'] > 0:
                color = 'red'
            elif summary['changed'] > 0:
                color = 'yellow'
            else:
                color = 'green'
            
            self._display.display(msg, color=color)
        
        # Выводим общую длительность
        self._display.display(f"\nPlaybook duration: {duration}", color='bright blue')
```

### Notification Callback - отправка в Slack

```python
# callback_plugins/slack_notification.py

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
import json
import requests

# Документация плагина с описанием параметров конфигурации
DOCUMENTATION = '''
    callback: slack_notification
    type: notification
    short_description: Sends notifications to Slack
    version_added: "2.0"
    description:
        - This callback plugin sends playbook results to Slack
    requirements:
        - requests library
    options:
        webhook_url:
            description: Slack webhook URL
            required: True
            env:
              - name: SLACK_WEBHOOK_URL
            ini:
              - section: callback_slack
                key: webhook_url
        channel:
            description: Slack channel
            default: '#ansible'
            ini:
              - section: callback_slack
                key: channel
'''

class CallbackModule(CallbackBase):
    """
    Callback plugin для отправки уведомлений в Slack
    """
    
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'  # notification - не влияет на stdout
    CALLBACK_NAME = 'slack_notification'
    CALLBACK_NEEDS_ENABLED = True  # Требует явного включения в конфигурации
    
    def __init__(self):
        """Инициализация плагина"""
        super(CallbackModule, self).__init__()
        self.playbook_name = None
        self.errors = []  # Список ошибок для финального отчета
    
    def set_options(self, task_keys=None, var_options=None, direct=None):
        """
        Загрузка параметров из ansible.cfg или переменных окружения
        
        Args:
            task_keys: ключи задачи
            var_options: опции переменных
            direct: прямые опции
        """
        super(CallbackModule, self).set_options(task_keys=task_keys, 
                                                  var_options=var_options, 
                                                  direct=direct)
        
        # Получаем параметры из конфигурации
        self.webhook_url = self.get_option('webhook_url')
        self.channel = self.get_option('channel')
    
    def send_slack_message(self, message, color='good'):
        """
        Отправка сообщения в Slack через webhook
        
        Args:
            message: текст сообщения
            color: цвет attachment (good, warning, danger)
        """
        # Формируем payload для Slack API
        payload = {
            'channel': self.channel,
            'username': 'Ansible Bot',
            'icon_emoji': ':ansible:',
            'attachments': [
                {
                    'color': color,  # good=зеленый, warning=желтый, danger=красный
                    'text': message,
                    'mrkdwn_in': ['text']  # Поддержка Markdown
                }
            ]
        }
        
        try:
            # POST запрос к Slack webhook
            response = requests.post(
                self.webhook_url,
                data=json.dumps(payload),
                headers={'Content-Type': 'application/json'}
            )
            response.raise_for_status()  # Выбросить исключение при HTTP ошибке
        except Exception as e:
            # Логируем ошибку, но не прерываем выполнение playbook
            self._display.warning(f"Failed to send Slack message: {str(e)}")
    
    def v2_playbook_on_start(self, playbook):
        """
        Уведомление о начале playbook
        
        Args:
            playbook: объект playbook
        """
        self.playbook_name = playbook._file_name
        message = f"*Playbook Started*\n`{self.playbook_name}`"
        # Зеленый цвет для старта
        self.send_slack_message(message, color='#36a64f')
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        """
        Сохранение информации об ошибках
        
        Args:
            result: объект результата
            ignore_errors: флаг игнорирования ошибок
        """
        # Сохраняем только реальные ошибки (не игнорируемые)
        if not ignore_errors:
            host = result._host.get_name()
            task = result._task.get_name()
            error_msg = result._result.get('msg', 'Unknown error')
            # Добавляем в список ошибок
            self.errors.append(f"• {host}: {task}\n  Error: {error_msg}")
    
    def v2_playbook_on_stats(self, stats):
        """
        Итоговое уведомление с результатами playbook
        
        Args:
            stats: объект статистики
        """
        hosts = sorted(stats.processed.keys())
        
        # Формируем итоговое сообщение
        message = f"*Playbook Completed:* `{self.playbook_name}`\n\n"
        
        # Добавляем статистику по каждому хосту
        for host in hosts:
            summary = stats.summarize(host)
            message += (
                f"*{host}*\n"
                f"  OK: {summary['ok']}  "
                f"Changed: {summary['changed']}  "
                f"Failed: {summary['failures']}\n"
            )
        
        # Добавляем список ошибок если есть
        if self.errors:
            message += "\n*Errors:*\n" + "\n".join(self.errors)
            color = 'danger'  # Красный цвет при ошибках
        else:
            message += "\n*All tasks completed successfully!*"
            color = 'good'  # Зеленый цвет при успехе
        
        self.send_slack_message(message, color=color)
```

### Log Callback - логирование в файл

```python
# callback_plugins/detailed_log.py

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
from datetime import datetime
import json
import os

class CallbackModule(CallbackBase):
    """
    Callback plugin для детального логирования в файл
    Сохраняет полную информацию о выполнении playbook
    """
    
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'  # Работает параллельно с stdout
    CALLBACK_NAME = 'detailed_log'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        """Инициализация и создание лог файла"""
        super(CallbackModule, self).__init__()
        
        # Создание директории для логов если не существует
        log_dir = '/var/log/ansible'
        os.makedirs(log_dir, exist_ok=True)
        
        # Файл лога с timestamp для уникальности
        timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        self.log_file = f"{log_dir}/ansible_{timestamp}.log"
        
        # Открываем файл для записи
        self.log_handle = open(self.log_file, 'w')
    
    def log(self, message):
        """
        Запись сообщения в лог файл с timestamp
        
        Args:
            message: сообщение для записи
        """
        # Добавляем timestamp к каждому сообщению
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        self.log_handle.write(f"[{timestamp}] {message}\n")
        # Принудительная запись на диск
        self.log_handle.flush()
    
    def v2_playbook_on_start(self, playbook):
        """
        Начало playbook - записываем заголовок
        
        Args:
            playbook: объект playbook
        """
        self.log(f"=== PLAYBOOK START: {playbook._file_name} ===")
    
    def v2_playbook_on_play_start(self, play):
        """
        Начало play - записываем разделитель
        
        Args:
            play: объект play
        """
        name = play.get_name().strip()
        self.log(f"--- PLAY: {name} ---")
    
    def v2_playbook_on_task_start(self, task, is_conditional):
        """
        Начало задачи - логируем имя
        
        Args:
            task: объект задачи
            is_conditional: наличие условий
        """
        task_name = task.get_name().strip()
        self.log(f"TASK: {task_name}")
    
    def v2_runner_on_ok(self, result):
        """
        Успешное выполнение - логируем детали
        
        Args:
            result: объект результата
        """
        host = result._host.get_name()
        task = result._task.get_name()
        
        # Определяем статус
        if result._result.get('changed', False):
            status = "CHANGED"
        else:
            status = "OK"
        
        self.log(f"  [{status}] {host}: {task}")
        
        # Логируем полные результаты в JSON формате
        if result._result:
            # Форматируем JSON с отступами для читаемости
            self.log(f"    Result: {json.dumps(result._result, indent=2)}")
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        """
        Ошибка выполнения - детальное логирование
        
        Args:
            result: объект результата
            ignore_errors: флаг игнорирования ошибок
        """
        host = result._host.get_name()
        task = result._task.get_name()
        
        self.log(f"  [FAILED] {host}: {task}")
        # Логируем полную информацию об ошибке
        self.log(f"    Error: {json.dumps(result._result, indent=2)}")
    
    def v2_playbook_on_stats(self, stats):
        """
        Итоговая статистика - записываем и закрываем файл
        
        Args:
            stats: объект статистики
        """
        self.log("=== PLAY RECAP ===")
        
        # Записываем статистику по каждому хосту
        hosts = sorted(stats.processed.keys())
        for host in hosts:
            summary = stats.summarize(host)
            self.log(
                f"{host}: ok={summary['ok']} changed={summary['changed']} "
                f"unreachable={summary['unreachable']} failed={summary['failures']}"
            )
        
        # Указываем путь к сохраненному логу
        self.log(f"=== LOG SAVED TO: {self.log_file} ===")
        # Закрываем файл
        self.log_handle.close()
```

### Использование собственных Callback

```ini
# ansible.cfg
[defaults]
callback_plugins = ./callback_plugins
stdout_callback = custom_callback
callbacks_enabled = slack_notification, detailed_log

[callback_slack]
webhook_url = https://hooks.slack.com/services/YOUR/WEBHOOK/URL
channel = #ansible
```

```bash
# Или через переменные окружения
export ANSIBLE_CALLBACK_PLUGINS=./callback_plugins
export ANSIBLE_STDOUT_CALLBACK=custom_callback
export ANSIBLE_CALLBACKS_ENABLED=slack_notification,detailed_log

ansible-playbook playbook.yml
```

---

## Интеграция с внешними системами

### 1. Email уведомления

```ini
[defaults]
callbacks_enabled = mail

[callback_mail]
smtp_host = smtp.gmail.com
smtp_port = 587
smtp_user = ansible@example.com
smtp_password = your_password
mail_to = admin@example.com, team@example.com
mail_from = ansible@example.com
mail_subject_fail = "[ANSIBLE] Playbook Failed: {{ playbook_name }}"
mail_subject_success = "[ANSIBLE] Playbook Success: {{ playbook_name }}"
```

### 2. Grafana/Prometheus метрики

```python
# callback_plugins/prometheus_metrics.py

from ansible.plugins.callback import CallbackBase
from prometheus_client import Counter, Histogram, push_to_gateway
import time

class CallbackModule(CallbackBase):
    """
    Callback для отправки метрик в Prometheus через Pushgateway
    """
    
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'prometheus_metrics'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        """Инициализация метрик Prometheus"""
        super(CallbackModule, self).__init__()
        
        # Счетчик задач по статусу и хосту
        self.task_counter = Counter(
            'ansible_tasks_total',
            'Total number of tasks',
            ['status', 'host']  # Метки для группировки
        )
        
        # Гистограмма для времени выполнения задач
        self.task_duration = Histogram(
            'ansible_task_duration_seconds',
            'Task duration in seconds',
            ['task_name', 'host']
        )
        
        # Словарь для хранения времени начала задач
        self.task_start_time = {}
    
    def v2_playbook_on_task_start(self, task, is_conditional):
        """
        Сохраняем время начала задачи
        
        Args:
            task: объект задачи
            is_conditional: флаг условности
        """
        task_name = task.get_name()
        # Запоминаем timestamp начала
        self.task_start_time[task_name] = time.time()
    
    def v2_runner_on_ok(self, result):
        """
        Отправка метрики при успешном выполнении
        
        Args:
            result: объект результата
        """
        host = result._host.get_name()
        task = result._task.get_name()
        
        # Определяем статус для метрики
        status = 'changed' if result._result.get('changed') else 'ok'
        # Увеличиваем счетчик
        self.task_counter.labels(status=status, host=host).inc()
        
        # Измерение времени выполнения
        if task in self.task_start_time:
            duration = time.time() - self.task_start_time[task]
            # Записываем в гистограмму
            self.task_duration.labels(task_name=task, host=host).observe(duration)
    
    def v2_playbook_on_stats(self, stats):
        """
        Отправка всех метрик в Pushgateway
        
        Args:
            stats: объект статистики
        """
        # Отправка метрик в Prometheus Pushgateway
        # Метрики будут доступны для scraping в Prometheus
        push_to_gateway(
            'localhost:9091',  # Адрес Pushgateway
            job='ansible',      # Имя задачи в Prometheus
            registry=self.task_counter._metrics
        )
```

### 3. Elasticsearch логирование

```python
# callback_plugins/elasticsearch_log.py

from ansible.plugins.callback import CallbackBase
from elasticsearch import Elasticsearch
from datetime import datetime
import json

class CallbackModule(CallbackBase):
    """
    Callback для логирования событий Ansible в Elasticsearch
    Позволяет хранить и анализировать историю выполнения playbooks
    """
    
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'elasticsearch_log'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        """Инициализация подключения к Elasticsearch"""
        super(CallbackModule, self).__init__()
        # Создаем клиент Elasticsearch
        self.es = Elasticsearch(['http://localhost:9200'])
        # Уникальный ID для группировки событий одного playbook
        self.playbook_id = None
    
    def v2_playbook_on_start(self, playbook):
        """
        Создание записи о начале playbook в Elasticsearch
        
        Args:
            playbook: объект playbook
        """
        # Генерируем уникальный ID playbook с timestamp
        self.playbook_id = f"playbook_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        # Формируем документ для индексации
        doc = {
            'timestamp': datetime.now().isoformat(),  # ISO формат времени
            'type': 'playbook_start',                 # Тип события
            'playbook': playbook._file_name,          # Имя playbook
            'playbook_id': self.playbook_id           # ID для связи событий
        }
        
        # Индексируем документ в Elasticsearch
        self.es.index(index='ansible-logs', document=doc)
    
    def v2_runner_on_ok(self, result):
        """
        Логирование успешного выполнения задачи
        
        Args:
            result: объект результата
        """
        # Формируем документ с результатом задачи
        doc = {
            'timestamp': datetime.now().isoformat(),
            'type': 'task_result',
            'playbook_id': self.playbook_id,          # Связь с playbook
            'host': result._host.get_name(),
            'task': result._task.get_name(),
            'status': 'changed' if result._result.get('changed') else 'ok',
            'result': result._result                  # Полный результат задачи
        }
        
        # Индексируем в Elasticsearch
        # Данные можно потом искать по playbook_id, host, status и т.д.
        self.es.index(index='ansible-logs', document=doc)
```

### 4. Telegram уведомления

```python
# callback_plugins/telegram_notify.py

from ansible.plugins.callback import CallbackBase
import requests
import json

class CallbackModule(CallbackBase):
    """
    Callback для отправки уведомлений в Telegram
    Использует Telegram Bot API для отправки сообщений
    """
    
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'telegram_notify'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        """Инициализация с параметрами Telegram бота"""
        super(CallbackModule, self).__init__()
        # Токен бота от @BotFather
        self.bot_token = "YOUR_BOT_TOKEN"
        # ID чата (можно получить от @userinfobot)
        self.chat_id = "YOUR_CHAT_ID"
        # Список ошибок для финального отчета
        self.errors = []
    
    def send_message(self, text):
        """
        Отправка сообщения через Telegram Bot API
        
        Args:
            text: текст сообщения (поддерживает Markdown)
        """
        # URL для Telegram Bot API
        url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
        # Параметры запроса
        data = {
            'chat_id': self.chat_id,
            'text': text,
            'parse_mode': 'Markdown'  # Поддержка форматирования
        }
        # POST запрос к API
        requests.post(url, data=data)
    
    def v2_playbook_on_start(self, playbook):
        """
        Уведомление о старте playbook
        
        Args:
            playbook: объект playbook
        """
        message = f"*Ansible Playbook Started*\n`{playbook._file_name}`"
        self.send_message(message)
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        """
        Сохранение информации об ошибках
        
        Args:
            result: объект результата
            ignore_errors: флаг игнорирования
        """
        # Сохраняем только реальные ошибки
        if not ignore_errors:
            host = result._host.get_name()
            task = result._task.get_name()
            # Добавляем в список для финального отчета
            self.errors.append(f"• {host}: {task}")
    
    def v2_playbook_on_stats(self, stats):
        """
        Финальное уведомление с результатами
        
        Args:
            stats: объект статистики
        """
        message = "*Playbook Completed*\n\n"
        
        # Формируем статистику по каждому хосту
        for host in sorted(stats.processed.keys()):
            summary = stats.summarize(host)
            # Определяем статус
            status = "FAILED" if summary['failures'] > 0 else "SUCCESS"
            message += f"[{status}] *{host}*: "
            message += f"ok={summary['ok']} changed={summary['changed']} failed={summary['failures']}\n"
        
        # Добавляем список ошибок если есть
        if self.errors:
            message += f"\n*Errors:*\n" + "\n".join(self.errors)
        
        # Отправляем финальное сообщение
        self.send_message(message)
```

---

## Полный справочник плагинов

### Встроенные Stdout Callbacks

| Callback | Описание | Использование |
|----------|----------|---------------|
| `default` | Стандартный вывод Ansible | `stdout_callback = default` |
| `yaml` | Структурированный YAML | `stdout_callback = yaml` |
| `json` | JSON формат | `stdout_callback = json` |
| `minimal` | Минимальный вывод | `stdout_callback = minimal` |
| `oneline` | Однострочный вывод | `stdout_callback = oneline` |
| `debug` | Детальный вывод для отладки | `stdout_callback = debug` |
| `dense` | Компактный вывод | `stdout_callback = dense` |
| `null` | Без вывода (тихий режим) | `stdout_callback = null` |
| `selective` | Выборочный вывод по regex | `stdout_callback = selective` |
| `actionable` | Только changed/failed | `stdout_callback = actionable` |
| `skippy` | Без пропущенных задач | `stdout_callback = skippy` |
| `unixy` | Unix-style вывод | `stdout_callback = unixy` |

### Встроенные Notification Callbacks

| Callback | Описание | Конфигурация |
|----------|----------|--------------|
| `log_plays` | Логирование в файлы | `[callback_log_plays]`<br>`log_folder = /var/log/ansible` |
| `mail` | Email уведомления | `[callback_mail]`<br>`smtp_host = smtp.gmail.com` |
| `slack` | Slack уведомления | `[callback_slack]`<br>`webhook_url = ...` |
| `jabber` | Jabber/XMPP сообщения | `[callback_jabber]`<br>`server = jabber.org` |
| `hipchat` | HipChat уведомления | `[callback_hipchat]`<br>`token = ...` |
| `logstash` | Отправка в Logstash | `[callback_logstash]`<br>`server = localhost:5000` |
| `splunk` | Отправка в Splunk | `[callback_splunk]`<br>`url = ...` |
| `syslog` | Логирование в syslog | `[callback_syslog]`<br>`facility = local0` |

### Встроенные Aggregate Callbacks

| Callback | Описание | Конфигурация |
|----------|----------|--------------|
| `profile_tasks` | Профилирование задач | `[callback_profile_tasks]`<br>`task_output_limit = 20` |
| `profile_roles` | Профилирование ролей | `[callback_profile_roles]`<br>`task_output_limit = 20` |
| `timer` | Общее время выполнения | `[callback_timer]`<br>`format_string = ...` |
| `cgroup_perf_recap` | Профилирование cgroups | `[callback_cgroup_perf_recap]`<br>`control_group = ansible` |
| `cgroup_memory_recap` | Мониторинг памяти | `[callback_cgroup_memory_recap]` |
| `junit` | JUnit XML отчеты | `[callback_junit]`<br>`output_dir = ./reports` |

### Community Callbacks (community.general)

| Callback | Описание |
|----------|----------|
| `counter_enabled` | Счетчики задач и хостов |
| `context_demo` | Демонстрация контекста |
| `default_without_diff` | Default без diff вывода |
| `diy` | Настраиваемый вывод |
| `elastic` | Отправка в Elasticsearch |
| `logdna` | Интеграция с LogDNA |
| `logentries` | Отправка в Logentries |
| `nrdp` | Nagios NRDP интеграция |
| `sumologic` | Интеграция с Sumo Logic |
| `syslog_json` | JSON в syslog |
| `teams` | Microsoft Teams |
| `say` | Голосовые уведомления (macOS) |

### Cloud Provider Callbacks

#### AWS
```python
# amazon.aws.aws_resource_actions
# Суммирует все действия с AWS ресурсами
```

#### Azure
```python
# azure.azcollection.azure_rm
# Логирование операций Azure
```

### Методы Callback Plugin API

#### Playbook Events

| Метод | Когда вызывается |
|-------|------------------|
| `v2_playbook_on_start(playbook)` | Начало playbook |
| `v2_playbook_on_play_start(play)` | Начало play |
| `v2_playbook_on_task_start(task, is_conditional)` | Начало задачи |
| `v2_playbook_on_cleanup_task_start(task)` | Начало cleanup задачи |
| `v2_playbook_on_handler_task_start(task)` | Начало handler |
| `v2_playbook_on_stats(stats)` | Конец playbook (статистика) |
| `v2_playbook_on_include(included_file)` | Include файла |
| `v2_playbook_on_notify(handler, host)` | Уведомление handler |

#### Task Events

| Метод | Когда вызывается |
|-------|------------------|
| `v2_runner_on_ok(result)` | Успешное выполнение |
| `v2_runner_on_failed(result, ignore_errors)` | Ошибка выполнения |
| `v2_runner_on_skipped(result)` | Пропуск задачи |
| `v2_runner_on_unreachable(result)` | Хост недоступен |
| `v2_runner_on_async_ok(result)` | Async задача завершена |
| `v2_runner_on_async_failed(result)` | Async задача с ошибкой |
| `v2_runner_on_async_poll(result)` | Опрос async задачи |
| `v2_runner_item_on_ok(result)` | Item успешно |
| `v2_runner_item_on_failed(result)` | Item с ошибкой |
| `v2_runner_item_on_skipped(result)` | Item пропущен |
| `v2_runner_retry(result)` | Повтор задачи |

### Использование через CLI

```bash
# Stdout callback
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook playbook.yml

# Notification callbacks
ANSIBLE_CALLBACKS_ENABLED=profile_tasks,timer ansible-playbook playbook.yml

# Комбинация
ANSIBLE_STDOUT_CALLBACK=yaml \
ANSIBLE_CALLBACKS_ENABLED=profile_tasks,timer,log_plays \
ansible-playbook playbook.yml

# Путь к кастомным плагинам
ANSIBLE_CALLBACK_PLUGINS=./callback_plugins \
ANSIBLE_STDOUT_CALLBACK=custom_callback \
ansible-playbook playbook.yml
```

---

## Лучшие практики

### 1. Выбор правильного Callback

**Для разработки и отладки:**
```ini
[defaults]
stdout_callback = yaml
callbacks_enabled = profile_tasks, timer
```

**Для production:**
```ini
[defaults]
stdout_callback = actionable
callbacks_enabled = log_plays, mail
display_skipped_hosts = False
```

**Для CI/CD:**
```ini
[defaults]
stdout_callback = json
callbacks_enabled = junit
```

### 2. Производительность

- Используйте `profile_tasks` для оптимизации медленных задач
- `cgroup_perf_recap` для анализа системных ресурсов
- Не включайте слишком много notification callbacks одновременно

### 3. Безопасность

```python
# Не логировать чувствительные данные
def v2_runner_on_ok(self, result):
    # Удаляем пароли из вывода
    if 'password' in result._result:
        result._result['password'] = '***REDACTED***'
```

### 4. Отладка Callback плагинов

```bash
# Детальный вывод
ANSIBLE_DEBUG=1 ansible-playbook playbook.yml

# Проверка загруженных callbacks
ansible-doc -t callback -l

# Информация о конкретном callback
ansible-doc -t callback profile_tasks
```
