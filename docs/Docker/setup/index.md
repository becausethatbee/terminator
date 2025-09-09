# Установка Docker на Debian

## 1. Установка зависимостей  
Установка пакетов, необходимых для доступа к репозиториям по HTTPS.  

```bash
sudo apt install -y ca-certificates curl gnupg
```

| Параметр        | Описание                                                                 |
|-----------------|--------------------------------------------------------------------------|
| install         | Установка указанных пакетов                                               |
| -y              | Автоматическое подтверждение действий (yes)                              |
| ca-certificates | Сертификаты для проверки подлинности SSL-соединений                      |
| curl            | Утилита для передачи данных по URL                                       |
| gnupg           | Инструменты для работы с GPG (шифрование/подпись)                        |

---

## 2. Добавление GPG-ключа Docker  
Импорт официального ключа Docker для проверки подписей пакетов.  

```bash
sudo install -m 0755 -d /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/debian/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

| Параметр                           | Описание                                                       |
|-----------------------------------|----------------------------------------------------------------|
| install -m 0755 -d                | Создание каталога `/etc/apt/keyrings` с правами `755`          |
| curl -fsSL                        | Безопасная загрузка ключа без вывода прогресса                 |
| gpg --dearmor                     | Преобразование ключа в бинарный формат                         |
| -o /etc/apt/keyrings/docker.gpg   | Сохранение ключа в файл                                        |

---

## 3. Добавление репозитория Docker  
Настройка APT для использования официального репозитория Docker.  

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

| Параметр                                     | Описание                                                             |
|---------------------------------------------|----------------------------------------------------------------------|
| arch=$(dpkg --print-architecture)           | Автоматическое определение архитектуры (например, amd64)             |
| signed-by=/etc/apt/keyrings/docker.gpg      | Путь к ключу для верификации                                         |
| $(. /etc/os-release && echo "$VERSION_CODENAME") | Определение кодового имени Debian (например, bookworm)               |
| tee /etc/apt/sources.list.d/docker.list     | Запись строки репозитория в файл                                     |
| > /dev/null                                 | Подавление вывода                                                    |

---

## 4. Обновление индекса пакетов  
После добавления репозитория нужно обновить список пакетов.  

```bash
sudo apt update
```

| Параметр | Описание                                              |
|----------|-------------------------------------------------------|
| update   | Обновление индексов пакетов, включая новый репозиторий |

---

## 5. Установка Docker  
Установка пакетов Docker Engine, CLI, Containerd и Docker Compose Plugin.  

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

| Пакет                 | Описание                                            |
|------------------------|----------------------------------------------------|
| docker-ce              | Docker Community Edition (основной движок)         |
| docker-ce-cli          | Командная строка Docker                            |
| containerd.io          | Среда выполнения контейнеров                       |
| docker-buildx-plugin   | Поддержка расширенной сборки образов               |
| docker-compose-plugin  | Управление мультиконтейнерными приложениями        |

---

## 6. Проверка работы Docker  
Запуск тестового контейнера для проверки установки.  

```bash
sudo docker run hello-world
```

| Параметр     | Описание                                                             |
|--------------|----------------------------------------------------------------------|
| run          | Запуск нового контейнера из образа                                   |
| hello-world  | Тестовый образ Docker, который выводит приветственное сообщение      |



---


# Руководство по установке Docker Compose на Debian 13

## Шаг 1. Установка Docker Engine (при необходимости)

```bash
sudo apt update
sudo apt install docker.io -y
sudo systemctl enable --now docker
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| apt update | Debian | Обновление списка пакетов |
| apt install docker.io -y | Docker | Установка Docker Engine |
| systemctl enable --now docker | System | Включение и запуск сервиса Docker |

---

## Шаг 2. Установка Docker Compose (версия 2 и выше)

###  Вариант A: Через пакетный менеджер apt (рекомендуется)

```bash
sudo apt update
sudo apt install docker-compose-plugin -y
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| apt update | Debian | Обновление списка пакетов |
| apt install docker-compose-plugin -y | Docker Compose | Установка плагина Compose |

Проверка версии:

```bash
docker compose version
```

---

###  Вариант B: Установка вручную (если пакет не доступен)

```bash
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest \
  | grep '"tag_name":' \
  | cut -d '"' -f 4)
sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| curl → COMPOSE_VERSION | Shell | Получение последнего релиз-тега Compose |
| curl -L … -o /usr/local/bin/docker-compose | Download | Загрузка исполняемого файла Compose |
| chmod +x /usr/local/bin/docker-compose | Permissions | Дает права на выполнение |

Проверка версии:

```bash
docker-compose --version
```

---

## Шаг 3. (Опционально) Настройка автодополнения команд (bash)

```bash
sudo apt update && sudo apt install bash-completion -y
curl -L https://raw.githubusercontent.com/docker/compose/v2.20.2/contrib/completion/bash/docker-compose \
  -o ~/.docker-compose-completion.sh
echo 'source ~/.docker-compose-completion.sh' >> ~/.bashrc
source ~/.bashrc
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| apt install bash-completion -y | Shell | Установка автодополнения bash |
| curl … -o ~/.docker-compose-completion.sh | Download | Скачивание скрипта автодополнения |
| echo … >> ~/.bashrc | Shell | Подключение автодополнения |
| source ~/.bashrc | Shell | Активирует изменения в текущей сессии |

---

## Шаг 4. Проверка работоспособности

```bash
docker compose version
```

или, если установлен вручную:

```bash
docker-compose --version
```

Версия отображается — установка успешна.

---

##  Сводка

| Шаг | Действие |
|-----|----------|
| 1 | Установка Docker Engine (`docker.io`) |
| 2 | Установка Docker Compose (через `docker-compose-plugin` или ручное скачивание) |
| 3 | (По желанию) Настройка автодополнения в bash |
| 4 | Проверка корректности установки через версию |
