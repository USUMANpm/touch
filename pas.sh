#!/bin/bash

# Скрипт для настройки Альт Сервера
# Выполняет:
# 1. Настройку второго интерфейса с IP 192.168.0.1/24
# 2. Настройку NAT (маскарадинг) через iptables
# 3. Установку имени сервера "srv"

set -e  # Прерывать выполнение при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка запуска от root
if [[ $EUID -ne 0 ]]; then
   print_error "Этот скрипт должен запускаться от root (sudo)"
   exit 1
fi

print_info "Начинаем настройку Альт Сервера..."
print_info "======================================"

# Определение переменных
# ВНИМАНИЕ: Измените эти значения под вашу конфигурацию!
EXTERNAL_IF="enp7s1"      # Интерфейс с выходом в интернет (обычно первый)
INTERNAL_IF="enp7s2"       # Второй интерфейс для внутренней сети
INTERNAL_IP="192.168.0.1/24"  # IP адрес для внутреннего интерфейса
INTERNAL_NET="192.168.0.0/24" # Внутренняя сеть
HOSTNAME="srv"             # Имя сервера

print_info "Конфигурация:"
print_info "  Имя сервера: $HOSTNAME"
print_info "  Внешний интерфейс: $EXTERNAL_IF (интернет)"
print_info "  Внутренний интерфейс: $INTERNAL_IF -> $INTERNAL_IP"
print_info "  Внутренняя сеть: $INTERNAL_NET"
print_info "======================================"

# Проверка наличия интерфейсов
print_info "Проверка сетевых интерфейсов..."
if ! ip link show $EXTERNAL_IF &>/dev/null; then
    print_error "Внешний интерфейс $EXTERNAL_IF не найден!"
    print_info "Доступные интерфейсы:"
    ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | sed 's/ //g'
    exit 1
fi

if ! ip link show $INTERNAL_IF &>/dev/null; then
    print_error "Внутренний интерфейс $INTERNAL_IF не найден!"
    print_info "Проверьте, подключен ли второй сетевой адаптер в настройках ВМ"
    exit 1
fi

# 3. Установка имени сервера
print_info "Устанавливаем имя сервера: $HOSTNAME..."
hostnamectl set-hostname $HOSTNAME

# Проверка и применение имени
CURRENT_HOSTNAME=$(hostname)
if [ "$CURRENT_HOSTNAME" = "$HOSTNAME" ]; then
    print_info "Имя сервера успешно изменено на $CURRENT_HOSTNAME"
else
    print_warn "Имя сервера не применилось сразу. Будет применено после перезагрузки."
fi

# Обновление /etc/hosts (рекомендуется для Альт Сервер)
print_info "Обновляем /etc/hosts..."
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain
127.0.1.1   $HOSTNAME
::1         localhost localhost.localdomain ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# 1. Настройка второго интерфейса (etcnet - стандартная для Альт Сервер)
print_info "Настройка внутреннего интерфейса $INTERNAL_IF..."

# Создание каталога для интерфейса, если его нет [citation:1]
if [ ! -d /etc/net/ifaces/$INTERNAL_IF ]; then
    print_info "Создаем каталог /etc/net/ifaces/$INTERNAL_IF..."
    mkdir -p /etc/net/ifaces/$INTERNAL_IF
fi

# Создание файла options для статического интерфейса [citation:1]
print_info "Создание файла options..."
cat > /etc/net/ifaces/$INTERNAL_IF/options << EOF
BOOTPROTO=static
TYPE=eth
DISABLED=no
NM_CONTROLLED=no
CONFIG_IPV4=YES
CONFIG_IPV6=NO
EOF

# Назначение статического IP-адреса [citation:1]
print_info "Назначение IP-адреса $INTERNAL_IP..."
echo "$INTERNAL_IP" > /etc/net/ifaces/$INTERNAL_IF/ipv4address

# Проверка создания файла
if [ -f /etc/net/ifaces/$INTERNAL_IF/ipv4address ]; then
    print_info "Файл ipv4address создан успешно"
else
    print_error "Не удалось создать файл ipv4address"
    exit 1
fi

# Перезапуск сетевой службы для применения настроек [citation:1]
print_info "Перезапуск сетевой службы..."
systemctl restart network

# Проверка применения IP-адреса
print_info "Проверка назначенных IP-адресов..."
ip -4 addr show $INTERNAL_IF | grep -q "$(echo $INTERNAL_IP | cut -d/ -f1)"
if [ $? -eq 0 ]; then
    print_info "IP-адрес успешно назначен на интерфейс $INTERNAL_IF"
else
    print_error "Не удалось назначить IP-адрес на интерфейс $INTERNAL_IF"
    print_info "Текущая конфигурация:"
    ip addr show $INTERNAL_IF
    exit 1
fi

# 2. Настройка NAT через iptables

