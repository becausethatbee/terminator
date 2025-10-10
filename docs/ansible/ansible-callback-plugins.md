# Ansible Callback плагины

Компоненты Ansible для настройки формата вывода, логирования и интеграции с внешними системами.

## Функциональность

Callback плагины обеспечивают:
- Настройку формата вывода playbook
- Логирование в различные backend системы
- Интеграцию с системами уведомлений
- Профилирование производительности
- Кастомизацию отображения результатов

---

## Типы Callback плагинов

### Stdout Callbacks

Управление выводом в консоль. Активен только один stdout callback.

Настройка через `stdout_callback` в ansible.cfg.

Примеры: `default`, `yaml`, `json`, `minimal`

### Notification Callbacks

Отправка информации во внешние системы. Можно активировать несколько.

Настройка через `callbacks_enabled` в ansible.cfg.

Примеры: `mail`, `slack`, `log_plays`, `junit`

### Aggregate Callbacks

Сбор метрик и статистики. Работают в фоновом режиме.

Примеры: `profile_tasks`, `timer`, `cgroup_perf_recap`

---

## Настройка через ansible.cfg

### Базовая конфигурация

```ini
[defaults]
stdout_callback = yaml
bin_ansible_callbacks = True
callbacks_enabled = profile_tasks, timer, log_plays
display_skipped_hosts = False
display_ok_hosts = True
display_failed_stderr = True
force_color = True
callback_plugins = ~/.ansible/plugins/callback:/usr/share/ansible/plugins/callback
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

[callback_profile_tasks]
task_output_limit = 20
sort_order = descending

[callback_timer]
format_string = "Playbook execution took {days} days, {hours} hours, {minutes} minutes, {seconds} seconds"

[callback_log_plays]
log_folder = /var/log/ansible/playbooks
log_date_format = %Y-%m-%d_%H-%M-%S

[callback_mail]
smtp_host = smtp.gmail.com
smtp_port = 587
smtp_user = ansible@example.com
smtp_password = <PASSWORD>
mail_to = admin@example.com
mail_from = ansible@example.com

[callback_slack]
webhook_url = https://hooks.slack.com/services/<WEBHOOK_PATH>
channel = #ansible
username = Ansible Bot
```

---

## Встроенные Callback плагины

### Default

Стандартный вывод Ansible:

```ini
[defaults]
stdout_callback = default
```

### YAML

Структурированный YAML вывод:

```ini
[defaults]
stdout_callback = yaml
bin_ansible_callbacks = True
```

Через CLI:

```bash
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook playbook.yml
```

### JSON

JSON формат для программной обработки:

```ini
[defaults]
stdout_callback = json
```

### Minimal

Минимальный вывод:

```ini
[defaults]
stdout_callback = minimal
```

### Oneline

Однострочный вывод:

```ini
[defaults]
stdout_callback = oneline
```

### Profile_tasks

Профилирование времени выполнения:

```ini
[defaults]
callbacks_enabled = profile_tasks

[callback_profile_tasks]
task_output_limit = 20
sort_order = descending
```

Вывод:

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

### Timer

Общее время выполнения:

```ini
[defaults]
callbacks_enabled = timer
```

### Actionable

Только задачи с изменениями или ошибками:

```ini
[defaults]
stdout_callback = actionable
display_skipped_hosts = False
display_ok_hosts = False
```

### Debug

Расширенный вывод для отладки:

```ini
[defaults]
stdout_callback = debug
```

### Selective

Фильтрация задач по regex:

```ini
[defaults]
stdout_callback = selective

[callback_selective]
task_name_regex = "Install|Configure"
```

---

## Создание собственного Callback

### Минимальные требования

1. Python файл в `callback_plugins/`
2. Наследование от CallbackBase
3. Метаданные плагина
4. DOCUMENTATION блок
5. Реализация методов событий

Структура директорий:

```
project/
├── ansible.cfg
├── playbook.yml
└── callback_plugins/
    └── my_callback.py
```

### Базовая структура

