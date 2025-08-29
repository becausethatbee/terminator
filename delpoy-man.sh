#!/bin/bash
# manual-deploy.sh

# Сборка сайта
mkdocs build

# Переключение на ветку gh-pages
git checkout --orphan gh-pages
git add site/
git commit -m "Deploy to GitHub Pages"

# Принудительная отправка в ветку gh-pages
git push origin gh-pages --force

# Возврат к основной ветке
git checkout main
