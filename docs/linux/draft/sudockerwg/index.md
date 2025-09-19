# 📋 Полное руководство по развертыванию WireGuard VPN на openSUSE  
🎯 **Результат:** Рабочий WireGuard VPN с веб-интерфейсом wg-easy  

---

## 📁 Структура проекта

```bash
mkdir -p /home/admin/wireguard-opensuse/{scripts,configs,docs}
cd /home/admin/wireguard-opensuse
```

---

## 🚀 Шаг 1: Подготовка системы  

### 1.1 Установка зависимостей

```bash
cat > scripts/01-install-dependencies.sh << 'EOF'
#!/bin/bash
echo "=== Installing Dependencies ==="

# Обновление системы
sudo zypper refresh
sudo zypper update -y

# Установка Docker
sudo zypper install -y docker docker-compose

# Установка дополнительных утилит
sudo zypper install -y curl wget git

# Запуск и автозагрузка Docker
sudo systemctl enable docker
sudo systemctl start docker

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER

echo "✅ Dependencies installed"
echo "⚠️ Please logout and login again for docker group to take effect"
EOF
```

---

### 1.2 Настройка firewall и сети  

```bash
cat > scripts/02-setup-firewall.sh << 'EOF'
#!/bin/bash
echo "=== Setting up Firewall ==="

# Отключение nftables для совместимости с Docker
sudo systemctl stop nftables 2>/dev/null || true
sudo systemctl disable nftables 2>/dev/null || true

# Переключение на iptables-legacy
sudo update-alternatives --install /usr/sbin/iptables iptables /usr/sbin/iptables-legacy 10 2>/dev/null || true

# Очистка существующих правил
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
sudo iptables -t nat -X

# Базовые правила
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# Разрешение loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Разрешение установленных соединений
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH доступ
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# WireGuard порты
sudo iptables -A INPUT -p tcp --dport 51821 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# Включение IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf

# Перезапуск Docker для применения изменений
sudo systemctl restart docker

echo "✅ Firewall configured"
EOF
```

---

## 🛠 Шаг 2: Развертывание WireGuard  

### 2.1 Создание Docker Compose файла  

```bash
cat > configs/docker-compose.yml << 'EOF'
version: '3.8'

services:
  wg-easy:
    environment:
      # ВАЖНО: Замените на ваш IP
      - WG_HOST=YOUR_SERVER_IP
      # ВАЖНО: Замените на ваш пароль hash
      - PASSWORD_HASH=YOUR_PASSWORD_HASH
      
      # Основные настройки
      - PORT=51821
      - WG_PORT=51820
      - WG_DEFAULT_ADDRESS=10.8.0.x
      - WG_DEFAULT_DNS=1.1.1.1,8.8.8.8
      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
      - WG_PERSISTENT_KEEPALIVE=25
      - WG_MTU=1420
      
      # UI настройки
      - UI_TRAFFIC_STATS=true
      - UI_CHART_TYPE=2
      
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    volumes:
      - wg-data:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1

volumes:
  wg-data:
EOF
```

---

### 2.2 Скрипт настройки WireGuard  

```bash
cat > scripts/03-setup-wireguard.sh << 'EOF'
#!/bin/bash
echo "=== Setting up WireGuard ==="

# Получение IP сервера
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
echo "Detected server IP: $SERVER_IP"

# Запрос пароля
echo "Enter password for WireGuard web interface:"
read -s PASSWORD

# Генерация hash пароля
PASSWORD_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy:latest /bin/sh -c "node -e \"console.log(require('bcryptjs').hashSync('$PASSWORD', 12))\"")

# Создание конфигурации
sed -i "s/YOUR_SERVER_IP/$SERVER_IP/g" configs/docker-compose.yml
sed -i "s|YOUR_PASSWORD_HASH|$PASSWORD_HASH|g" configs/docker-compose.yml

# Запуск контейнера
echo "Starting WireGuard..."
docker compose -f configs/docker-compose.yml up -d

# Ожидание запуска
echo "Waiting for container to start..."
sleep 30

# Настройка NAT
echo "Setting up NAT..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE
sudo iptables -A FORWARD -i wg0 -j ACCEPT
sudo iptables -A FORWARD -o wg0 -j ACCEPT

echo "✅ WireGuard setup complete!"
echo "Web interface: http://$SERVER_IP:51821"
echo "Password: $PASSWORD"
EOF
```

---

## 🔧 Шаг 3: Вспомогательные скрипты  

### 3.1 Проверка статуса  

```bash
cat > scripts/04-check-status.sh << 'EOF'
#!/bin/bash
echo "=== WireGuard Status Check ==="

echo "Container status:"
docker ps | grep wg-easy

echo -e "\nWireGuard interface:"
docker exec wg-easy wg show 2>/dev/null || echo "WireGuard not ready"

echo -e "\nListening ports:"
sudo ss -tlnp | grep ":51821" && echo "✅ Web UI port open"
sudo ss -ulnp | grep ":51820" && echo "✅ VPN port open"

echo -e "\nFirewall rules:"
sudo iptables -t nat -L POSTROUTING -n | grep "10.8.0.0/24" && echo "✅ NAT configured"

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null)
echo -e "\nAccess URLs:"
echo "Web interface: http://$SERVER_IP:51821"

echo -e "\nContainer logs (last 5 lines):"
docker logs wg-easy 2>&1 | tail -5
EOF
```

