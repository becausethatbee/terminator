# Установка Docker

## Подготовка системы (Ubuntu/Debian)

### Обновление пакетного менеджера

```bash
sudo apt update && sudo apt upgrade -y
```

### Установка зависимостей

```bash
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
```

## Установка Docker

### Добавление официального GPG-ключа Docker

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

### Добавление репозитория Docker в sources.list

```bash
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Установка Docker Engine

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

## Настройка Docker после установки

### Добавление пользователя в группу docker

```bash
sudo usermod -aG docker $USER
```

### Применение изменений групп

```bash
newgrp docker
```

### Проверка установки Docker

```bash
docker --version
```

### Запуск тестового контейнера

```bash
docker run hello-world
```

## Настройка автозапуска и управления службой Docker

### Включение автозапуска Docker

```bash
sudo systemctl enable docker
```

### Запуск службы Docker

```bash
sudo systemctl start docker
```

### Проверка статуса службы Docker

```bash
sudo systemctl status docker
```

## Установка Docker Compose (отдельно)

### Скачивание актуальной версии Docker Compose

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

### Установка прав на выполнение

```bash
sudo chmod +x /usr/local/bin/docker-compose
```

### Проверка установки Docker Compose

```bash
docker-compose --version
```

## Устранение常见 проблем

### Если команды Docker требуют sudo

```bash
# Выйдите и снова войдите в систему после добавления в группу docker
exit
```

### Проверка членства в группах

```bash
groups
```

### Перезагрузка демона Docker

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Дополнительные полезные команды

### Просмотр информации о Docker

```bash
docker info
```

### Просмотр установленных образов

```bash
docker images
```

### Просмотр запущенных контейнеров

```bash
docker ps
```

### Просмотр всех контейнеров (включая остановленные)

```bash
docker ps -a
```

## Обновление Docker

### Обновление списка пакетов

```bash
sudo apt update
```

### Обновление Docker

```bash
sudo apt upgrade docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

## Удаление Docker

### Остановка всех контейнеров

```bash
docker stop $(docker ps -aq)
```

### Удаление всех контейнеров

```bash
docker rm $(docker ps -aq)
```

### Удаление всех образов

```bash
docker rmi $(docker images -q)
```

### Удаление Docker Engine

```bash
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### Удаление конфигурационных файлов

```bash
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
```

---

*Примечание: Для применения изменений групп может потребоваться перезагрузка системы или повторный вход в учетную запись.*
