# Настройка Trojan-Go прокси сервера

Полное руководство по развертыванию Trojan-Go прокси с валидным SSL сертификатом, автообновлением и защитой.

## О Trojan и Trojan-Go

**Trojan** - это прокси-протокол, разработанный для обхода блокировок через имитацию обычного HTTPS трафика. В отличие от VPN или других прокси, Trojan не добавляет дополнительных слоёв шифрования поверх TLS, а использует сам TLS как транспорт.

**Преимущества перед другими протоколами:**

- **Незаметность:** Для внешнего наблюдателя (включая DPI системы) трафик выглядит как обычное HTTPS соединение к веб-серверу
- **Производительность:** Нет лишних слоёв шифрования - используется только TLS, что даёт хорошую скорость
- **Простота:** Минималистичный протокол без сложной конфигурации
- **Надёжность:** Использует стандартные TLS библиотеки, валидные сертификаты работают везде

**Trojan-Go vs оригинальный Trojan:**

- Написан на Go (оригинал на C++) - проще установка, один бинарник
- Поддержка WebSocket для дополнительной маскировки
- Мультиплексирование для ускорения
- Меньше потребление памяти

**Когда использовать Trojan:**
- Нужна стабильность и скорость
- Важна незаметность для DPI
- Есть доступ к домену и валидному SSL

## Содержание

