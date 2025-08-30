# Установка Docker на Debian

## 1. Установка зависимостей

sudo apt install -y ca-certificates curl gnupg

| Комментарий |
|-------------|
| Установка пакетов, необходимых для доступа к репозиториям по HTTPS. 
- `install`: Установка указанных пакетов. 
- `-y`: Автоматическое подтверждение действий (yes). 
- `ca-certificates`: Сертификаты для проверки подлинности SSL-соединений. 
- `curl`: Утилита для передачи данных по URL. 
- `gnupg`: Инструменты для работы с GPG (шифрование/подпись). |

---

## 2. Добавление GPG-ключа Docker

sudo install -m 0755 -d /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/debian/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

| Комментарий |
|-------------|
| Импорт официального ключа Docker для проверки подписей пакетов. 
- `install -m 0755 -d`: Создание каталога `/etc/apt/keyrings` с правами `755`. 
- `curl -fsSL`: Безопасная загрузка ключа без вывода прогресса. 
- `gpg --dearmor`: Преобразование ключа в бинарный формат. 
- `-o /etc/apt/keyrings/docker.gpg`: Сохранение ключа в файл. |

---

## 3. Добавление репозитория Docker

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

| Комментарий |
|-------------|
| Настройка APT для использования официального репозитория Docker. 
- `arch=$(dpkg --print-architecture)`: Автоматическое определение архитектуры (например, amd64). 
- `signed-by=/etc/apt/keyrings/docker.gpg`: Путь к ключу для верификации. 
- `$(. /etc/os-release && echo "$VERSION_CODENAME")`: Определение кодового имени Debian (например, bookworm). 
- `tee /etc/apt/sources.list.d/docker.list`: Запись строки репозитория в файл. 
- `> /dev/null`: Подавление вывода. |

---

## 4. Обновление индекса пакетов

sudo apt update

| Комментарий |
|-------------|
| Обновление индексов пакетов, включая новый репозиторий. 
- `update`: Обновление индексов пакетов. |

---

## 5. Установка Docker

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

| Комментарий |
|-------------|
| Установка пакетов Docker Engine, CLI, Containerd и Docker Compose Plugin. 
- `docker-ce`: Docker Community Edition (основной движок). 
- `docker-ce-cli`: Командная строка Docker. 
- `containerd.io`: Среда выполнения контейнеров. 
- `docker-buildx-plugin`: Поддержка расширенной сборки образов. 
- `docker-compose-plugin`: Управление мультиконтейнерными приложениями. |

---

## 6. Проверка работы Docker

sudo docker run hello-world

| Комментарий |
|-------------|
| Запуск тестового контейнера для проверки установки. 
- `run`: Запуск нового контейнера из образа. 
- `hello-world`: Тестовый образ Docker, который выводит приветственное сообщение. |

