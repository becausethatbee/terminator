# Оптимизация и настройка образа

### Создание файла приложения

```bash
cat > app.py <<EOF
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return "Hello, Flask in Docker!"

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000)
EOF
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| `cat > app.py <<EOF` | Создание файлов | Создание файла app.py с использованием heredoc-синтаксиса |
| `>` | Перенаправление | Перенаправление вывода в файл app.py |
| `<<EOF` | Heredoc | Начало многострочного ввода до маркера EOF |

### Создание Dockerfile

```dockerfile
FROM python:3.9-alpine
WORKDIR /app
COPY app.py .
RUN pip install --no-cache-dir flask
EXPOSE 5000
CMD ["python", "app.py"]
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| `FROM python:3.9-alpine` | Dockerfile | Определение базового образа (alpine-версия для минимального размера) |
| `WORKDIR /app` | Dockerfile | Установка рабочего каталога внутри контейнера |
| `COPY app.py .` | Dockerfile | Копирование файла приложения в образ |
| `RUN pip install --no-cache-dir flask` | Dockerfile | Установка Flask без кеша pip для уменьшения размера образа |
| `EXPOSE 5000` | Dockerfile | Декларация используемого порта |
| `CMD ["python", "app.py"]` | Dockerfile | Команда запуска приложения при старте контейнера |

### Сборка и запуск контейнера

```bash
docker build -t flask-app .
docker run -d -p 5000:5000 flask-app
curl http://localhost:5000
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| `docker build -t flask-app .` | Docker | Сборка Docker-образа с тегом flask-app из текущей директории |
| `docker run -d -p 5000:5000 flask-app` | Docker | Запуск контейнера в фоновом режиме с пробросом порта 5000 |
| `curl http://localhost:5000` | Тестирование | Выполнение HTTP-запроса к приложению для проверки работоспособности |

### Ожидаемый результат
```
Hello, Flask in Docker!
```
