#!/bin/bash
# Файл: check_isp.sh
# Проверка конфигурации ISP маршрутизатора (Alt JeOS)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    ПРОВЕРКА ISP (Alt JeOS)${NC}"
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

# ============= ПРОВЕРКА ИНТЕРФЕЙСОВ =============
echo -e "\n${YELLOW}--- Проверка сетевых интерфейсов ---${NC}"
ip -br link show | sed 's/^/  /'

# ============= ПРОВЕРКА DHCP НА ВНЕШНЕМ ИНТЕРФЕЙСЕ =============
echo -e "\n${YELLOW}--- Проверка DHCP на внешнем интерфейсе ---${NC}"

# Определяем внешний интерфейс (обычно eth0)
EXT_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -n "$EXT_IF" ]; then
    echo "  Внешний интерфейс: $EXT_IF"
    EXT_IP=$(ip -4 addr show $EXT_IF | grep inet | awk '{print $2}')
    if [ -n "$EXT_IP" ]; then
        echo -e "${GREEN}[OK]${NC} Интерфейс $EXT_IF получил IP по DHCP: $EXT_IP"
    else
        echo -e "${RED}[FAIL]${NC} Интерфейс $EXT_IF не получил IP по DHCP"
    fi
else
    echo -e "${RED}[FAIL]${NC} Не удалось определить внешний интерфейс"
fi

# ============= ПРОВЕРКА ИНТЕРФЕЙСА К HQ-RTR =============
echo -e "\n${YELLOW}--- Проверка интерфейса к HQ-RTR (172.16.1.0/28) ---${NC}"
if ip -4 addr show | grep -q "172.16.1."; then
    HQ_IP=$(ip -4 addr show | grep "172.16.1." | awk '{print $2}')
    echo -e "${GREEN}[OK]${NC} Интерфейс к HQ-RTR настроен: $HQ_IP"
    
    # Проверка маски /28
    if echo "$HQ_IP" | grep -q "/28"; then
        echo -e "${GREEN}[OK]${NC} Маска /28 настроена правильно"
    else
        echo -e "${RED}[FAIL]${NC} Ожидается маска /28, получено ${HQ_IP#*/}"
    fi
else
    echo -e "${RED}[FAIL]${NC} Интерфейс к HQ-RTR не настроен"
fi

# ============= ПРОВЕРКА ИНТЕРФЕЙСА К BR-RTR =============
echo -e "\n${YELLOW}--- Проверка интерфейса к BR-RTR (172.16.2.0/28) ---${NC}"
if ip -4 addr show | grep -q "172.16.2."; then
    BR_IP=$(ip -4 addr show | grep "172.16.2." | awk '{print $2}')
    echo -e "${GREEN}[OK]${NC} Интерфейс к BR-RTR настроен: $BR_IP"
    
    # Проверка маски /28
    if echo "$BR_IP" | grep -q "/28"; then
        echo -e "${GREEN}[OK]${NC} Маска /28 настроена правильно"
    else
        echo -e "${RED}[FAIL]${NC} Ожидается маска /28, получено ${BR_IP#*/}"
    fi
else
    echo -e "${RED}[FAIL]${NC} Интерфейс к BR-RTR не настроен"
fi

# ============= ПРОВЕРКА МАРШРУТА ПО УМОЛЧАНИЮ =============
echo -e "\n${YELLOW}--- Проверка маршрута по умолчанию ---${NC}"
if ip route show | grep -q "^default"; then
    DEFAULT_ROUTE=$(ip route show | grep "^default")
    echo -e "${GREEN}[OK]${NC} Маршрут по умолчанию есть: $DEFAULT_ROUTE"
else
    echo -e "${RED}[FAIL]${NC} Маршрут по умолчанию отсутствует"
fi

# ============= ПРОВЕРКА NAT =============
echo -e "\n${YELLOW}--- Проверка NAT ---${NC}"
if iptables -t nat -L -n | grep -q "MASQUERADE"; then
    echo -e "${GREEN}[OK]${NC} NAT (MASQUERADE) настроен"
    iptables -t nat -L -n | grep MASQUERADE | sed 's/^/  /'
else
    echo -e "${RED}[FAIL]${NC} NAT не настроен"
fi

# Проверка IP форвардинга
if sysctl net.ipv4.ip_forward | grep -q "1"; then
    echo -e "${GREEN}[OK]${NC} IP Forwarding включен"
else
    echo -e "${RED}[FAIL]${NC} IP Forwarding выключен"
fi

# ============= ПРОВЕРКА СВЯЗНОСТИ =============
echo -e "\n${YELLOW}--- Проверка связности ---${NC}"

# Ping до HQ-RTR
HQ_RTR_IP="172.16.1.1"
echo -e "${BLUE}Ping до HQ-RTR ($HQ_RTR_IP):${NC}"
ping -c 2 -W 1 $HQ_RTR_IP &>/dev/null && echo -e "${GREEN}[OK]${NC} HQ-RTR доступен" || echo -e "${RED}[FAIL]${NC} HQ-RTR недоступен"

# Ping до BR-RTR
BR_RTR_IP="172.16.2.1"
echo -e "${BLUE}Ping до BR-RTR ($BR_RTR_IP):${NC}"
ping -c 2 -W 1 $BR_RTR_IP &>/dev/null && echo -e "${GREEN}[OK]${NC} BR-RTR доступен" || echo -e "${RED}[FAIL]${NC} BR-RTR недоступен"

# Ping до внешнего мира (8.8.8.8)
echo -e "${BLUE}Ping до 8.8.8.8:${NC}"
ping -c 2 -W 1 8.8.8.8 &>/dev/null && echo -e "${GREEN}[OK]${NC} Доступ в интернет есть" || echo -e "${RED}[FAIL]${NC} Нет доступа в интернет"

# ============= ТАБЛИЦА МАРШРУТИЗАЦИИ =============
echo -e "\n${YELLOW}--- Таблица маршрутизации ---${NC}"
ip route show | sed 's/^/  /'

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}    ПРОВЕРКА ISP ЗАВЕРШЕНА${NC}"
echo -e "${BLUE}========================================${NC}"