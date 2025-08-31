# Полный справочник по Docker

| Команда / Инструкция                              | Категория         | Описание                                                                 |
|---------------------------------------------------|------------------|--------------------------------------------------------------------------|
| `docker ps`                                       | Основные команды | Список запущенных контейнеров                                            |
| `docker ps -a`                                    | Основные команды | Список всех контейнеров (включая остановленные)                          |
| `docker images`                                   | Основные команды | Список локальных образов                                                 |
| `docker pull <image>`                             | Основные команды | Загрузить образ из Docker Hub                                            |
| `docker build -t <name> .`                        | Основные команды | Собрать образ из Dockerfile                                              |
| `docker run <image>`                              | Основные команды | Запуск контейнера                                                        |
| `docker exec -it <id> bash`                       | Основные команды | Выполнить команду внутри контейнера                                      |
| `docker stop <id>`                                | Основные команды | Остановить контейнер                                                     |
| `docker start <id>`                               | Основные команды | Запустить остановленный контейнер                                        |
| `docker rm <id>`                                  | Основные команды | Удалить контейнер                                                        |
| `docker rmi <image>`                              | Основные команды | Удалить образ                                                            |
| `docker logs <id>`                                | Основные команды | Логи контейнера                                                          |
| `docker inspect <id>`                             | Основные команды | Подробная информация о контейнере/образе                                 |
| `docker network ls`                               | Основные команды | Список сетей                                                             |
| `docker volume ls`                                | Основные команды | Список томов                                                             |
| `docker compose up -d`                            | Docker Compose   | Запуск сервисов в фоне                                                   |
| `docker compose down`                             | Docker Compose   | Остановка и удаление контейнеров, сетей, томов                           |
| `docker compose build`                            | Docker Compose   | Сборка сервисов по `docker-compose.yml`                                  |
| `docker compose logs -f`                          | Docker Compose   | Логи сервисов (следить в реальном времени)                               |
| `docker compose ps`                               | Docker Compose   | Список сервисов и их статус                                              |
| `-d`                                              | Флаг run         | Запуск контейнера в фоне (detached)                                      |
| `-it`                                             | Флаг run         | Интерактивный терминал (stdin + tty)                                     |
| `--rm`                                            | Флаг run         | Удалить контейнер после остановки                                        |
| `-p <host:container>`                             | Флаг run         | Проброс порта (пример: `-p 8080:80`)                                     |
| `-v <host:container>`                             | Флаг run         | Монтирование тома                                                        |
| `--name <name>`                                   | Флаг run         | Имя контейнера                                                           |
| `--network <network>`                             | Флаг run         | Подключение к сети                                                        |
| `FROM <image>`                                    | Dockerfile       | Базовый образ                                                            |
| `RUN <command>`                                   | Dockerfile       | Выполнить команду при сборке                                             |
| `COPY <src> <dest>`                               | Dockerfile       | Копировать файлы в образ                                                 |
| `ADD <src> <dest>`                                | Dockerfile       | Как COPY, но поддерживает URL и архивы                                   |
| `WORKDIR <path>`                                  | Dockerfile       | Рабочая директория                                                        |
| `ENV <key> <value>`                               | Dockerfile       | Переменные окружения                                                     |
| `EXPOSE <port>`                                   | Dockerfile       | Документирование порта                                                   |
| `CMD ["executable", "param"]`                     | Dockerfile       | Команда по умолчанию (для `docker run`)                                  |
| `ENTRYPOINT ["executable", "param"]`              | Dockerfile       | Точка входа (жёстко фиксированная команда)                               |
| `VOLUME ["/data"]`                                | Dockerfile       | Объявление тома                                                          |
| `USER <user>`                                     | Dockerfile       | Пользователь, от которого выполняются процессы                           |
| `ARG <name>=<default>`                            | Dockerfile       | Аргументы сборки (доступны только при build)                             |
| `HEALTHCHECK CMD curl -f http://localhost/ || exit 1` | Dockerfile   | Проверка здоровья контейнера                                             |

---