```python
# callback_plugins/custom_callback.py

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
from datetime import datetime
import json

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
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'custom_callback'
    
    def __init__(self):
        super(CallbackModule, self).__init__()
        self.start_time = datetime.now()
    
    def v2_playbook_on_start(self, playbook):
        self._display.banner("PLAYBOOK START")
        self._display.display(f"Starting playbook: {playbook._file_name}")
        self._display.display(f"Time: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    
    def v2_playbook_on_play_start(self, play):
        name = play.get_name().strip()
        self._display.banner(f"PLAY: {name}")
    
    def v2_playbook_on_task_start(self, task, is_conditional):
        task_name = task.get_name().strip()
        timestamp = datetime.now().strftime('%H:%M:%S')
        self._display.display(f"[{timestamp}] TASK: {task_name}", color='bright blue')
    
    def v2_runner_on_ok(self, result):
        host = result._host.get_name()
        task_name = result._task.get_name()
        
        if result._result.get('changed', False):
            status = "CHANGED"
            color = 'yellow'
        else:
            status = "OK"
            color = 'green'
        
        msg = f"  [{status}] {host}: {task_name}"
        
        if 'msg' in result._result:
            msg += f"\n    Message: {result._result['msg']}"
        
        self._display.display(msg, color=color)
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        host = result._host.get_name()
        task_name = result._task.get_name()
        
        msg = f"  [FAILED] {host}: {task_name}"
        
        if 'msg' in result._result:
            msg += f"\n    Error: {result._result['msg']}"
        
        if ignore_errors:
            msg += "\n    (ignored)"
            color = 'yellow'
        else:
            color = 'red'
        
        self._display.display(msg, color=color)
    
    def v2_runner_on_skipped(self, result):
        host = result._host.get_name()
        task_name = result._task.get_name()
        
        self._display.display(
            f"  [SKIPPED] {host}: {task_name}",
            color='cyan'
        )
    
    def v2_runner_on_unreachable(self, result):
        host = result._host.get_name()
        
        self._display.display(
            f"  [UNREACHABLE] {host}: Host is unreachable",
            color='bright red'
        )
    
    def v2_playbook_on_stats(self, stats):
        end_time = datetime.now()
        duration = end_time - self.start_time
        
        self._display.banner("PLAY RECAP")
        
        hosts = sorted(stats.processed.keys())
        for host in hosts:
            summary = stats.summarize(host)
            
            msg = (
                f"{host:30} : "
                f"ok={summary['ok']:4} "
                f"changed={summary['changed']:4} "
                f"unreachable={summary['unreachable']:4} "
                f"failed={summary['failures']:4} "
                f"skipped={summary['skipped']:4}"
            )
            
            if summary['failures'] > 0 or summary['unreachable'] > 0:
                color = 'red'
            elif summary['changed'] > 0:
                color = 'yellow'
            else:
                color = 'green'
            
            self._display.display(msg, color=color)
        
        self._display.display(f"\nPlaybook duration: {duration}", color='bright blue')
```

### Notification Callback - Slack

```python
# callback_plugins/slack_notification.py

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
import json
import requests

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
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'slack_notification'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        super(CallbackModule, self).__init__()
        self.playbook_name = None
        self.errors = []
    
    def set_options(self, task_keys=None, var_options=None, direct=None):
        super(CallbackModule, self).set_options(task_keys=task_keys, 
                                                  var_options=var_options, 
                                                  direct=direct)
        
        self.webhook_url = self.get_option('webhook_url')
        self.channel = self.get_option('channel')
    
    def send_slack_message(self, message, color='good'):
        payload = {
            'channel': self.channel,
            'username': 'Ansible Bot',
            'icon_emoji': ':ansible:',
            'attachments': [
                {
                    'color': color,
                    'text': message,
                    'mrkdwn_in': ['text']
                }
            ]
        }
        
        try:
            response = requests.post(
                self.webhook_url,
                data=json.dumps(payload),
                headers={'Content-Type': 'application/json'}
            )
            response.raise_for_status()
        except Exception as e:
            self._display.warning(f"Failed to send Slack message: {str(e)}")
    
    def v2_playbook_on_start(self, playbook):
        self.playbook_name = playbook._file_name
        message = f"*Playbook Started*\n`{self.playbook_name}`"
        self.send_slack_message(message, color='#36a64f')
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        if not ignore_errors:
            host = result._host.get_name()
            task = result._task.get_name()
            error_msg = result._result.get('msg', 'Unknown error')
            self.errors.append(f"• {host}: {task}\n  Error: {error_msg}")
    
    def v2_playbook_on_stats(self, stats):
        hosts = sorted(stats.processed.keys())
        
        message = f"*Playbook Completed:* `{self.playbook_name}`\n\n"
        
        for host in hosts:
            summary = stats.summarize(host)
            message += (
                f"*{host}*\n"
                f"  OK: {summary['ok']}  "
                f"Changed: {summary['changed']}  "
                f"Failed: {summary['failures']}\n"
            )
        
        if self.errors:
            message += "\n*Errors:*\n" + "\n".join(self.errors)
            color = 'danger'
        else:
            message += "\n*All tasks completed successfully!*"
            color = 'good'
        
        self.send_slack_message(message, color=color)
```

