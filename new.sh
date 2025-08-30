#!/bin/bash

# Скрипт для добавления новой папки в MkDocs

# Проверка аргумента
if [ -z "$1" ]; then
  echo "Использование: $0 <имя_новой_папки>"
  exit 1
fi

FOLDER_NAME="$1"
DOCS_DIR="docs"
CONFIG_FILE="mkdocs.yml"

# Создание папки
NEW_FOLDER="$DOCS_DIR/$FOLDER_NAME"
mkdir -p "$NEW_FOLDER"

# Создание index.md если не существует
INDEX_FILE="$NEW_FOLDER/index.md"
if [ ! -f "$INDEX_FILE" ]; then
  echo "# $FOLDER_NAME" > "$INDEX_FILE"
  echo "Файл $INDEX_FILE создан."
else
  echo "Файл $INDEX_FILE уже существует."
fi

# Добавление в mkdocs.yml (в конец nav)
if grep -q "nav:" "$CONFIG_FILE"; then
  # Проверка, чтобы не дублировать
  if ! grep -q "$FOLDER_NAME:" "$CONFIG_FILE"; then
    echo "  - $FOLDER_NAME:" >> "$CONFIG_FILE"
    echo "    - Введение: $FOLDER_NAME/index.md" >> "$CONFIG_FILE"
    echo "Папка добавлена в навигацию $CONFIG_FILE."
  else
    echo "Папка уже есть в $CONFIG_FILE."
  fi
else
  echo "Ошибка: не найден раздел nav в $CONFIG_FILE"
fi

echo "Готово! Теперь пересоберите сайт с помощью:"
echo "mkdocs serve"
