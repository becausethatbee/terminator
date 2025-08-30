#!/bin/bash

# Скрипт для добавления новой папки как подкаталога в MkDocs
# Использование: ./add_mkdocs_subfolder.sh родительская_папка новая_папка

PARENT="$1"
NEW="$2"

if [ -z "$PARENT" ] || [ -z "$NEW" ]; then
  echo "Использование: $0 <родительская_папка> <новая_папка>"
  exit 1
fi

DOCS_DIR="docs"
CONFIG_FILE="mkdocs.yml"
NEW_FOLDER="$DOCS_DIR/$PARENT/$NEW"

# Создаём подкаталог
mkdir -p "$NEW_FOLDER"

# Создаём index.md если его нет
INDEX_FILE="$NEW_FOLDER/index.md"
if [ ! -f "$INDEX_FILE" ]; then
  echo "# $NEW" > "$INDEX_FILE"
  echo "Файл $INDEX_FILE создан."
else
  echo "Файл $INDEX_FILE уже существует."
fi

# Функция для вставки подкаталога в nav
awk -v parent="$PARENT" -v new="$NEW" '
  BEGIN { inserted=0 }
  /^nav:/ { print; in_nav=1; next }
  in_nav && $0 ~ "- "parent":" && !inserted {
    print $0
    print "    - " new ": " parent "/" new "/index.md"
    inserted=1
    next
  }
  { print }
' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

if [ $inserted -eq 1 ]; then
  echo "Новая папка добавлена в nav секцию $CONFIG_FILE под $PARENT."
else
  echo "Не удалось найти родительскую папку '$PARENT' в nav. Проверьте mkdocs.yml."
fi

echo "Готово! Пересоберите сайт:"
echo "mkdocs serve"
