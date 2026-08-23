#!/bin/bash

UI="/usr/local/lib/joeltom-ui.sh"

if [ -f "$UI" ]; then
    source "$UI"
    k_header "JOELTOM VPN • SETUP_ZIVPN"
else
    clear
fi

RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
NC='\033[0m'

export SERVER_HOST="https://raw.githubusercontent.com/joeltom-tech/JOELTOM_VPN/main"

update_system() {
    echo -e "${BLUE}Updating server...${NC}"

    apt-get update -y && apt-get upgrade -y
}

stop_service() {
    echo -e "${BLUE}Stopping existing ZIVPN service...${NC}"

    if systemctl is-active --quiet zivpn.service; then
        systemctl stop zivpn.service
    fi
}

download_udp_service() {
    echo -e "${BLUE}Downloading ZIVPN UDP service...${NC}"

    mkdir -p /etc/zivpn

    if ! wget -q --timeout=30 --tries=3 \
        "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64" \
        -O /usr/local/bin/zivpn; then

        echo -e "${RED}[ERROR] Failed to download ZIVPN.${NC}"
        return 1
    fi

    chmod +x /usr/local/bin/zivpn

    touch /etc/zivpn/user.db

    if ! wget -q --timeout=30 --tries=3 \
        -O /etc/zivpn/config.json \
        "${SERVER_HOST}/module/zvpn.json"; then

        echo -e "${RED}[ERROR] Failed to download ZIVPN configuration.${NC}"
        return 1
    fi

    if [ ! -s /etc/zivpn/config.json ]; then
        echo -e "${RED}[ERROR] ZIVPN configuration is empty.${NC}"
        return 1
    fi
}

generate_certificates() {
    echo -e "${BLUE}Generating certificate files...${NC}"

    mkdir -p /etc/zivpn

    if ! openssl req \
        -new \
        -newkey rsa:4096 \
        -days 365 \
        -nodes \
        -x509 \
        -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" \
        -keyout "/etc/zivpn/zivpn.key" \
        -out "/etc/zivpn/zivpn.crt"; then

        echo -e "${RED}[ERROR] Failed to generate ZIVPN certificates.${NC}"
        return 1
    fi

    chmod 600 /etc/zivpn/zivpn.key
    chmod 644 /etc/zivpn/zivpn.crt

    sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1 || true
    sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1 || true

    if ! grep -q "^net.core.rmem_max=16777216$" /etc/sysctl.conf; then
        echo "net.core.rmem_max=16777216" >> /etc/sysctl.conf
    fi

    if ! grep -q "^net.core.wmem_max=16777216$" /etc/sysctl.conf; then
        echo "net.core.wmem_max=16777216" >> /etc/sysctl.conf
    fi
}

create_systemd_service() {
    echo -e "${BLUE}Creating systemd service...${NC}"

    cat > /etc/systemd/system/zivpn.service <<'EOF'
[Unit]
Description=ZIVPN UDP VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

enable_and_start_service() {
    echo -e "${BLUE}Enabling and starting ZIVPN service...${NC}"

    systemctl daemon-reload

    systemctl enable zivpn.service

    if ! systemctl restart zivpn.service; then
        echo -e "${RED}[ERROR] Failed to start ZIVPN service.${NC}"
        systemctl --no-pager -l status zivpn.service || true
        return 1
    fi

    sleep 2

    if systemctl is-active --quiet zivpn.service; then
        echo -e "${GREEN}[OK] ZIVPN service is running.${NC}"
    else
        echo -e "${RED}[ERROR] ZIVPN service is not running.${NC}"
        systemctl --no-pager -l status zivpn.service || true
        return 1
    fi
}

configure_firewall() {
    echo -e "${BLUE}Configuring firewall rules...${NC}"

    local iface

    iface=$(ip -4 route show default 2>/dev/null | awk '/default/ {print $5; exit}')

    if [ -z "$iface" ]; then
        echo -e "${RED}[ERROR] Unable to detect network interface.${NC}"
        return 1
    fi

    if ! iptables -t nat -C PREROUTING \
        -i "$iface" \
        -p udp \
        --dport 6000:19999 \
        -j DNAT \
        --to-destination :5667 \
        2>/dev/null; then

        iptables -t nat -A PREROUTING \
            -i "$iface" \
            -p udp \
            --dport 6000:19999 \
            -j DNAT \
            --to-destination :5667
    fi

    echo -e "${GREEN}[OK] Firewall configured on interface ${iface}.${NC}"
}

touchfile() {
    mkdir -p /etc/zivpn
    touch /etc/zivpn/user.db
    chmod 600 /etc/zivpn/user.db
}

cleanup() {
    rm -f setup_zivpn.* >/dev/null 2>&1 || true
}

main() {
    update_system || exit 1
    stop_service || exit 1
    download_udp_service || exit 1
    generate_certificates || exit 1
    create_systemd_service || exit 1
    enable_and_start_service || exit 1
    configure_firewall || exit 1
    touchfile
    cleanup

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   ZIVPN UDP INSTALLED SUCCESSFULLY!   ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}ZIVPN Port : 5667${NC}"
    echo -e "${BLUE}UDP Range  : 6000-19999${NC}"
    echo ""
}

main