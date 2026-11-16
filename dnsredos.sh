#!/bin/bash
set -e

# === ПАРАМЕТРЫ СЕТИ (измените под свою инфраструктуру) ===
SERVER_IP="192.168.0.1"          # IP-адрес этого DNS-сервера
SUBNET_CIDR="192.168.0.0/24"     # Разрешённая подсеть для запросов
REVERSE_ZONE="0.168.192"         # Первые 3 октета IP в обратном порядке
DOMAIN="corp.local"              # Имя локального домена
FORWARDERS="77.88.8.8; 8.8.8.8;" # Вышестоящие DNS (Яндекс / Google)
HOST_OCTET="1"                   # Последний октет IP сервера

# 1. Проверка запуска от root
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: запустите скрипт с правами root (sudo ./setup_dns.sh)"
  exit 1
fi

echo "[1/6] Установка пакетов bind и bind-utils..."
dnf install -y bind bind-utils

echo "[2/6] Резервное копирование исходного /etc/named.conf..."
cp -n /etc/named.conf /etc/named.conf.bak

echo "[3/6] Формирование конфигурации /etc/named.conf..."
cat <<EOF > /etc/named.conf
options {
    listen-on port 53 { 127.0.0.1; ${SERVER_IP}; };
    listen-on-v6 port 53 { none; };
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    secroots-file   "/var/named/data/named.secroots";
    recursing-file  "/var/named/data/named.recursing";

    allow-query     { localhost; ${SUBNET_CIDR}; };
    allow-recursion { localhost; ${SUBNET_CIDR}; };

    forward first;
    forwarders { ${FORWARDERS} };

    dnssec-validation no;

    managed-keys-directory "/var/named/dynamic";
    geoip-directory "/usr/share/GeoIP";

    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";
    include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

zone "." IN {
    type hint;
    file "named.ca";
};

zone "${DOMAIN}" IN {
    type master;
    file "master/${DOMAIN}.zone";
    allow-update { none; };
};

zone "${REVERSE_ZONE}.in-addr.arpa" IN {
    type master;
    file "master/${REVERSE_ZONE}.zone";
    allow-update { none; };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF

echo "[4/6] Создание файлов прямой и обратной зон..."
mkdir -p /var/named/master

# Прямая зона
cat <<EOF > /var/named/master/${DOMAIN}.zone
\$TTL 86400
@   IN  SOA ns1.${DOMAIN}. admin.${DOMAIN}. (
        $(date +%Y%m%d)01 ; Serial
        3600           ; Refresh
        1800           ; Retry
        604800         ; Expire
        86400 )        ; Minimum TTL

@       IN  NS  ns1.${DOMAIN}.
ns1     IN  A   ${SERVER_IP}
server  IN  A   ${SERVER_IP}
EOF

# Обратная зона
cat <<EOF > /var/named/master/${REVERSE_ZONE}.zone
\$TTL 86400
@   IN  SOA ns1.${DOMAIN}. admin.${DOMAIN}. (
        $(date +%Y%m%d)01 ; Serial
        3600           ; Refresh
        1800           ; Retry
        604800         ; Expire
        86400 )        ; Minimum TTL

@           IN  NS  ns1.${DOMAIN}.
${HOST_OCTET}           IN  PTR ns1.${DOMAIN}.
EOF

chown -R root:named /var/named/master
chmod 640 /var/named/master/*

echo "[5/6] Проверка синтаксиса конфигурации и зон..."
named-checkconf /etc/named.conf
named-checkzone ${DOMAIN} /var/named/master/${DOMAIN}.zone
named-checkzone ${REVERSE_ZONE}.in-addr.arpa /var/named/master/${REVERSE_ZONE}.zone

echo "[6/6] Настройка межсетевого экрана и запуск службы named..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=dns
    firewall-cmd --reload
fi

systemctl enable --now named
systemctl restart named

echo "Готово! DNS-сервер запущен на ${SERVER_IP}."
echo "Проверка прямой зоны: dig @${SERVER_IP} ns1.${DOMAIN} +short"
echo "Проверка обратной зоны: dig @${SERVER_IP} -x ${SERVER_IP} +short"