---

### 3.2 Управление службой  

```bash
cat > scripts/05-manage-service.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "Starting WireGuard..."
        docker compose -f configs/docker-compose.yml up -d
        ;;
    stop)
        echo "Stopping WireGuard..."
        docker compose -f configs/docker-compose.yml down
        ;;
    restart)
        echo "Restarting WireGuard..."
        docker compose -f configs/docker-compose.yml restart
        ;;
    logs)
        docker logs wg-easy -f
        ;;
    backup)
        echo "Creating backup..."
        docker run --rm -v wg-data:/data -v $(pwd)/backup:/backup alpine tar czf /backup/wireguard-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .
        echo "Backup created in ./backup/"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|backup}"
        exit 1
        ;;
esac
EOF
```

---

### 3.3 Диагностика проблем  

```bash
cat > scripts/06-troubleshoot.sh << 'EOF'
#!/bin/bash
echo "=== WireGuard Troubleshooting ==="

echo "1. System info:"
cat /etc/os-release | grep PRETTY_NAME

echo -e "\n2. Docker status:"
sudo systemctl status docker --no-pager -l

echo -e "\n3. Container status:"
docker ps -a | grep wg-easy

echo -e "\n4. Port check:"
sudo ss -tlnp | grep ":51821"
sudo ss -ulnp | grep ":51820"

echo -e "\n5. Firewall rules:"
sudo iptables -L INPUT -n | grep -E "(51820|51821)"
sudo iptables -t nat -L -n | grep "10.8.0"

echo -e "\n6. Network interfaces:"
ip addr show | grep -E "(docker|wg)"

echo -e "\n7. IP forwarding:"
cat /proc/sys/net/ipv4/ip_forward

echo -e "\n8. Container logs:"
docker logs wg-easy 2>&1 | tail -10

echo -e "\n9. External connectivity test:"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null)
curl -I http://localhost:51821 2>/dev/null | head -1
curl -I http://$SERVER_IP:51821 --connect-timeout 5 2>/dev/null | head -1 || echo "External access failed"
EOF
```

---

## 📖 Шаг 4: Документация  

### 4.1 README  

```bash
cat > docs/README.md << 'EOF'
# WireGuard VPN на openSUSE

Автоматическая установка WireGuard VPN с веб-интерфейсом wg-easy на openSUSE.

## Быстрый старт

```bash
# 1. Установка зависимостей
chmod +x scripts/*.sh
./scripts/01-install-dependencies.sh

# 2. Перелогиньтесь для применения группы docker
logout

# 3. Настройка firewall
./scripts/02-setup-firewall.sh

# 4. Установка WireGuard
./scripts/03-setup-wireguard.sh

# 5. Проверка
./scripts/04-check-status.sh
```

... (остальная документация аналогично твоему тексту)  
EOF
```

---

### 4.2 Установочный скрипт  

```bash
cat > install.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 WireGuard VPN installer for openSUSE"
echo "========================================"

# Проверка ОС
if ! grep -q "openSUSE" /etc/os-release; then
    echo "❌ This script is designed for openSUSE"
    exit 1
fi

# Проверка прав root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root"
   exit 1
fi

echo "📦 Step 1/4: Installing dependencies..."
./scripts/01-install-dependencies.sh

echo ""
echo "⚠️  Please logout and login again, then run:"
echo "   ./continue-install.sh"
EOF
```

```bash
cat > continue-install.sh << 'EOF'
#!/bin/bash
set -e

echo "🔧 Step 2/4: Setting up firewall..."
./scripts/02-setup-firewall.sh

echo ""
echo "🛠  Step 3/4: Installing WireGuard..."
./scripts/03-setup-wireguard.sh

echo ""
echo "✅ Step 4/4: Checking installation..."
./scripts/04-check-status.sh

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Access your VPN:"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null)
echo "  Web interface: http://$SERVER_IP:51821"
echo ""
echo "Management commands:"
echo "  ./scripts/05-manage-service.sh {start|stop|restart|logs|backup}"
echo "  ./scripts/06-troubleshoot.sh"
EOF
```

---

## 🚀 Финальная настройка  

```bash
# Делаем все скрипты исполняемыми
chmod +x scripts/*.sh install.sh continue-install.sh

# Создание директории для бэкапов
mkdir -p backup
```

---

## 📤 Подготовка к Git  

```bash
cat > .gitignore << 'EOF'
# Secrets
configs/docker-compose.yml

# Backups
backup/

# Logs
*.log

# Temporary files
*.tmp
.env

# OS
.DS_Store
Thumbs.db
EOF
```

```bash
cat > configs/docker-compose.yml.example << 'EOF'
version: '3.8'

services:
  wg-easy:
    environment:
      - WG_HOST=YOUR_SERVER_IP
      - PASSWORD_HASH=YOUR_PASSWORD_HASH
      - PORT=51821
      - WG_PORT=51820
      - WG_DEFAULT_ADDRESS=10.8.0.x
      - WG_DEFAULT_DNS=1.1.1.1,8.8.8.8
      - WG_ALLOWED_IPS=0.0.0.0/0,::/0
      - WG_PERSISTENT_KEEPALIVE=25
      - WG_MTU=1420
      - UI_TRAFFIC_STATS=true
      - UI_CHART_TYPE=2
      
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    volumes:
      - wg-data:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1

volumes:
  wg-data:
EOF
```
