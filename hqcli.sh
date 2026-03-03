#!/bin/bash
# Файл: check_hq-cli.sh
# Проверка конфигурации HQ-CLI (Alt Workstation)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    ПРОВЕРКА HQ-CLI (Alt Workstation)${NC}"
echo -e "${BLUE}========================================${NC}"

# Функция проверки
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} $1"
    else
        echo -e "${RED}[FAIL]${NC} $1"
    fi
}

# Функция для проверки с подсветкой
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Информация об устройстве
echo -e "\n${YELLOW}--- Информация об устройстве ---${NC}"
echo "  Hostname: $(hostname)"
echo "  Дата: $(date)"
echo "  ОС: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  Ядро: $(uname -r)"

# ============= ПРОВЕРКА VLAN 200 =============
echo -e "\n${YELLOW}--- Проверка принадлежности к VLAN 200 ---${NC}"
if ip link show | grep -q "vlan200\|eth0.200"; then
    echo -e "${GREEN}[OK]${NC} Интерфейс VLAN 200 настроен"
    VLAN_IF=$(ip link show | grep -B1 "vlan200\|eth0.200" | head -1 | awk '{print $2}' | tr -d ':')
    echo "  Интерфейс: $VLAN_IF"
elif ip addr show | grep -q "192.168.200."; then
    echo -e "${YELLOW}[WARN]${NC} IP из сети 192.168.200.0 найден, но VLAN интерфейс не обнаружен"
else
    echo -e "${YELLOW}[INFO]${NC} VLAN 200 может быть настроен на уровне коммутатора"
fi

# ============= ПРОВЕРКА DHCP =============
echo -e "\n${YELLOW}--- Проверка получения IP по DHCP ---${NC}"

# Получаем IP адрес из сети 192.168.200.0
IP_ADDR=$(ip -4 addr show | grep "192.168.200." | awk '{print $2}')
if [ -n "$IP_ADDR" ]; then
    echo -e "${GREEN}[OK]${NC} IP адрес получен: $IP_ADDR"
    
    # Проверка маски /28
    if echo "$IP_ADDR" | grep -q "/28"; then
        echo -e "${GREEN}[OK]${NC} Маска /28 соответствует требованиям"
    else
        echo -e "${YELLOW}[WARN]${NC} Текущая маска: ${IP_ADDR#*/}, ожидается /28"
    fi
    
    # Проверяем время аренды DHCP
    DHCP_INFO=$(ps aux | grep -v grep | grep dhclient)
    if [ -n "$DHCP_INFO" ]; then
        echo -e "${GREEN}[OK]${NC} DHCP клиент активен"
        
        # Пытаемся найти информацию о аренде
        LEASE_FILE="/var/lib/dhcp/dhclient.leases"
        if [ -f "$LEASE_FILE" ]; then
            LEASE_TIME=$(grep -A10 "$IP_ADDR" "$LEASE_FILE" 2>/dev/null | grep "renew" | head -1)
            [ -n "$LEASE_TIME" ] && echo "  Информация о аренде: $LEASE_TIME"
        fi
    fi
else
    echo -e "${RED}[FAIL]${NC} IP адрес из сети 192.168.200.0 не получен"
    
    # Проверяем, запущен ли DHCP клиент
    if ps aux | grep -q "[d]hclient"; then
        echo -e "${YELLOW}[WARN]${NC} DHCP клиент запущен, но IP не получен"
    else
        echo -e "${RED}[FAIL]${NC} DHCP клиент не запущен"
    fi
fi

# ============= ПРОВЕРКА ШЛЮЗА ПО УМОЛЧАНИЮ =============
echo -e "\n${YELLOW}--- Проверка шлюза по умолчанию ---${NC}"
DEFAULT_GW=$(ip route show | grep "^default" | awk '{print $3}')
DEFAULT_IF=$(ip route show | grep "^default" | awk '{print $5}')

if [ -n "$DEFAULT_GW" ]; then
    echo -e "${GREEN}[OK]${NC} Шлюз по умолчанию: $DEFAULT_GW"
    echo "  Интерфейс: $DEFAULT_IF"
    
    # Проверяем, что шлюз в сети 192.168.200.0
    if [[ "$DEFAULT_GW" == 192.168.200.* ]]; then
        echo -e "${GREEN}[OK]${NC} Шлюз находится в правильной сети"
        
        # Проверяем, что шлюз не равен адресу клиента
        CLIENT_IP=$(echo $IP_ADDR | cut -d'/' -f1)
        if [ "$DEFAULT_GW" != "$CLIENT_IP" ]; then
            echo -e "${GREEN}[OK]${NC} Адрес шлюза отличается от адреса клиента"
        else
            echo -e "${RED}[FAIL]${NC} Адрес шлюза совпадает с адресом клиента"
        fi
    else
        echo -e "${RED}[FAIL]${NC} Шлюз должен быть в сети 192.168.200.0"
    fi