1. [Требования](#требования)
2. [Регистрация домена](#регистрация-домена)
3. [Настройка DNS](#настройка-dns)
4. [Настройка Firewall](#настройка-firewall)
5. [Получение SSL сертификата](#получение-ssl-сертификата)
6. [Установка Trojan-Go](#установка-trojan-go)
7. [Настройка клиентов](#настройка-клиентов)
8. [Автообновление сертификата](#автообновление-сертификата)
9. [Возможные улучшения](#возможные-улучшения)

---

## Требования

- VPS с публичным IP (Ubuntu/Debian/SUSE)
- Root доступ к серверу
- Домен (.online, .xyz, .com и т.д.)
- Docker и Docker Compose

## Настройка Firewall

Откройте порты 80 (для получения SSL сертификата) и 443 (для Trojan).

### Firewalld (RHEL/CentOS/SUSE)

```bash
# Добавьте порты
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload

# Проверка
sudo firewall-cmd --list-ports
```

### UFW (Ubuntu/Debian)

```bash
# Разрешите порты
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Включите firewall если выключен
sudo ufw enable

# Проверка
sudo ufw status
```

### iptables (универсальный)

```bash
# Добавьте правила
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Сохраните правила
sudo iptables-save > /etc/iptables/rules.v4  # Debian/Ubuntu
# или
sudo service iptables save  # RHEL/CentOS

# Проверка
sudo iptables -L -n | grep -E "80|443"
```

### Проверка доступности портов

```bash
# Проверьте что порты слушаются
sudo ss -tulpn | grep -E ":80|:443"

# Проверьте извне (замените на ваш IP)
telnet ваш_ip 443
```

## Регистрация домена

Зарегистрируйте домен у одного из регистраторов:

- **Namecheap** - международный
- **Porkbun** - дешевые цены
- **Timeweb** - российский (~180₽/год за .online)

### Рекомендуемые доменные зоны

- `.online` - выглядит как веб-сервис
- `.xyz` - дешево и нейтрально
- `.site` - подходит для API

### Примеры названий

- `api-core.online`
- `netcore.online`
- `node7.online`
- `cdn-cache.online`

## Настройка DNS

В панели управления доменом добавьте A-запись:

```
Тип: A
Имя: @ (или пусто)
Значение: ВАШ_IP_СЕРВЕРА
TTL: 3600
```

Проверьте DNS (подождите 5-30 минут):

```bash
ping ваш-домен.online
# Должен отвечать ваш IP
```

## Получение SSL сертификата

### Установка acme.sh

```bash
curl https://get.acme.sh | sh -s email=your@email.com
source ~/.bashrc
```

### Установка socat

```bash
sudo zypper install socat  # SUSE
# или
sudo apt install socat     # Ubuntu/Debian
```

### Получение сертификата через webroot

Если у вас работает nginx на порту 80:

```bash
# Создайте папку для валидации
mkdir -p ~/your-web-folder/.well-known/acme-challenge

# Используйте Let's Encrypt
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# Получите сертификат (nginx продолжает работать)
~/.acme.sh/acme.sh --issue -d ваш-домен.online \
  -w ~/your-web-folder \
  --force
```

### Альтернатива: standalone режим

Если порт 80 свободен:

```bash
# Остановите nginx если работает
docker stop nginx_container

# Получите сертификат
~/.acme.sh/acme.sh --issue --standalone -d ваш-домен.online --force

# Запустите nginx обратно
docker start nginx_container
```

### Установка сертификатов

```bash
# Создайте папку для trojan
mkdir -p ~/go-proxy

# Установите сертификаты
~/.acme.sh/acme.sh --install-cert -d ваш-домен.online \
  --cert-file ~/go-proxy/cert.pem \
  --key-file ~/go-proxy/key.pem \
  --fullchain-file ~/go-proxy/fullchain.pem
```

## Установка Trojan-Go

Trojan-Go можно установить двумя способами: через Docker (проще) или нативно (больше контроля).

### Вариант 1: Установка через Docker

**Преимущества:** Изолированное окружение, простое обновление, не засоряет систему.

#### Создайте docker-compose.yml

```bash
cd ~/go-proxy
nano docker-compose.yml
```

**docker-compose.yml:**

```yaml
version: "3.9"

services:
  trojan-go:
    image: p4gefau1t/trojan-go:latest
    container_name: trojan-go
    restart: unless-stopped
    ports:
      - "443:443"
    volumes:
      - ./:/etc/trojan-go
```

#### Создайте config.json

**Генерация надежного пароля:**

```bash
openssl rand -base64 24
```

**config.json:**

```json
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "172.17.0.1",
  "remote_port": 80,
  "password": ["ВАШ_СГЕНЕРИРОВАННЫЙ_ПАРОЛЬ"],
  "ssl": {
    "cert": "/etc/trojan-go/fullchain.pem",
    "key": "/etc/trojan-go/key.pem",
    "sni": "ваш-домен.online"
  }
}
```

**Пояснение к config:**
- `remote_addr` и `remote_port` - куда перенаправлять при неправильном подключении (fallback на nginx)
- `password` - массив, можно добавить несколько паролей для разных пользователей
- `sni` - должен совпадать с доменом в сертификате

#### Запуск

```bash
docker-compose up -d

# Проверка логов
docker logs -f trojan-go
```

### Вариант 2: Нативная установка (без Docker)

**Преимущества:** Меньше overhead, прямой контроль, работает на системах без Docker.

#### Скачайте Trojan-Go

```bash
# Создайте директорию
mkdir -p ~/trojan-go
cd ~/trojan-go

# Скачайте последнюю версию
wget https://github.com/p4gefau1t/trojan-go/releases/download/v0.10.6/trojan-go-linux-amd64.zip

# Распакуйте
unzip trojan-go-linux-amd64.zip
chmod +x trojan-go
```

#### Создайте конфигурацию

```bash
nano config.json
```

**config.json для нативной установки:**

```json
{
  "run_type": "server",
  "local_addr": "0.0.0.0",
  "local_port": 443,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password": ["ВАШ_ПАРОЛЬ"],
  "log": {
    "level": 1,
    "access": "/var/log/trojan-go/access.log",
    "error": "/var/log/trojan-go/error.log"
  },
  "ssl": {
    "cert": "/home/admin/go-proxy/fullchain.pem",
    "key": "/home/admin/go-proxy/key.pem",
    "sni": "ваш-домен.online"
  }
}
```

**Важно:** Используйте полные пути к сертификатам при нативной установке.

#### Создайте systemd сервис

```bash
sudo nano /etc/systemd/system/trojan-go.service
```

**trojan-go.service:**

```ini
[Unit]
Description=Trojan-Go Proxy Server
After=network.target

[Service]
Type=simple
User=admin
WorkingDirectory=/home/admin/trojan-go
ExecStart=/home/admin/trojan-go/trojan-go -config /home/admin/trojan-go/config.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

#### Создайте директорию для логов

```bash
sudo mkdir -p /var/log/trojan-go
sudo chown admin:admin /var/log/trojan-go
```

#### Запустите сервис

```bash
# Перезагрузите systemd
sudo systemctl daemon-reload

# Запустите trojan-go
sudo systemctl start trojan-go

# Добавьте в автозагрузку
sudo systemctl enable trojan-go

# Проверьте статус
sudo systemctl status trojan-go

# Логи
sudo journalctl -u trojan-go -f
```

Успешный запуск выглядит так:
```
[INFO] trojan-go v0.10.6 initializing
[WARN] empty tls fallback port
[WARN] empty tls http response
```

## Настройка клиентов

### Windows: v2rayN

1. Скачайте [v2rayN](https://github.com/2dust/v2rayN/releases)
2. Добавьте сервер Trojan:
   - **Адрес:** ваш-ip или домен
   - **Порт:** 443
   - **Пароль:** из config.json
   - **SNI:** ваш-домен.online
   - **Allow Insecure:** ВЫКЛЮЧЕНО (валидный SSL)

3. Запустите подключение
4. Локальный прокси появится на `127.0.0.1:10808`

### Windows: NekoBox

1. Скачайте [NekoBox](https://github.com/MatsuriDayo/nekoray/releases)
2. Добавьте профиль Trojan
3. **ВАЖНО:** Отключите Multiplexing (мультиплексирование)
   - Trojan-Go его не поддерживает
4. Настройки аналогично v2rayN

### Android: v2rayNG

1. Установите из [Play Store](https://play.google.com/store/apps/details?id=com.v2ray.ang)
2. Добавьте сервер Trojan
3. Параметры те же

### Настройка браузера

#### Firefox (встроенная настройка):

1. `about:preferences` → Основные → Параметры сети
2. Ручная настройка прокси:
   - **SOCKS хост:** `127.0.0.1`
   - **Порт:** `10808` (или другой из клиента)
   - **SOCKS v5** ✓
   - **Использовать прокси для DNS** ✓

#### Chrome/Brave через SwitchyOmega:

1. Установите [SwitchyOmega](https://chrome.google.com/webstore/detail/proxy-switchyomega/padekgcemlokbadohgkifijomclgjgif)
2. Создайте профиль:
   - **Protocol:** SOCKS5
   - **Server:** `127.0.0.1`
   - **Port:** `10808`
3. Переключайтесь одним кликом

### Проверка работы

Откройте https://whoer.net
- Должен показать IP вашего сервера
- DNS leak test должен быть чистым

## Автообновление сертификата

Let's Encrypt сертификаты действуют 90 дней. Настроим автоматическое обновление.

### Для Docker установки

```bash
~/.acme.sh/acme.sh --install-cert -d ваш-домен.online \
  --cert-file ~/go-proxy/cert.pem \
  --key-file ~/go-proxy/key.pem \
  --fullchain-file ~/go-proxy/fullchain.pem \
  --reloadcmd "cd /home/admin/go-proxy && /usr/bin/docker compose restart"
```

**Что делает эта команда:**
- Сохраняет пути к файлам сертификатов
- Добавляет команду перезапуска после обновления
- При обновлении (через ~60 дней) Docker контейнер автоматически перезапустится

### Для нативной установки

```bash
~/.acme.sh/acme.sh --install-cert -d ваш-домен.online \
  --cert-file /home/admin/trojan-go/fullchain.pem \
  --key-file /home/admin/trojan-go/key.pem \
  --fullchain-file /home/admin/trojan-go/fullchain.pem \
  --reloadcmd "sudo systemctl restart trojan-go"
```

### Проверка автообновления

```bash
# Проверьте cron задачу
crontab -l | grep acme

# Должна быть строка типа:
# 21 13 * * * "/home/admin/.acme.sh"/acme.sh --cron --home "/home/admin/.acme.sh" > /dev/null
```

**Как это работает:**
1. Cron запускается ежедневно в 13:21
2. acme.sh проверяет срок действия сертификата
3. За 30 дней до истечения получает новый сертификат
4. Копирует в указанные пути
5. Выполняет команду перезапуска (reloadcmd)

### Ручное обновление сертификата

```bash
# Если нужно обновить вручную
~/.acme.sh/acme.sh --renew -d ваш-домен.online --force

# Проверка срока действия
openssl x509 -in ~/go-proxy/fullchain.pem -noout -dates
```

## Возможные улучшения

### WebSocket транспорт (обход продвинутого DPI)

WebSocket делает трафик неотличимым от обычного веб-приложения (чаты, стриминг).

Добавьте в config.json:

```json
{
  "websocket": {
    "enabled": true,
    "path": "/api/v1/data",
    "host": "ваш-домен.online"
  }
}
```

**Преимущества:**
- Внутри TLS идут настоящие HTTP заголовки и WebSocket фреймы
- DPI видит обычное веб-приложение, а не VPN
- Работает через CDN (Cloudflare)
- Обходит блокировки по TLS fingerprint

**В клиенте** включите WebSocket:
- Transport: `ws`
- Path: `/api/v1/data`
- Host: `ваш-домен.online`

### CDN проксирование через Cloudflare

Скрывает ваш реальный IP от блокировщиков.

**Настройка:**
1. Зарегистрируйтесь на [cloudflare.com](https://cloudflare.com)
2. Добавьте домен
3. Измените DNS на серверы Cloudflare (в Timeweb/Namecheap)
4. Включите проксирование (оранжевое облако ☁️)
5. Используйте WebSocket транспорт (обязательно!)

**Что это даёт:**
- DPI видит соединение к Cloudflare, а не к вашему серверу
- Cloudflare - легитимный CDN, его не блокируют
- Ваш IP остаётся скрытым
- Дополнительная защита от DDoS

**Ограничения:**
- WebSocket обязателен (Cloudflare не проксирует чистый TLS)
- Небольшое увеличение latency

### Мультиплексирование (ускорение)

Упаковывает несколько соединений в один канал - ускоряет работу.

Добавьте в config.json:

```json
{
  "mux": {
    "enabled": true,
    "concurrency": 8
  }
}
```

**Когда полезно:**
- Открываете много вкладок одновременно
- Высокий latency до сервера
- Много мелких запросов

**Внимание:** Не все клиенты поддерживают. Убедитесь что клиент понимает trojan-go mux, а не sing-box mux.

### Camouflage - маскировка под реальный сайт

Разверните обычный сайт на порту 80 (fallback в config.json).

**Что это даёт:**
- При неправильном подключении показывается реальный сайт
- DPI сканер увидит блог/портфолио/документацию
- Выглядит как легитимный веб-сервер с дополнительным HTTPS

**Варианты:**
- Статический сайт на nginx
- Простой блог на Jekyll/Hugo
- Копия популярного сайта (документация проекта)

### Дополнительные протоколы на том же сервере

**Shadowsocks** - легковесная альтернатива:
```bash
docker run -d -p 8388:8388 shadowsocks/shadowsocks-libev \
  ss-server -s 0.0.0.0 -p 8388 -k пароль -m chacha20-ietf-poly1305
```

**V2Ray/Xray** - продвинутая маскировка:
- Поддерживает больше транспортов (gRPC, HTTP/2)
- uTLS - эмуляция TLS handshake браузера
- Лучше для Китая/Ирана

**WireGuard** - как fallback:
- Простой UDP VPN
- Если Trojan заблокируют - переключиться на WireGuard
- Работает на уровне ядра - очень быстрый

### Несколько пользователей

В `password` можно добавить несколько паролей:

```json
{
  "password": [
    "пароль_пользователь1",
    "пароль_пользователь2",
    "пароль_гость"
  ]
}
```

Каждый пароль работает независимо. Можно отозвать доступ удалив пароль из списка.

### GeoIP ограничения (опционально)

Разрешить подключения только из определённых стран.

**Установите GeoIP базу:**
```bash
wget https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb
mv GeoLite2-Country.mmdb ~/trojan-go/
```

**Добавьте в config.json:**
```json
{
  "router": {
    "enabled": true,
    "geoip": "GeoLite2-Country.mmdb",
    "bypass": ["geoip:ru", "geoip:ua"],
    "block": ["geoip:cn"]
  }
}
```

Это заблокирует подключения из Китая, разрешив только из России/Украины.

### Резервный сервер

Настройте идентичный Trojan на втором VPS в другой стране.

**Два подхода:**

1. **Разные домены** - переключаетесь вручную в клиенте
2. **DNS round-robin** - один домен → несколько IP, автоматическое переключение

Если один сервер заблокируют, второй продолжит работать.

---

## Troubleshooting

### Ошибка "Connection refused"

Проверьте:
```bash
docker ps | grep trojan
docker logs trojan-go
sudo ss -tulpn | grep :443
```

### Ошибка "SNI mismatched"

- SNI в клиенте должен совпадать с config.json
- Проверьте домен в настройках

### "sp.mux.sing-box.arpa" в логах

- Отключите мультиплексирование в клиенте
- Trojan-Go не поддерживает sing-box mux

### Сертификат не обновляется

```bash
# Проверьте cron
crontab -l | grep acme

# Ручное обновление
~/.acme.sh/acme.sh --renew -d ваш-домен.online --force
```

---

## Полезные команды

```bash
# Перезапуск trojan
cd ~/go-proxy && docker-compose restart

# Просмотр логов
docker logs -f trojan-go

# Проверка сертификата
openssl x509 -in ~/go-proxy/fullchain.pem -noout -dates

# Статус fail2ban
sudo fail2ban-client status sshd

# Проверка портов
sudo ss -tulpn | grep -E "80|443"

# Генерация нового пароля
openssl rand -base64 24
```
