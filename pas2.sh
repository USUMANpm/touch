#!/bin/bash

# Скрипт настройки DHCP-сервера для Альт Линукс
# Параметры:
# Сеть: 192.168.0.0/24
# Интерфейс: enp7s2
# Пул: 192.168.0.10-192.168.0.200
# Шлюз: 192.168.0.1
# DNS: 10.0.0.1

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка запуска от root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Этот скрипт должен запускаться от root${NC}" 
   exit 1
fi

echo -e "${YELLOW}Начинаем настройку DHCP-сервера...${NC}"

# Установка DHCP-сервера
echo -e "${GREEN}Устанавливаем DHCP-сервер...${NC}"
apt-get update
apt-get install -y dhcp-server

if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка установки DHCP-сервера${NC}"
    exit 1
fi

# Создание резервной копии оригинального конфига
if [ -f /etc/dhcp/dhcpd.conf ]; then
    cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}Создана резервная копия конфигурации${NC}"
fi

# Создание конфигурации DHCP-сервера
cat > /etc/dhcp/dhcpd.conf << 'EOF'
# DHCP Server Configuration
# Файл создан автоматически скриптом настройки

# Глобальные настройки
option domain-name-servers 10.0.0.1;
default-lease-time 600;
max-lease-time 7200;
authoritative;

# Логирование
log-facility local7;

# Настройки подсети
subnet 192.168.0.0 netmask 255.255.255.0 {
    interface enp7s2;
    range 192.168.0.10 192.168.0.200;
    option routers 192.168.0.1;
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.0.255;
    option domain-name-servers 10.0.0.1;
    
    # Время аренды по умолчанию (в секундах)
    default-lease-time 86400;  # 1 день
    max-lease-time 604800;      # 1 неделя
}
EOF

# Проверка конфигурации
echo -e "${YELLOW}Проверяем конфигурацию DHCP-сервера...${NC}"
dhcpd -t -cf /etc/dhcp/dhcpd.conf

if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка в конфигурации DHCP-сервера${NC}"
    exit 1
fi

# Настройка интерфейса в /etc/default/dhcp-server
if [ -f /etc/default/dhcp-server ]; then
    cp /etc/default/dhcp-server /etc/default/dhcp-server.bak.$(date +%Y%m%d_%H%M%S)
fi

# Указываем интерфейс для прослушивания
echo "INTERFACES=\"enp7s2\"" > /etc/default/dhcp-server

# Включаем и запускаем сервис
echo -e "${GREEN}Запускаем DHCP-сервер...${NC}"
systemctl enable dhcpd
systemctl restart dhcpd

# Проверка статуса
sleep 2
if systemctl is-active --quiet dhcpd; then
    echo -e "${GREEN}DHCP-сервер успешно запущен!${NC}"
    systemctl status dhcpd --no-pager
else
    echo -e "${RED}Ошибка запуска DHCP-сервера${NC}"
    echo -e "${YELLOW}Проверьте журнал: journalctl -u dhcpd -xe${NC}"
    exit 1
fi

# Настройка файрвола (если используется)
if command -v firewall-cmd &> /dev/null; then
    echo -e "${GREEN}Настраиваем файрвол...${NC}"
    firewall-cmd --permanent --add-service=dhcp
    firewall-cmd --reload
elif command -v iptables &> /dev/null; then
    echo -e "${GREEN}Настраиваем iptables...${NC}"
    iptables -I INPUT -p udp --dport 67 -j ACCEPT
    iptables-save > /etc/sysconfig/iptables
fi

# Информация о настройках
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Настройка DHCP-сервера завершена!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Параметры:${NC}"
echo -e "  Сеть: ${GREEN}192.168.0.0/24${NC}"
echo -e "  Интерфейс: ${GREEN}enp7s2${NC}"
echo -e "  Пул адресов: ${GREEN}192.168.0.10 - 192.168.0.200${NC}"
echo -e "  Шлюз: ${GREEN}192.168.0.1${NC}"
echo -e "  DNS: ${GREEN}10.0.0.1${NC}"
echo -e "  Маска подсети: ${GREEN}255.255.255.0${NC}"
echo -e "  Broadcast: ${GREEN}192.168.0.255${NC}"
echo -e "${GREEN}========================================${NC}"

# Проверка прослушивания порта
echo -e "\n${YELLOW}Проверка прослушивания порта DHCP (67):${NC}"
netstat -tulpn | grep :67 || ss -tulpn | grep :67

# Информация о логах
echo -e "\n${YELLOW}Для просмотра логов используйте:${NC}"
echo "  journalctl -u dhcpd -f"
echo "  tail -f /var/log/messages | grep dhcpd"

echo -e "\n${GREEN}Готово!${NC}"