# Включение IP форвардинга [citation:5][citation:8]
print_info "Включение IP форвардинга..."

# Добавление в /etc/net/sysctl.conf [citation:5]
if grep -q "^net.ipv4.ip_forward" /etc/net/sysctl.conf; then
    sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
else
    echo "net.ipv4.ip_forward = 1" >> /etc/net/sysctl.conf
fi

# Добавление в /etc/sysctl.conf для надежности [citation:5]
if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
    sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/sysctl.conf
else
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
fi

# Применение настроек [citation:5][citation:8]
sysctl -p /etc/sysctl.conf
sysctl -p /etc/net/sysctl.conf 2>/dev/null || true

# Дополнительное включение через sysctl (на всякий случай)
sysctl -w net.ipv4.ip_forward=1

# Проверка включения форвардинга
FORWARD_STATUS=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$FORWARD_STATUS" = "1" ]; then
    print_info "IP форвардинг успешно включен"
else
    print_error "Не удалось включить IP форвардинг"
    exit 1
fi

# Настройка правил iptables для NAT [citation:5][citation:8]
print_info "Настройка правил iptables для NAT..."

# Очистка старых правил NAT (опционально, чтобы не было конфликтов)
iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true

# Основное правило NAT (маскарадинг) [citation:5][citation:8]
iptables -t nat -A POSTROUTING -o $EXTERNAL_IF -s $INTERNAL_NET -j MASQUERADE
print_info "Добавлено правило MASQUERADE для интерфейса $EXTERNAL_IF"

# Правила FORWARD для разрешения прохождения трафика [citation:5]
iptables -A FORWARD -i $INTERNAL_IF -o $EXTERNAL_IF -j ACCEPT
iptables -A FORWARD -i $EXTERNAL_IF -o $INTERNAL_IF -m state --state ESTABLISHED,RELATED -j ACCEPT
print_info "Добавлены правила FORWARD"

# Сохранение правил iptables [citation:5][citation:8]
print_info "Сохранение правил iptables..."

# Создание директории для сохранения правил, если её нет
mkdir -p /etc/sysconfig

# Сохранение правил в файл [citation:5][citation:8]
iptables-save > /etc/sysconfig/iptables
print_info "Правила сохранены в /etc/sysconfig/iptables"

# Настройка автоматического восстановления правил при загрузке через rc.local [citation:5]
print_info "Настройка автоматической загрузки правил iptables..."

# Создание rc.local, если его нет
if [ ! -f /etc/rc.local ]; then
    cat > /etc/rc.local << EOF
#!/bin/bash
# Этот файл будет выполнен при загрузке системы
EOF
    chmod +x /etc/rc.local
fi

# Добавление команды восстановления iptables, если её ещё нет
if ! grep -q "iptables-restore" /etc/rc.local; then
    # Удаляем последнюю строку (exit 0) если она есть, чтобы добавить перед ней
    sed -i '/exit 0/d' /etc/rc.local 2>/dev/null || true
    echo "iptables-restore < /etc/sysconfig/iptables" >> /etc/rc.local
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local
    print_info "Добавлена команда восстановления iptables в /etc/rc.local"
else
    print_info "Команда восстановления iptables уже существует в /etc/rc.local"
fi

# Включение и запуск службы iptables (для систем, где она есть) [citation:5]
if systemctl list-unit-files | grep -q iptables; then
    systemctl enable iptables --now 2>/dev/null || true
    print_info "Служба iptables включена"
fi

# Проверка правил
print_info "======================================"
print_info "Проверка настроек:"

print_info "1. Имя сервера:"
hostname

print_info "2. Сетевые интерфейсы:"
ip -4 addr show | grep -E "^[0-9]+:|inet"

print_info "3. Правила NAT:"
iptables -t nat -L POSTROUTING -v

print_info "4. Правила FORWARD:"
iptables -L FORWARD -v

print_info "5. Статус IP форвардинга:"
sysctl net.ipv4.ip_forward
apt-get update
apt-get install dhcp-server -y
print_info "======================================"
print_info "${GREEN}✅ Настройка успешно завершена!${NC}"
print_info ""
print_info "Итоговая конфигурация:"
print_info "  • Имя сервера: $HOSTNAME"
print_info "  • Внутренний интерфейс: $INTERNAL_IF с IP $INTERNAL_IP"
print_info "  • NAT настроен для сети $INTERNAL_NET через интерфейс $EXTERNAL_IF"
print_info ""
print_info "Для применения имени сервера может потребоваться перезагрузка:"
print_info "  reboot"
print_info ""
print_info "Для проверки с клиента (в сети 192.168.0.0/24):"
print_info "  • Настройте на клиенте IP из этой сети (например, 192.168.0.100/24)"
print_info "  • Установите шлюз по умолчанию: 192.168.0.1"
print_info "  • Проверьте соединение: ping 8.8.8.8"