### Log Callback

```python
# callback_plugins/detailed_log.py

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.callback import CallbackBase
from datetime import datetime
import json
import os

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'detailed_log'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        super(CallbackModule, self).__init__()
        
        log_dir = '/var/log/ansible'
        os.makedirs(log_dir, exist_ok=True)
        
        timestamp = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        self.log_file = f"{log_dir}/ansible_{timestamp}.log"
        
        self.log_handle = open(self.log_file, 'w')
    
    def log(self, message):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        self.log_handle.write(f"[{timestamp}] {message}\n")
        self.log_handle.flush()
    
    def v2_playbook_on_start(self, playbook):
        self.log(f"=== PLAYBOOK START: {playbook._file_name} ===")
    
    def v2_playbook_on_play_start(self, play):
        name = play.get_name().strip()
        self.log(f"--- PLAY: {name} ---")
    
    def v2_playbook_on_task_start(self, task, is_conditional):
        task_name = task.get_name().strip()
        self.log(f"TASK: {task_name}")
    
    def v2_runner_on_ok(self, result):
        host = result._host.get_name()
        task = result._task.get_name()
        
        if result._result.get('changed', False):
            status = "CHANGED"
        else:
            status = "OK"
        
        self.log(f"  [{status}] {host}: {task}")
        
        if result._result:
            self.log(f"    Result: {json.dumps(result._result, indent=2)}")
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        host = result._host.get_name()
        task = result._task.get_name()
        
        self.log(f"  [FAILED] {host}: {task}")
        self.log(f"    Error: {json.dumps(result._result, indent=2)}")
    
    def v2_playbook_on_stats(self, stats):
        self.log("=== PLAY RECAP ===")
        
        hosts = sorted(stats.processed.keys())
        for host in hosts:
            summary = stats.summarize(host)
            self.log(
                f"{host}: ok={summary['ok']} changed={summary['changed']} "
                f"unreachable={summary['unreachable']} failed={summary['failures']}"
            )
        
        self.log(f"=== LOG SAVED TO: {self.log_file} ===")
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
webhook_url = https://hooks.slack.com/services/<WEBHOOK_PATH>
channel = #ansible
```

Через переменные окружения:

```bash
export ANSIBLE_CALLBACK_PLUGINS=./callback_plugins
export ANSIBLE_STDOUT_CALLBACK=custom_callback
export ANSIBLE_CALLBACKS_ENABLED=slack_notification,detailed_log

ansible-playbook playbook.yml
```

---

## Интеграция с внешними системами

### Email

```ini
[defaults]
callbacks_enabled = mail

[callback_mail]
smtp_host = smtp.gmail.com
smtp_port = 587
smtp_user = ansible@example.com
smtp_password = <PASSWORD>
mail_to = admin@example.com, team@example.com
mail_from = ansible@example.com
mail_subject_fail = "[ANSIBLE] Playbook Failed: {{ playbook_name }}"
mail_subject_success = "[ANSIBLE] Playbook Success: {{ playbook_name }}"
```

### Prometheus метрики

```python
# callback_plugins/prometheus_metrics.py

from ansible.plugins.callback import CallbackBase
from prometheus_client import Counter, Histogram, push_to_gateway
import time

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'prometheus_metrics'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        super(CallbackModule, self).__init__()
        
        self.task_counter = Counter(
            'ansible_tasks_total',
            'Total number of tasks',
            ['status', 'host']
        )
        
        self.task_duration = Histogram(
            'ansible_task_duration_seconds',
            'Task duration in seconds',
            ['task_name', 'host']
        )
        
        self.task_start_time = {}
    
    def v2_playbook_on_task_start(self, task, is_conditional):
        task_name = task.get_name()
        self.task_start_time[task_name] = time.time()
    
    def v2_runner_on_ok(self, result):
        host = result._host.get_name()
        task = result._task.get_name()
        
        status = 'changed' if result._result.get('changed') else 'ok'
        self.task_counter.labels(status=status, host=host).inc()
        
        if task in self.task_start_time:
            duration = time.time() - self.task_start_time[task]
            self.task_duration.labels(task_name=task, host=host).observe(duration)
    
    def v2_playbook_on_stats(self, stats):
        push_to_gateway(
            'localhost:9091',
            job='ansible',
            registry=self.task_counter._metrics
        )
```

