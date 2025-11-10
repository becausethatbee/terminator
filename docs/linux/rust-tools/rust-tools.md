# Топовые CLI утилиты на Rust

## Файловая система

**fd** - find альтернатива
```bash
fd pattern          # найти файлы
fd -e js            # только .js файлы
fd -H config        # включая скрытые
```

**eza** (ex-exa) - ls с иконками
```bash
eza -la             # красивый список
eza --tree          # дерево файлов
eza --git           # с git статусом
```

**dust** - du альтернатива (размер папок)
```bash
dust                # размер текущей папки
dust -d 2           # глубина 2 уровня
```

**broot** - навигация по папкам
```bash
br                  # интерактивный браузер файлов
```

## Поиск и текст

**ripgrep (rg)** - grep на стероидах
```bash
rg "TODO"                    # поиск TODO
rg "import.*React" --type js # в JS файлах
rg -i password               # case-insensitive
rg --files-with-matches bug  # только имена файлов
```

**bat** - cat с подсветкой
```bash
bat file.rs         # покажет с подсветкой
bat -A file.txt     # покажет скрытые символы
bat file.json       # JSON с подсветкой
```

**sd** - sed альтернатива
```bash
sd 'from' 'to' file.txt      # замена
sd '\d+' 'X' file.txt        # regex замена
```

## Git

**gitui** - TUI для git
```bash
gitui               # запустить интерфейс
```

**delta** - красивый git diff
```bash
git diff | delta    # или настроить в .gitconfig
```

**tokei** - считает строки кода
```bash
tokei               # статистика по языкам
tokei --sort lines  # отсортировать
```

## Системный мониторинг

**bottom (btm)** - htop альтернатива
```bash
btm                 # мониторинг системы
btm --basic         # упрощенный режим
```

**procs** - ps альтернатива
```bash
procs               # список процессов
procs nginx         # фильтр по имени
```

**bandwhich** - сетевой мониторинг (нужен sudo)
```bash
sudo bandwhich      # кто жрёт трафик
```

## Терминал

**starship** - кастомный prompt
```bash
# В .bashrc или .zshrc:
eval "$(starship init bash)"
```

**zellij** - tmux альтернатива
```bash
zellij              # запуск сессии
zellij attach       # подключиться
```

**alacritty** - GPU терминал
```bash
alacritty           # запустить терминал
```

## Бенчмарки и утилиты

**hyperfine** - бенчмарк команд
```bash
hyperfine 'sleep 0.1' 'sleep 0.2'
hyperfine --warmup 3 'rg pattern' 'grep pattern'
```

**just** - make альтернатива
```bash
just --list         # показать команды
just build          # запустить задачу
```

**zoxide** - cd с автодополнением
```bash
z docs              # прыгнуть в ~/Documents
zi                  # интерактивный выбор
```

## HTTP/Сеть

**xh** - httpie альтернатива
```bash
xh GET https://api.github.com
xh POST httpbin.org/post name=John
```

**dog** - dig альтернатива
```bash
dog google.com      # DNS lookup
dog google.com MX   # MX записи
```

## Установка

**Windows:**
```bash
# Через Scoop
scoop install ripgrep fd bat eza

# Через Cargo (нужен Rust)
cargo install ripgrep fd-find bat eza
```

**Linux:**
```bash
# Через Cargo
cargo install ripgrep fd-find bat eza bottom tokei

# Или через пакетный менеджер
apt install ripgrep fd-find bat  # Debian/Ubuntu
```

## Самые полезные для старта:

1. **ripgrep** - будешь юзать каждый день
2. **fd** - ищет файлы мгновенно
3. **bat** - замена cat
4. **eza** - красивый ls
5. **starship** - крутой prompt

Попробуй сначала эти 5, потом остальное по необходимости.
