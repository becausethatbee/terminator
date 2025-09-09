# Docker Compose: Flask + PostgreSQL

## Подготовка структуры проекта

### Создание директории приложения

```bash
mkdir -p app
```

| Команда | Категория | Описание |
|---------|-----------|----------|
| mkdir -p app | Linux | Создает директорию `app` для кода приложения (флаг `-p` позволяет избежать ошибки, если директория уже существует) |

---

## Flask-приложение

### Создание файла `app.py`

```bash
cat > app/app.py << 'EOF'
from flask import Flask
import psycopg2
app = Flask(__name__)
@app.route('/')
def home():
    try:
        conn = psycopg2.connect(
            dbname="mydatabase",
            user="user",
            password="password",
            host="db"
        )
        conn.close()
        return "Connected to the database successfully!"
    except Exception as e:
        return f"Error: {e}"
if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
EOF
```

| Команда | Категория | Описание |
|---------|-----------|----------|
| cat > app/app.py << 'EOF' | Linux | Создает файл `app.py` с кодом Flask-приложения |
| Flask | Python Web Framework | Минимальное веб-приложение |
| psycopg2 | Python DB Driver | Драйвер PostgreSQL для Python |

---

### Создание файла зависимостей `requirements.txt`

```bash
cat > app/requirements.txt << 'EOF'
flask
psycopg2-binary
EOF
```

| Команда | Категория | Описание |
|---------|-----------|----------|
| cat > app/requirements.txt | Linux | Создает файл зависимостей Python |
| flask | PyPI пакет | Фреймворк для веб-приложений |
| psycopg2-binary | PyPI пакет | Бинарный драйвер PostgreSQL для Python |

---

### Создание Dockerfile

```bash
cat > app/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "app.py"]
EOF
```

| Секция | Категория | Описание |
|--------|-----------|----------|
| FROM python:3.9-slim | Base Image | Используется официальный легковесный образ Python |
| WORKDIR /app | Dockerfile | Рабочая директория внутри контейнера |
| COPY requirements.txt . | Files | Копирует список зависимостей |
| RUN pip install ... | Build | Устанавливает зависимости |
| COPY . . | Files | Копирует все файлы приложения |
| CMD ["python", "app.py"] | Entrypoint | Запускает приложение |

---

## Конфигурация Docker Compose

### Создание файла `docker-compose.yml`

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  db:
    image: postgres:13
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydatabase
    volumes:
      - postgres_data:/var/lib/postgresql/data
  web:
    build: ./app
    ports:
      - "5000:5000"
    depends_on:
      - db
volumes:
  postgres_data:
EOF
```

| Секция | Категория | Описание |
|--------|-----------|----------|
| version: '3.8' | Compose | Версия формата файла Docker Compose |
| db | Service | Сервис базы данных PostgreSQL |
| image: postgres:13 | Docker Image | Используется официальный образ PostgreSQL |
| environment | Config | Переменные окружения: логин, пароль, база данных |
| volumes | Storage | Создает volume `postgres_data` для хранения данных |
| web | Service | Flask-приложение |
| build: ./app | Dockerfile | Сборка приложения из папки `app` |
| ports: "5000:5000" | Networking | Проброс порта приложения наружу |
| depends_on: db | Dependency | Гарантирует, что БД запустится до веб-сервиса |

---

## Запуск проекта

### Сборка и запуск контейнеров

```bash
docker-compose up -d --build
```

| Команда | Категория | Описание |
|---------|-----------|----------|
| docker-compose up | Docker Compose | Запускает все сервисы |
| -d | Flag | Запуск в фоновом режиме |
| --build | Flag | Пересобирает образы перед запуском |

---

### Проверка работы приложения

```bash
curl http://localhost:5000
```

или открыть в браузере: [http://localhost:5000](http://localhost:5000)

| Команда | Категория | Описание |
|---------|-----------|----------|
| curl http://localhost:5000 | CLI | Проверка ответа приложения из терминала |
| http://localhost:5000 | Web | Проверка в браузере |

---

# Основные команды Docker Compose

### Запуск и остановка сервисов
```bash
docker-compose up
```
- `-d`: Запуск в фоновом режиме (detached)  
- `--build`: Принудительная сборка образов перед запуском  
- `--force-recreate`: Пересоздание контейнеров даже если конфигурация не менялась  

```bash
docker-compose down
```
- `-v`: Удаляет volumes, объявленные в секции volumes  
- `--rmi all`: Удаляет все образы, использованные в сервисах  

---

### Управление сборкой и статусом
```bash
docker-compose build
```
- `--no-cache`: Сборка без использования кэша  
- `--pull`: Всегда пытаться скачать новую версию образа  

```bash
docker-compose ps
```
- `-a`: Показывает все контейнеры (включая остановленные)  

---

### Логи
```bash
docker-compose logs
```
- `-f`: Режим следования за логами (follow)  
- `--tail=N`: Показывает N последних строк логов  
- `имя_сервиса`: Логи конкретного сервиса  

---

### Выполнение команд
```bash
docker-compose exec имя_сервиса команда
```
- `-T`: Отключает псевдо-TTY (для скриптов)  
- `команда`: Любая команда (например, `bash`)  

---

### Управление сервисами
```bash
docker-compose restart [имя_сервиса]
docker-compose stop
docker-compose start
docker-compose pause
docker-compose unpause
```

---

### Проверка и диагностика
```bash
docker-compose config
```
- `--services`: Показывает список сервисов  
- `--volumes`: Показывает список volumes  

```bash
docker-compose pull
```
Скачивает образы для сервисов.  

```bash
docker-compose run имя_сервиса команда
```
- `--rm`: Удаляет контейнер после завершения работы  
- `-e`: Устанавливает переменные окружения  
- `--service-ports`: Пробрасывает порты как в оригинальном сервисе  

```bash
docker-compose top
docker-compose images
```

---

# Конфигурационные файлы Docker Compose

### Основные файлы и их пути:
- `./docker-compose.yml` — главный файл конфигурации (определяет сервисы, сети, volumes)  
- `./app/Dockerfile` — инструкции сборки образа приложения  
- `./app/requirements.txt` — список зависимостей Python  
- `./app/app.py` — код приложения  

---

# Руководство по наполнению docker-compose.yml

1. **version** — версия синтаксиса Compose (актуальная `3.8`).  
2. **services** — секция сервисов:  
   - `image` или `build`: либо используем готовый образ, либо собираем из Dockerfile  
   - `ports`: проброс портов `host:container`  
   - `environment`: переменные окружения (например, для базы данных)  
   - `volumes`: тома для хранения данных  
   - `depends_on`: порядок запуска сервисов  
3. **volumes** — список именованных томов (данные сохраняются при перезапуске).  
4. **networks** (опционально) — настройка пользовательских сетей для сервисов.  

---

