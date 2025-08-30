# Установка Docker на Debian

## 1. Установка зависимостей
Установка пакетов, необходимых для доступа к репозиториям по HTTPS.

```bash
sudo apt install -y ca-certificates curl gnupg
```

- `install`: Установка указанных пакетов.  
- `-y`: Автоматическое подтверждение действий (yes).  
- `ca-certificates`: Сертификаты для проверки подлинности SSL-соединений.  
- `curl`: Утилита для передачи данных по URL.  
- `gnupg`: Инструменты для работы с GPG (шифрование/подпись).  

---

## 2. Добавление GPG-ключа Docker
Импорт официального ключа Docker для проверки подписей пакетов.

```bash
sudo install -m 0755 -d /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/debian/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

- `install -m 0755 -d`: Создание каталога `/etc/apt/keyrings` с правами `755`.  
- `curl -fsSL`: Безопасная загрузка ключа без вывода прогресса.  
- `gpg --dearmor`: Преобразование ключа в бинарный формат.  
- `-o /etc/apt/keyrings/docker.gpg`: Сохранение ключа в файл.  

---

## 3. Добавление репозитория Docker
Настройка APT для использования официального репозитория Docker.

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

- `arch=$(dpkg --print-architecture)`: Автоматическое определение архитектуры (например, amd64).  
- `signed-by=/etc/apt/keyrings/docker.gpg`: Путь к ключу для верификации.  
- `$(. /etc/os-release && echo "$VERSION_CODENAME")`: Определение кодового имени Debian (например, bookworm).  
- `tee /etc/apt/sources.list.d/docker.list`: Запись строки репозитория в файл.  
- `> /dev/null`: Подавление вывода.  

---

## 4. Обновление индекса пакетов
После добавления репозитория нужно обновить список пакетов.

```bash
sudo apt update
```

- `update`: Обновление индексов пакетов, включая новый репозиторий.  

---

## 5. Установка Docker
Установка пакетов Docker Engine, CLI, Containerd и Docker Compose Plugin.

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

- `docker-ce`: Docker Community Edition (основной движок).  
- `docker-ce-cli`: Командная строка Docker.  
- `containerd.io`: Среда выполнения контейнеров.  
- `docker-buildx-plugin`: Поддержка расширенной сборки образов.  
- `docker-compose-plugin`: Управление мультиконтейнерными приложениями.  

---

## 6. Проверка работы Docker
Запуск тестового контейнера для проверки установки.

```bash
sudo docker run hello-world
```

- `run`: Запуск нового контейнера из образа.  
- `hello-world`: Тестовый образ Docker, который выводит приветственное сообщение.  
