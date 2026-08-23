#!/bin/bash

UI="/usr/local/lib/joeltom-ui.sh"

if [ -f "$UI" ]; then
    source "$UI"
    k_header "JOELTOM VPN • SETUP_UDP"
else
    clear
fi

export SERVER_HOST="https://raw.githubusercontent.com/joeltom-tech/JOELTOM_VPN/main"
export UDP_DIR="/etc/udp-custom"
export SERVICE_FILE="/etc/systemd/system/udp-custom.service"

RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

update_system() {
    log "Updating system..."

    apt-get update -y || error "Failed to update package lists."

    apt-get upgrade -y || error "Failed to upgrade system."

    apt-get install -y wget || error "Failed to install wget."
}

install_udp_custom() {
    log "Installing UDP Custom..."

    rm -rf "$UDP_DIR"
    mkdir -p "$UDP_DIR"

    if ! wget -q \
        --timeout=30 \
        --tries=3 \
        -O "$UDP_DIR/udp-custom" \
        "${SERVER_HOST}/module/udp-custom-linux-amd64"; then

        error "Failed to download UDP Custom binary."
    fi

    if [ ! -s "$UDP_DIR/udp-custom" ]; then
        error "UDP Custom binary is empty or missing."
    fi

    chmod +x "$UDP_DIR/udp-custom"

    if ! wget -q \
        --timeout=30 \
        --tries=3 \
        -O "$UDP_DIR/config.json" \
        "${SERVER_HOST}/module/udp_config.json"; then

        error "Failed to download UDP Custom configuration."
    fi

    if [ ! -s "$UDP_DIR/config.json" ]; then
        error "UDP Custom configuration is empty."
    fi

    chmod 644 "$UDP_DIR/config.json"

    log "UDP Custom files installed successfully."
}

create_service() {
    local exclude_arg=""

    if [ -n "${1:-}" ]; then
        exclude_arg="-exclude $1"
    fi

    log "Creating UDP Custom systemd service..."

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=UDP Custom by ePro Dev. Team
After=network.target

[Service]
User=root
Type=simple
ExecStart=$UDP_DIR/udp-custom server $exclude_arg
WorkingDirectory=$UDP_DIR
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$SERVICE_FILE"
}

start_service() {
    log "Starting UDP Custom service..."

    systemctl daemon-reload

    systemctl enable udp-custom.service >/dev/null 2>&1 || \
        error "Failed to enable UDP Custom service."

    if ! systemctl restart udp-custom.service; then
        echo ""
        systemctl --no-pager -l status udp-custom.service || true
        error "Failed to start UDP Custom service."
    fi

    sleep 2

    if systemctl is-active --quiet udp-custom.service; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   UDP CUSTOM INSTALLED SUCCESSFULLY   ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
    else
        systemctl --no-pager -l status udp-custom.service || true
        error "UDP Custom service is not running."
    fi
}

main() {
    update_system
    install_udp_custom
    create_service "${1:-}"
    start_service
}

main "$@"