else
    echo -e "${RED}[FAIL]${NC} Шлюз по умолчанию не настроен"
fi

# ============= ПРОВЕРКА DNS =============
echo -e "\n${YELLOW}--- Проверка DNS ---${NC}"

# Проверка DNS серверов
if [ -f /etc/resolv.conf ]; then
    echo -e "${BLUE}Конфигурация resolv.conf:${NC}"
    cat /etc/resolv.conf | sed 's/^/  /'
    
    # Проверка DNS сервера (должен быть HQ-SRV - 192.168.100.x)
    DNS_SERVERS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}')
    if [ -n "$DNS_SERVERS" ]; then
        echo -e "\n${BLUE}Проверка DNS серверов:${NC}"
        DNS_OK=0
        for DNS in $DNS_SERVERS; do
            if [[ "$DNS" == 192.168.100.* ]]; then
                echo -e "  ${GREEN}✓${NC} DNS сервер $DNS (HQ-SRV)"
                DNS_OK=1
            else
                echo -e "  ${YELLOW}⚠${NC} DNS сервер $DNS (не из сети HQ-SRV)"
            fi
        done
        
        if [ $DNS_OK -eq 1 ]; then
            echo -e "${GREEN}[OK]${NC} DNS сервер HQ-SRV настроен"
        else
            echo -e "${RED}[FAIL]${NC} DNS сервер HQ-SRV (192.168.100.x) не найден"
        fi
    else
        echo -e "${RED}[FAIL]${NC} DNS серверы не настроены"
    fi
    
    # Проверка DNS-суффикса
    if grep -q "search" /etc/resolv.conf; then
        SEARCH=$(grep "^search" /etc/resolv.conf)
        echo -e "\n${BLUE}DNS search domain:${NC} $SEARCH"
        if echo "$SEARCH" | grep -q "au-team.irpo"; then
            echo -e "${GREEN}[OK]${NC} DNS-суффикс au-team.irpo настроен"
        else
            echo -e "${RED}[FAIL]${NC} DNS-суффикс au-team.irpo не найден"
        fi
    else
        echo -e "${RED}[FAIL]${NC} DNS search domain не настроен"
    fi
else
    echo -e "${RED}[FAIL]${NC} Файл /etc/resolv.conf не найден"
fi

# ============= ПРОВЕРКА СВЯЗНОСТИ =============
echo -e "\n${YELLOW}--- Проверка связности ---${NC}"

# Функция для проверки доступности хоста
test_connectivity() {
    local host=$1
    local name=$2
    local count=${3:-2}
    
    echo -e "${BLUE}Проверка $name ($host):${NC}"
    if ping -c $count -W 2 $host &>/dev/null; then
        local avg_time=$(ping -c $count -W 2 $host | grep "avg" | awk -F'/' '{print $5}')
        echo -e "  ${GREEN}✓${NC} Доступен (${avg_time}ms)"
        return 0
    else
        echo -e "  ${RED}✗${NC} Недоступен"
        return 1
    fi
}

# Проверка шлюза
if [ -n "$DEFAULT_GW" ]; then
    test_connectivity $DEFAULT_GW "шлюз (HQ-RTR)"
fi

# Проверка HQ-SRV
HQ_SRV="192.168.100.2"  # Предполагаемый адрес HQ-SRV
test_connectivity $HQ_SRV "HQ-SRV"

# Проверка доступа в интернет (8.8.8.8)
test_connectivity "8.8.8.8" "интернет (8.8.8.8)"

# Проверка DNS разрешения
echo -e "\n${BLUE}Проверка DNS разрешения:${NC}"
if nslookup au-team.irpo &>/dev/null; then
    IP=$(nslookup au-team.irpo | grep -A1 "Name:" | grep "Address" | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} au-team.irpo разрешается в $IP"
else
    echo -e "  ${RED}✗${NC} Не удается разрешить au-team.irpo"
fi

# ============= ПРОВЕРКА АДРЕСА МАРШРУТИЗАТОРА (ИСКЛЮЧЕН ИЗ DHCP) =============
echo -e "\n${YELLOW}--- Проверка исключения адреса маршрутизатора ---${NC}"

# Предполагаем, что адрес маршрутизатора - первый адрес в подсети
ROUTER_IP="192.168.200.1"

if [ "$IP_ADDR" != "$ROUTER_IP/28" ] && [ "$(echo $IP_ADDR | cut -d'/' -f1)" != "$ROUTER_IP" ]; then
    echo -e "${GREEN}[OK]${NC} Клиент не использует адрес маршрутизатора ($ROUTER_IP)"
else
    echo -e "${RED}[FAIL]${NC} Клиент использует адрес маршрутизатора ($ROUTER_IP)"
fi

# ============= ПРОВЕРКА ДОПОЛНИТЕЛЬНЫХ СЕРВИСОВ =============
echo -e "\n${YELLOW}--- Проверка дополнительных сервисов ---${NC}"

