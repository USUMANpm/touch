#!/bin/bash
# Файл: check_hq-srv.sh
# Проверка конфигурации HQ-SRV (Alt Server)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    ПРОВЕРКА HQ-SRV (Alt Server)${NC}"
echo -e "${BLUE}========================================${NC}"

# Функция проверки
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    else
        echo -e "${RED}[FAIL]${NC} $1"
    fi
}

# Информация об устройстве
echo -e "\n${YELLOW}--- Информация об устройстве ---${NC}"
echo "  Hostname: $(hostname)"
echo "  Дата: $(date)"

# ============= ПРОВЕРКА VLAN =============
echo -e "\n${YELLOW}--- Проверка принадлежности к VLAN 100 ---${NC}"
if ip link show | grep -q "vlan100\|eth0.100"; then
    echo -e "${GREEN}[OK]${NC} Интерфейс VLAN 100 настроен"
    ip link show | grep -A1 "vlan100\|eth0.100" | sed 's/^/  /'
elif ip addr show | grep -q "192.168.100."; then
    echo -e "${YELLOW}[WARN]${NC} IP из сети 192.168.100.0 найден, но VLAN интерфейс не обнаружен"
else
    echo -e "${RED}[FAIL]${NC} Принадлежность к VLAN 100 не обнаружена"
fi

# ============= ПРОВЕРКА IP АДРЕСА =============
echo -e "\n${YELLOW}--- Проверка IP адреса ---${NC}"
IP_ADDR=$(ip -4 addr show | grep "192.168.100." | awk '{print $2}')
if [ -n "$IP_ADDR" ]; then
    echo -e "${GREEN}[OK]${NC} IP адрес: $IP_ADDR"
    if echo "$IP_ADDR" | grep -q "/27"; then
        echo -e "${GREEN}[OK]${NC} Маска /27 соответствует требованиям"
    else
        echo -e "${RED}[FAIL]${NC} Ожидается маска /27, получено ${IP_ADDR#*/}"
    fi
else
    echo -e "${RED}[FAIL]${NC} IP адрес из сети 192.168.100.0 не найден"
fi

# ============= ПРОВЕРКА ШЛЮЗА ПО УМОЛЧАНИЮ =============
echo -e "\n${YELLOW}--- Проверка шлюза по умолчанию ---${NC}"
DEFAULT_GW=$(ip route show | grep "^default" | awk '{print $3}')
if [ -n "$DEFAULT_GW" ]; then
    echo -e "${GREEN}[OK]${NC} Шлюз по умолчанию: $DEFAULT_GW"
    if [[ "$DEFAULT_GW" == 192.168.100.* ]]; then
        echo -e "${GREEN}[OK]${NC} Шлюз находится в правильной сети"
    else
        echo -e "${RED}[FAIL]${NC} Шлюз должен быть в сети 192.168.100.0"
    fi
else
    echo -e "${RED}[FAIL]${NC} Шлюз по умолчанию не настроен"
fi

# ============= ПРОВЕРКА ДОСТУПА В ИНТЕРНЕТ =============
echo -e "\n${YELLOW}--- Проверка доступа в интернет ---${NC}"
echo -e "${BLUE}Ping до 8.8.8.8:${NC}"
if ping -c 2 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}[OK]${NC} Доступ в интернет есть"
    
    # Проверка задержки
    PING_TIME=$(ping -c 1 -W 2 8.8.8.8 | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}')
    echo "  Время отклика: ${PING_TIME}ms"
else
    echo -e "${RED}[FAIL]${NC} Нет доступа в интернет"
fi

# ============= ПРОВЕРКА DNS =============
echo -e "\n${YELLOW}--- Проверка DNS ---${NC}"
if grep -q "nameserver" /etc/resolv.conf; then
    echo -e "${GREEN}[OK]${NC} DNS серверы настроены:"
    grep "nameserver" /etc/resolv.conf | sed 's/^/  /'
    
    # Проверка разрешения имен
    echo -e "${BLUE}Разрешение имени au-team.irpo:${NC}"
    if nslookup au-team.irpo &>/dev/null; then
        echo -e "${GREEN}[OK]${NC} DNS работает"
    else
        echo -e "${RED}[FAIL]${NC} Не удается разрешить au-team.irpo"
    fi
else
    echo -e "${RED}[FAIL]${NC} DNS серверы не настроены