# Установка Docker

## Установка зависимостей

Установка пакетов, необходимых для доступа к репозиториям по HTTPS:

    sudo apt install -y ca-certificates curl gnupg

**Описание параметров:**
- **install**: Установка указанных пакетов.  
- **-y**: Автоматическое подтверждение действий (yes).  
- **ca-certificates**: Сертификаты для проверки подлинности SSL-соединений.  
- **curl**: Утилита для передачи данных по URL.  
- **gnupg**: Инструменты для работы с GPG (шифрование/подпись).  

---

## Добавление GPG-ключа Docker

Импорт официального ключа Docker для проверки подписей пакетов:

    sudo install -m 0755 -d /etc/apt/keyrings \
      && curl -fsSL https://download.docker.com/linux/debian/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

**Описание параметров:**
- **install -m 0755 -d**: Создание каталога `/etc/apt/keyrings` с правами `755`.  
- **curl -fsSL**: Безопасная загрузка ключа без прогресса (`-f`, `-s`, `-L`).  
- **gpg --dearmor**: Преобразование ключа из ASCII-armored в бинарный формат.  
- **-o /etc/apt/keyrings/docker.gpg**: Сохранение ключа в указанный файл.  

---

## Добавление репозитория Docker

Настройка APT для использования официального репозитория Docker:

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

**Описание параметров:**
- **deb [arch=...] ... stable**: Строка репозитория.  
  - **arch=$(dpkg --print-architecture)**: Автоматическое определение архитектуры системы (например, `amd64`).  
  - **signed-by=/etc/apt/keyrings/docker.gpg**: Путь к ключу для верификации.  
  - **$(. /etc/os-release && echo "$VERSION_CODENAME")**: Определение кодового имени Debian (например, `bookworm`).  
- **tee /etc/apt/sources.list.d/docker.list**: Запись строки репозитория в файл.  
- **> /dev/null**: Подавление вывода в терминал.  

---

## Обновление индекса пакетов

После добавления репозитория необходимо обновить список пакетов:

    sudo apt update

**Описание параметров:**
- **update**: Обновление индексов, включая новый репозиторий Docker.  

---

## Установка Docker

Установка Docker Engine, CLI, Containerd и Docker Compose Plugin:

    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

**Описание пакетов:**
- **docker-ce**: Docker Community Edition (основной движок).  
- **docker-ce-cli**: Командная строка Docker.  
- **containerd.io**: Среда выполнения контейнеров (CRI).  
- **docker-buildx-plugin**: Поддержка расширенной сборки образов.  
- **docker-compose-plugin**: Плагин для мультиконтейнерных приложений (заменяет `docker-compose`).  

---

## Проверка работы Docker

Запуск тестового контейнера:

    sudo docker run hello-world

**Описание параметров:**
- **run**: Запуск нового контейнера из образа.  
- **hello-world**: Официальный тестовый образ Docker. Выводит приветственное сообщение при успешной установке.  
