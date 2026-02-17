#!/bin/bash

# Скрипт проверки настройки DHCP-сервера для Альт Линукс
# Задание: настроить DHCP-сервер с параметрами:
# - сеть: 192.168.0.0/24
# - интерфейс: enp7s2
# - пул: 192.168.0.10-192.168.0.200
# - шлюз: 192.168.0.1
# - DNS: 10.0.0.1

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переменные для подсчета баллов
TOTAL_SCORE=0
MAX_SCORE=5
CHECKED_ITEMS=0

# Функция для проверки условия
check_condition() {
    local condition="$1"
    local description="$2"
    local points="$3"
    
    echo -e "\n${YELLOW}[${CHECKED_ITEMS}/5] Проверка: ${description}${NC}"
    
    if eval "$condition"; then
        echo -e "  ${GREEN}✓ ВЫПОЛНЕНО (+${points} балл)${NC}"
        TOTAL_SCORE=$((TOTAL_SCORE + points))
    else
        echo -e "  ${RED}✗ НЕ ВЫПОЛНЕНО (0 баллов)${NC}"
        echo -e "    ${BLUE}Ожидалось:${NC} $4"
        echo -e "    ${BLUE}Текущее:${NC} $5"
    fi
    
    CHECKED_ITEMS=$((CHECKED_ITEMS + 1))
}

# Проверка запуска от root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Скрипт должен запускаться от root для полной проверки${NC}" 
   exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  ПРОВЕРКА НАСТРОЙКИ DHCP-СЕРВЕРА${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Задание: настройка DHCP для сети 192.168.0.0/24\n"

# Проверка 1: Установлен ли DHCP-сервер (1 балл)
check_condition \
    "command -v dhcpd &>/dev/null || rpm -q dhcp-server &>/dev/null || systemctl list-unit-files | grep -q dhcpd" \
    "Установка DHCP-сервера (1 балл)" \
    1 \
    "Пакет dhcp-server должен быть установлен" \
    "$(rpm -qa | grep -i dhcp 2>/dev/null || echo 'DHCP сервер не найден')"

# Проверка 2: Запущен ли DHCP-сервер и включен в автозагрузку (1 балл)
check_condition \
    "systemctl is-active dhcpd &>/dev/null && systemctl is-enabled dhcpd &>/dev/null" \
    "Сервис запущен и добавлен в автозагрузку (1 балл)" \
    1 \
    "Сервис dhcpd должен быть active и enabled" \
    "$(systemctl status dhcpd 2>/dev/null | grep -E 'Active|Loaded' | head -2 || echo 'Сервис не найден')"

# Проверка 3: Правильный интерфейс в конфигурации (1 балл)
check_condition \
    "grep -q 'interface.*enp7s2' /etc/dhcp/dhcpd.conf 2>/dev/null || grep -q 'INTERFACES=.*enp7s2' /etc/default/dhcp-server 2>/dev/null" \
    "Интерфейс enp7s2 настроен (1 балл)" \
    1 \
    "Интерфейс enp7s2 должен быть указан в конфигурации" \
    "Найденные интерфейсы: $(grep -h 'interface\|INTERFACES' /etc/dhcp/dhcpd.conf /etc/default/dhcp-server 2>/dev/null | head -3 || echo 'не найдены')"

# Проверка 4: Правильные параметры подсети (шлюз, DNS, пул) (1 балл)
check_condition \
    "grep -q '192.168.0.0.*255.255.255.0' /etc/dhcp/dhcpd.conf 2>/dev/null && \
     grep -q 'option.*routers.*192.168.0.1' /etc/dhcp/dhcpd.conf 2>/dev/null && \
     grep -q 'option.*domain-name-servers.*10.0.0.1' /etc/dhcp/dhcpd.conf 2>/dev/null" \
    "Параметры сети (шлюз 192.168.0.1, DNS 10.0.0.1) (1 балл)" \
    1 \
    "Должны быть настроены: subnet 192.168.0.0/24, routers 192.168.0.1, dns 10.0.0.1" \
    "$(grep -E 'subnet|routers|domain-name-servers' /etc/dhcp/dhcpd.conf 2>/dev/null | head -5 || echo 'не найдено')"

# Проверка 5: Правильный диапазон адресов (1 балл)
# Примечание: в задании опечатка 192.168.168.200, но проверяем оба варианта
check_condition \
    "grep -q 'range.*192.168.0.10.*192.168.0.200' /etc/dhcp/dhcpd.conf 2>/dev/null || \
     grep -q 'range.*192.168.0.10.*192.168.168.200' /etc/dhcp/dhcpd.conf 2>/dev/null" \
    "Диапазон адресов 192.168.0.10-192.168.168.200 (1 балл)" \
    1 \
    "Должен быть указан range 192.168.0.10 - 192.168.168.200" \
    "$(grep 'range' /etc/dhcp/dhcpd.conf 2>/dev/null | head -3 || echo 'range не найден')"

# Подсчет итоговой оценки
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}              РЕЗУЛЬТАТ                ${NC}"
echo -e "${BLUE}========================================${NC}"