### Elasticsearch

```python
# callback_plugins/elasticsearch_log.py

from ansible.plugins.callback import CallbackBase
from elasticsearch import Elasticsearch
from datetime import datetime
import json

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'elasticsearch_log'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        super(CallbackModule, self).__init__()
        self.es = Elasticsearch(['http://localhost:9200'])
        self.playbook_id = None
    
    def v2_playbook_on_start(self, playbook):
        self.playbook_id = f"playbook_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        doc = {
            'timestamp': datetime.now().isoformat(),
            'type': 'playbook_start',
            'playbook': playbook._file_name,
            'playbook_id': self.playbook_id
        }
        
        self.es.index(index='ansible-logs', document=doc)
    
    def v2_runner_on_ok(self, result):
        doc = {
            'timestamp': datetime.now().isoformat(),
            'type': 'task_result',
            'playbook_id': self.playbook_id,
            'host': result._host.get_name(),
            'task': result._task.get_name(),
            'status': 'changed' if result._result.get('changed') else 'ok',
            'result': result._result
        }
        
        self.es.index(index='ansible-logs', document=doc)
```

### Telegram

```python
# callback_plugins/telegram_notify.py

from ansible.plugins.callback import CallbackBase
import requests
import json

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'telegram_notify'
    CALLBACK_NEEDS_ENABLED = True
    
    def __init__(self):
        super(CallbackModule, self).__init__()
        self.bot_token = "<BOT_TOKEN>"
        self.chat_id = "<CHAT_ID>"
        self.errors = []
    
    def send_message(self, text):
        url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
        data = {
            'chat_id': self.chat_id,
            'text': text,
            'parse_mode': 'Markdown'
        }
        requests.post(url, data=data)
    
    def v2_playbook_on_start(self, playbook):
        message = f"*Ansible Playbook Started*\n`{playbook._file_name}`"
        self.send_message(message)
    
    def v2_runner_on_failed(self, result, ignore_errors=False):
        if not ignore_errors:
            host = result._host.get_name()
            task = result._task.get_name()
            self.errors.append(f"• {host}: {task}")
    
    def v2_playbook_on_stats(self, stats):
        message = "*Playbook Completed*\n\n"
        
        for host in sorted(stats.processed.keys()):
            summary = stats.summarize(host)
            status = "FAILED" if summary['failures'] > 0 else "SUCCESS"
            message += f"[{status}] *{host}*: "
            message += f"ok={summary['ok']} changed={summary['changed']} failed={summary['failures']}\n"
        
        if self.errors:
            message += f"\n*Errors:*\n" + "\n".join(self.errors)
        
        self.send_message(message)
```

---

## Справочник плагинов

### Stdout Callbacks

| Callback | Описание | Использование |
|----------|----------|---------------|
| `default` | Стандартный вывод | `stdout_callback = default` |
| `yaml` | Структурированный YAML | `stdout_callback = yaml` |
| `json` | JSON формат | `stdout_callback = json` |
| `minimal` | Минимальный вывод | `stdout_callback = minimal` |
| `oneline` | Однострочный вывод | `stdout_callback = oneline` |
| `debug` | Детальный вывод | `stdout_callback = debug` |
| `dense` | Компактный вывод | `stdout_callback = dense` |
| `null` | Без вывода | `stdout_callback = null` |
| `selective` | Выборочный по regex | `stdout_callback = selective` |
| `actionable` | Только changed/failed | `stdout_callback = actionable` |
| `skippy` | Без пропущенных задач | `stdout_callback = skippy` |
| `unixy` | Unix-style вывод | `stdout_callback = unixy` |

### Notification Callbacks