# Проверка SSH (опционально)
if systemctl is-active sshd &>/dev/null || systemctl is-active ssh &>/dev/null; then
    echo -e "${GREEN}[OK]${NC} SSH сервер запущен"
else
    echo -e "${YELLOW}[INFO]${NC} SSH сервер не запущен"
fi

# Проверка NetworkManager
if systemctl is-active NetworkManager &>/dev/null; then
    echo -e "${YELLOW}[INFO]${NC} NetworkManager активен"
    echo -e "${BLUE}NetworkManager соединения:${NC}"
    nmcli -t -f NAME,TYPE,DEVICE con show --active 2>/dev/null | head -5 | sed 's/^/  /'
fi

# ============= ПРОВЕРКА VLAN НА КОММУТАТОРЕ (ОПЦИОНАЛЬНО) =============
echo -e "\n${YELLOW}--- Проверка VLAN через коммутатор (опционально) ---${NC}"
if command -v arp &>/dev/null; then
    echo -e "${BLUE}ARP таблица:${NC}"
    arp -n | grep -v "incomplete" | head -10 | sed 's/^/  /'
fi

# ============= СБОР ИНФОРМАЦИИ =============
echo -e "\n${YELLOW}--- Сетевая информация ---${NC}"

# MAC адрес
MAC_ADDR=$(ip link show | grep -A1 "eth0\|enp" | grep "link/ether" | awk '{print $2}' | head -1)
if [ -n "$MAC_ADDR" ]; then
    echo "  MAC адрес: $MAC_ADDR"
fi

# Статистика интерфейсов
echo -e "\n${BLUE}Статистика интерфейсов:${NC}"
ip -s link show | grep -A2 "eth0\|enp" | head -6 | sed 's/^/  /'

# Открытые порты
echo -e "\n${BLUE}Открытые порты (netstat):${NC}"
ss -tuln | grep -E ":(80|443|22|53)" | head -10 | sed 's/^/  /'

# ============= ПРОВЕРКА ЛОГОВ =============
echo -e "\n${YELLOW}--- Проверка логов на ошибки ---${NC}"
if [ -f /var/log/messages ]; then
    tail -20 /var/log/messages 2>/dev/null | grep -i "dhcp\|network\|error" | tail -5 | sed 's/^/  /' || echo "  Ошибок не найдено"
elif [ -f /var/log/syslog ]; then
    tail -20 /var/log/syslog 2>/dev/null | grep -i "dhcp\|network\|error" | tail -5 | sed 's/^/  /' || echo "  Ошибок не найдено"
fi

# ============= ИТОГОВАЯ ТАБЛИЦА =============
echo -e "\n${YELLOW}--- Сводка проверок ---${NC}"

# Подсчет результатов
TOTAL_CHECKS=0
PASSED_CHECKS=0

check_result() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ $1 -eq 0 ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo -e "  ${GREEN}✓${NC} $2"
    else
        echo -e "  ${RED}✗${NC} $2"
    fi
}

# Основные проверки
[ -n "$IP_ADDR" ]; check_result $? "Получение IP по DHCP"
[ -n "$DEFAULT_GW" ]; check_result $? "Настройка шлюза"
[[ "$DEFAULT_GW" == 192.168.200.* ]]; check_result $? "Шлюз в сети 192.168.200.0"
grep -q "au-team.irpo" /etc/resolv.conf; check_result $? "DNS-суффикс au-team.irpo"
grep -q "192.168.100." /etc/resolv.conf; check_result $? "DNS сервер HQ-SRV"
ping -c 1 -W 2 8.8.8.8 &>/dev/null; check_result $? "Доступ в интернет"
ping -c 1 -W 2 192.168.100.2 &>/dev/null; check_result $? "Доступ к HQ-SRV"

echo -e "\n${BLUE}Результат: $PASSED_CHECKS из $TOTAL_CHECKS проверок пройдено${NC}"

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}Все проверки успешно пройдены!${NC}"
elif [ $PASSED_CHECKS -gt $(($TOTAL_CHECKS / 2)) ]; then
    echo -e "${YELLOW}Большинство проверок пройдено, но есть замечания.${NC}"
else
    echo -e "${RED}Критические проблемы в конфигурации!${NC}"
fi

# ============= ПОЛЕЗНЫЕ КОМАНДЫ =============
echo -e "\n${YELLOW}--- Полезные команды для диагностики ---${NC}"
echo "  ip a                     # Просмотр IP адресов"
echo "  ip route                 # Просмотр маршрутов"
echo "  cat /etc/resolv.conf     # Просмотр DNS"
echo "  dhclient -v eth0         # Принудительный запрос DHCP"
echo "  ping 192.168.200.1       # Проверка шлюза"
echo "  nslookup au-team.irpo    # Проверка DNS"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}    ПРОВЕРКА HQ-CLI ЗАВЕРШЕНА${NC}"
echo -e "${BLUE}========================================${NC}"