# Конвертация в 5-балльную шкалу
if [[ $TOTAL_SCORE -eq 5 ]]; then
    GRADE=5
    GRADE_COLOR=$GREEN
    COMMENT="Отлично! Все настройки выполнены правильно"
elif [[ $TOTAL_SCORE -eq 4 ]]; then
    GRADE=4
    GRADE_COLOR=$GREEN
    COMMENT="Хорошо. Есть небольшие недочеты"
elif [[ $TOTAL_SCORE -eq 3 ]]; then
    GRADE=3
    GRADE_COLOR=$YELLOW
    COMMENT="Удовлетворительно. Требуется доработка"
else
    GRADE=2
    GRADE_COLOR=$RED
    COMMENT="Неудовлетворительно. Задание не выполнено"
fi

echo -e "Набрано баллов: ${YELLOW}${TOTAL_SCORE}/${MAX_SCORE}${NC}"
echo -e "Оценка: ${GRADE_COLOR}${GRADE}/5${NC}"
echo -e "Комментарий: ${BLUE}${COMMENT}${NC}"

# Дополнительная информация
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}      ДЕТАЛИ КОНФИГУРАЦИИ               ${NC}"
echo -e "${BLUE}========================================${NC}"

# Проверка синтаксиса конфигурации
echo -e "\n${YELLOW}Проверка синтаксиса конфигурации:${NC}"
if dhcpd -t -cf /etc/dhcp/dhcpd.conf 2>&1 | grep -q "OK"; then
    echo -e "  ${GREEN}✓ Синтаксис конфигурации верный${NC}"
else
    echo -e "  ${RED}✗ Ошибки в синтаксисе:${NC}"
    dhcpd -t -cf /etc/dhcp/dhcpd.conf 2>&1 | head -5 | sed 's/^/    /'
fi

# Информация о leases
if [ -f /var/lib/dhcp/dhcpd.leases ]; then
    LEASES_COUNT=$(grep -c "lease" /var/lib/dhcp/dhcpd.leases 2>/dev/null || echo 0)
    echo -e "\n${YELLOW}Активные аренды:${NC} ${GREEN}${LEASES_COUNT} клиентов${NC}"
    tail -n 20 /var/lib/dhcp/dhcpd.leases 2>/dev/null | grep -E "lease|hardware|client-hostname" | tail -6 | sed 's/^/  /' || echo "  Нет активных аренд"
fi

# Проверка прослушивания порта
echo -e "\n${YELLOW}Проверка сетевых портов:${NC}"
if ss -tulpn | grep -q ":67"; then
    echo -e "  ${GREEN}✓ Порт 67 (DHCP) прослушивается${NC}"
    ss -tulpn | grep ":67" | sed 's/^/  /'
else
    echo -e "  ${RED}✗ Порт 67 не прослушивается${NC}"
fi

# Проверка интерфейса
echo -e "\n${YELLOW}Проверка сетевого интерфейса enp7s2:${NC}"
if ip link show enp7s2 &>/dev/null; then
    echo -e "  ${GREEN}✓ Интерфейс enp7s2 существует${NC}"
    ip addr show enp7s2 | grep -E "inet|state" | sed 's/^/  /'
else
    echo -e "  ${RED}✗ Интерфейс enp7s2 не найден${NC}"
    echo -e "  ${BLUE}Доступные интерфейсы:${NC}"
    ip -br link show | grep -v LOOPBACK | head -5 | sed 's/^/    /'
fi

# Логи ошибок за последний час
echo -e "\n${YELLOW}Последние ошибки в логах (за 1 час):${NC}"
journalctl -u dhcpd --since "1 hour ago" | grep -i "error\|fail\|warn" | tail -5 | sed 's/^/  /' || echo "  Ошибок не найдено"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Для детального просмотра логов:${NC}"
echo "  journalctl -u dhcpd -xe"
echo "  tail -f /var/log/messages | grep dhcpd"

# Сохранение результата в файл
REPORT_FILE="/tmp/dhcp_check_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "ОТЧЕТ ПРОВЕРКИ DHCP-СЕРВЕРА"
    echo "Дата: $(date)"
    echo "Оценка: $GRADE/5"
    echo "Баллы: $TOTAL_SCORE/$MAX_SCORE"
    echo "Комментарий: $COMMENT"
    echo ""
    echo "Детали проверки:"
    grep -E "Проверка:|✓|✗" $0 | grep -v "grep"
} > $REPORT_FILE

echo -e "\n${GREEN}Отчет сохранен в: ${REPORT_FILE}${NC}"
