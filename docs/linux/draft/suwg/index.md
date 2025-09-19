# Конфигурация и развертывание WireGuard VPN с использованием firewalld и Docker

**Цель:** Настроить VPN-сервер WireGuard на машине, где уже работает или планируется Docker, с использованием firewalld в качестве брандмауэра.  

---

## Шаг 1. Установка WireGuard и включение IP Forwarding

```bash
# Для SUSE/openSUSE
sudo zypper install wireguard-tools
```

Включаем пересылку пакетов. Это разрешает ядру Linux работать как маршрутизатор.  

```bash
# Создаем конфигурационный файл для sysctl
sudo tee /etc/sysctl.d/99-wireguard-forward.conf > /dev/null <<EOF
# Enable IP Forwarding for WireGuard
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

# Применяем настройки немедленно
sudo sysctl -p /etc/sysctl.d/99-wireguard-forward.conf
```

---

## Шаг 2. Конфигурация Docker (превентивная мера)

> **Примечание:** Чтобы избежать потенциальных конфликтов IP-адресов между Docker и сетью хостинг-провайдера, рекомендуется задать для Docker нестандартную подсеть.  

```bash
# Создаем директорию и файл конфигурации
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "bip": "172.29.0.1/16"
}
EOF

# Перезапускаем Docker, чтобы он применил новую сеть
sudo systemctl restart docker
```

---

## Шаг 3. Генерация ключей и конфигурация WireGuard

Создаем ключи (приватный и публичный) для сервера:  

```bash
# Устанавливаем безопасные права на директорию
cd /etc/wireguard/
umask 077

# Генерируем приватный ключ и публичный
wg genkey | tee privatekey | wg pubkey > publickey
```

Запомните или скопируйте оба ключа.  

Создаем конфигурационный файл сервера `wg0.conf`:  

```bash
sudo nano /etc/wireguard/wg0.conf
```

Содержимое:  

```ini
# /etc/wireguard/wg0.conf
[Interface]
# IP-адрес сервера внутри VPN-сети
Address = 10.13.13.1/24
# Приватный ключ сервера
PrivateKey = <SERVER_PRIVATE_KEY>
# Порт, который слушает WireGuard
ListenPort = 51820
# НЕ ИСПОЛЬЗУЕМ PostUp/PostDown, так как firewalld справится лучше
# PostUp = ...
# PostDown = ...

# --- Секция для первого клиента ---
[Peer]
# Публичный ключ клиента (сгенерируйте на клиентском устройстве)
PublicKey = <CLIENT_PUBLIC_KEY>
# IP-адрес, который будет выдан клиенту
AllowedIPs = 10.13.13.2/32
```

---

## Шаг 4. Конфигурация Firewalld (ключевой шаг)

Открываем порт для WireGuard:  

```bash
sudo firewall-cmd --permanent --add-port=51820/udp
```

Добавляем правило маскарадинга.  
> **Примечание:** Это самое важное правило. Оно заставляет сервер подменять внутренний IP-адрес клиента (10.13.13.x) на свой публичный IP при выходе в интернет. Мы используем `--direct`, чтобы правило имело высокий приоритет.  

```bash
# ЗАМЕНИТЕ ens3 на имя вашего основного сетевого интерфейса (если оно другое)
sudo firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.13.13.0/24 -o ens3 -j MASQUERADE
```

(Опционально, но рекомендуется) Добавляем TCP MSS Clamping.  
> **Примечание:** Это решает проблемы с доступом к сайтам через сети с низким MTU (например, мобильные).  

```bash
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter FORWARD 0 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

Применяем все правила:  

```bash
sudo firewall-cmd --reload
```

---

## Шаг 5. Запуск и проверка

Включаем автозапуск и стартуем сервис WireGuard:  

```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

Проверяем статус:  

```bash
# Убеждаемся, что сервис активен
sudo systemctl status wg-quick@wg0

# Смотрим на интерфейс и пиров
sudo wg show
```

---

## Шаг 6. Конфигурация клиента

На клиентском устройстве (телефоне, ноутбуке) создайте конфигурацию.  
> **Примечание:** `<CLIENT_PRIVATE_KEY>` вы генерируете на клиенте, а `<SERVER_PUBLIC_KEY>` берете из файла `publickey` на сервере.  

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.13.13.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <SERVER_PUBLIC_IP>:51820
AllowedIPs = 0.0.0.0/0, ::/0
```
