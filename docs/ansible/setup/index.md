# Установка Ansible на Debian 12

## Шаг 1. Обновление индекса пакетов

```bash
sudo apt update
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| sudo apt update | Debian | Обновляет индекс пакетов и репозитории |

---

## Шаг 2. Установка Ansible из репозиториев Debian

```bash
sudo apt install -y ansible
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| sudo apt install -y ansible | Debian | Устанавливает пакет Ansible из стандартных репозиториев |
| -y | Flag | Автоматически подтверждает установку |

---

## Шаг 3. Проверка версии Ansible

```bash
ansible --version
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| ansible --version | Ansible | Показывает текущую установленную версию Ansible |

---

## Шаг 4. Создание файла инвентаря для localhost

```bash
echo "localhost ansible_connection=local" > ~/inventory.ini
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| echo "localhost ansible_connection=local" > ~/inventory.ini | Ansible | Создает файл инвентаря `inventory.ini` для управления локальным хостом |
| ansible_connection=local | Параметр | Указывает, что подключение к localhost осуществляется локально |

---

## Шаг 5. Проверка доступности хоста

```bash
ansible all -i ~/inventory.ini -m ping
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| ansible all -i ~/inventory.ini -m ping | Ansible | Выполняет проверку доступности всех хостов из инвентаря через модуль ping |
| -i ~/inventory.ini | Параметр | Указывает путь к файлу инвентаря |
| -m ping | Модуль | Использует встроенный модуль ping для проверки связи |

---

## Установка актуальной версии Ansible через PPA

 официальный PPA:

```bash
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

| Команда / Инструкция | Категория | Описание |
|----------------------|-----------|----------|
| software-properties-common | Debian | Устанавливает пакет для управления PPA |
| add-apt-repository ppa:ansible/ansible | Debian | Добавляет официальный PPA Ansible |
| sudo apt install -y ansible | Debian | Устанавливает Ansible из PPA, обеспечивая актуальную версию |
