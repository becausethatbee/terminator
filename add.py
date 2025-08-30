#!/usr/bin/env python3
import os
import yaml

# Папка с документацией
docs_dir = "docs/Docker"

# Список секций в правильном порядке: {системное имя: отображаемое имя}
sections = [
    ("overview", "Обзор"),
    ("commands", "Команды"),
    ("setup", "Установка"),
    ("container", "Создание и запуск контейнера"),
    ("image_optimization", "Оптимизация и настройка образа"),
    ("filesystem", "Файловая система"),
    ("networking", "Сети"),
    ("security", "Безопасность"),
    ("compose", "Docker Compose"),
]

# Создаём папки и index.md
for folder, title in sections:
    path = os.path.join(docs_dir, folder)
    os.makedirs(path, exist_ok=True)
    index_file = os.path.join(path, "index.md")
    if not os.path.exists(index_file):
        with open(index_file, "w", encoding="utf-8") as f:
            f.write(f"# {title}\n\n")

# Обновляем mkdocs.yml
with open("mkdocs.yml", "r", encoding="utf-8") as f:
    config = yaml.safe_load(f)

# Ищем раздел "Docker" в nav
for item in config["nav"]:
    if "Docker" in item:
        docker_section = item["Docker"]
        break
else:
    docker_section = []
    config["nav"].append({"Docker": docker_section})

# Перезаписываем секцию Docker в правильном порядке
docker_section.clear()
for folder, title in sections:
    docker_section.append({title: f"Docker/{folder}/index.md"})

# Сохраняем
with open("mkdocs.yml", "w", encoding="utf-8") as f:
    yaml.dump(config, f, allow_unicode=True, sort_keys=False)

print("✅ Папки и навигация успешно обновлены!")