| Callback | Описание | Конфигурация |
|----------|----------|--------------|
| `log_plays` | Логирование в файлы | `[callback_log_plays]`<br>`log_folder = /var/log/ansible` |
| `mail` | Email уведомления | `[callback_mail]`<br>`smtp_host = smtp.gmail.com` |
| `slack` | Slack уведомления | `[callback_slack]`<br>`webhook_url = ...` |
| `jabber` | Jabber/XMPP | `[callback_jabber]`<br>`server = jabber.org` |
| `hipchat` | HipChat уведомления | `[callback_hipchat]`<br>`token = ...` |
| `logstash` | Отправка в Logstash | `[callback_logstash]`<br>`server = localhost:5000` |
| `splunk` | Отправка в Splunk | `[callback_splunk]`<br>`url = ...` |
| `syslog` | Логирование в syslog | `[callback_syslog]`<br>`facility = local0` |

### Aggregate Callbacks

| Callback | Описание | Конфигурация |
|----------|----------|--------------|
| `profile_tasks` | Профилирование задач | `[callback_profile_tasks]`<br>`task_output_limit = 20` |
| `profile_roles` | Профилирование ролей | `[callback_profile_roles]`<br>`task_output_limit = 20` |
| `timer` | Общее время выполнения | `[callback_timer]`<br>`format_string = ...` |
| `cgroup_perf_recap` | Профилирование cgroups | `[callback_cgroup_perf_recap]`<br>`control_group = ansible` |
| `cgroup_memory_recap` | Мониторинг памяти | `[callback_cgroup_memory_recap]` |
| `junit` | JUnit XML отчеты | `[callback_junit]`<br>`output_dir = ./reports` |

### Community Callbacks

| Callback | Описание |
|----------|----------|
| `counter_enabled` | Счетчики задач и хостов |
| `context_demo` | Демонстрация контекста |
| `default_without_diff` | Default без diff |
| `diy` | Настраиваемый вывод |
| `elastic` | Отправка в Elasticsearch |
| `logdna` | Интеграция с LogDNA |
| `logentries` | Отправка в Logentries |
| `nrdp` | Nagios NRDP |
| `sumologic` | Интеграция с Sumo Logic |
| `syslog_json` | JSON в syslog |
| `teams` | Microsoft Teams |
| `say` | Голосовые уведомления (macOS) |

### Методы Callback API

#### Playbook Events

| Метод | Вызов |
|-------|-------|
| `v2_playbook_on_start(playbook)` | Начало playbook |
| `v2_playbook_on_play_start(play)` | Начало play |
| `v2_playbook_on_task_start(task, is_conditional)` | Начало задачи |
| `v2_playbook_on_cleanup_task_start(task)` | Начало cleanup задачи |
| `v2_playbook_on_handler_task_start(task)` | Начало handler |
| `v2_playbook_on_stats(stats)` | Конец playbook (статистика) |
| `v2_playbook_on_include(included_file)` | Include файла |
| `v2_playbook_on_notify(handler, host)` | Уведомление handler |

#### Task Events

| Метод | Вызов |
|-------|-------|
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

---

## Использование через CLI

```bash
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook playbook.yml

ANSIBLE_CALLBACKS_ENABLED=profile_tasks,timer ansible-playbook playbook.yml

ANSIBLE_STDOUT_CALLBACK=yaml \
ANSIBLE_CALLBACKS_ENABLED=profile_tasks,timer,log_plays \
ansible-playbook playbook.yml

ANSIBLE_CALLBACK_PLUGINS=./callback_plugins \
ANSIBLE_STDOUT_CALLBACK=custom_callback \
ansible-playbook playbook.yml
```

---

## Best Practices

### Выбор callback

Development и отладка:

```ini
[defaults]
stdout_callback = yaml
callbacks_enabled = profile_tasks, timer
```

Production:

```ini
[defaults]
stdout_callback = actionable
callbacks_enabled = log_plays, mail
display_skipped_hosts = False
```

CI/CD:

```ini
[defaults]
stdout_callback = json
callbacks_enabled = junit
```

### Производительность

Использование `profile_tasks` для оптимизации медленных задач.

Использование `cgroup_perf_recap` для анализа системных ресурсов.

Ограничение количества активных notification callbacks.

### Безопасность

Исключение чувствительных данных из логов:

```python
def v2_runner_on_ok(self, result):
    if 'password' in result._result:
        result._result['password'] = '***REDACTED***'
```

### Отладка

```bash
ANSIBLE_DEBUG=1 ansible-playbook playbook.yml

ansible-doc -t callback -l

ansible-doc -t callback profile_tasks
```
