# Расширенный справочник по UFW (Uncomplicated Firewall) на Debian

---

## 1. Установка и базовая настройка

```bash
sudo apt update
sudo apt install ufw
```

| Команда | Назначение |
|---------|------------|
| sudo apt update | Обновление индекса пакетов |
| sudo apt install ufw | Установка Uncomplicated Firewall (UFW) |

---

## 2. Политики по умолчанию

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

| Команда | Назначение |
|---------|------------|
| ufw default deny incoming | Блокировка всех входящих подключений по умолчанию |
| ufw default allow outgoing | Разрешение всех исходящих подключений |

---

## 3. Разрешение и блокировка портов/сервисов

### Разрешение стандартных служб
```bash
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
```

| Команда | Назначение |
|---------|------------|
| ufw allow ssh | Разрешает SSH-подключения (порт 22) |
| ufw allow http | Разрешает HTTP-трафик (порт 80) |
| ufw allow https | Разрешает HTTPS-трафик (порт 443) |

### Разрешение конкретного порта
```bash
sudo ufw allow 8080/tcp
```

### Разрешение диапазона портов
```bash
sudo ufw allow 9000:9005/tcp
```

### Блокировка порта
```bash
sudo ufw deny 3306/tcp
```

### Разрешение по IP-адресу или подсети
```bash
sudo ufw allow from 192.168.1.50
sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
```

### Блокировка конкретного IP
```bash
sudo ufw deny from 192.168.1.100
```

### Удаление правила
```bash
sudo ufw delete allow 8080/tcp
```

---

## 4. Активация и деактивация UFW

```bash
sudo ufw enable
sudo ufw disable
```

| Команда | Назначение |
|---------|------------|
| ufw enable | Включение UFW с текущими правилами |
| ufw disable | Полное отключение фаервола |

---

## 5. Проверка и управление статусом

```bash
sudo ufw status
sudo ufw status verbose
sudo ufw status numbered
```

| Команда | Назначение |
|---------|------------|
| ufw status | Отображение активных правил |
| ufw status verbose | Подробная информация о правилах |
| ufw status numbered | Отображение правил с номерами для удаления |

---

## 6. Управление профилями приложений

```bash
sudo ufw app list
sudo ufw app info "OpenSSH"
sudo ufw allow "OpenSSH"
```

| Команда | Назначение |
|---------|------------|
| ufw app list | Список доступных профилей приложений |
| ufw app info "APP" | Информация о конкретном профиле |
| ufw allow "APP" | Разрешение трафика для приложения по профилю |

---

## 7. Настройка логирования

```bash
sudo ufw logging on
sudo ufw logging high
sudo ufw logging off
```

| Команда | Назначение |
|---------|------------|
| ufw logging on | Включение базового логирования |
| ufw logging high | Подробное логирование блокировок и разрешений |
| ufw logging off | Отключение логирования |

---

## 8. Настройка IPv6

```bash
sudo nano /etc/default/ufw
```

| Параметр | Описание |
|-----------|----------|
| IPV6=yes | Включение поддержки IPv6 |
| IPV6=no | Отключение поддержки IPv6 |

После изменения файла необходимо перезапустить UFW:
```bash
sudo ufw disable
sudo ufw enable
```

---

## 9. Дополнительные команды управления

```bash
sudo ufw reset
sudo ufw status verbose
```

| Команда | Назначение |
|---------|------------|
| ufw reset | Сброс всех правил к значениям по умолчанию |
| ufw status verbose | Проверка текущего состояния после сброса |

---

## 10. Советы по безопасности

- Всегда блокируйте все входящие соединения по умолчанию и открывайте только необходимые порты.  
- Разрешайте SSH только с доверенных IP-адресов или используйте ключи вместо пароля.  
- Регулярно проверяйте активные правила через `ufw status numbered`.  
- Используйте профили приложений для упрощения управления службами.  
- Включайте логирование для мониторинга попыток несанкционированного доступа.  
- Проверяйте совместимость с IPv6, если используется.  

---

## 11. Полезные сочетания команд

| Действие | Команда |
|-----------|---------|
| Разрешение порта TCP | `sudo ufw allow PORT/tcp` |
| Разрешение порта UDP | `sudo ufw allow PORT/udp` |
| Разрешение диапазона портов | `sudo ufw allow START:END/tcp` |
| Разрешение порта только для IP | `sudo ufw allow from IP to any port PORT` |
| Блокировка IP | `sudo ufw deny from IP` |
| Удаление правила по номеру | `sudo ufw delete NUM` |
