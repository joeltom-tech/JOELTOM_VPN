#!/bin/bash
# JOELTOM VPN — V2RAY-DNS PROTOCOL INSTALLATION
# Independent protocol module for V2Ray + DNS + FastDNS
# Version: 1.0.0

set -e

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

readonly SERVER_NAME="JOELTOM"
readonly V2RAY_DNS_CONF_DIR="/etc/joeltom-vpn"
readonly V2RAY_DNS_CONF_FILE="${V2RAY_DNS_CONF_DIR}/v2ray-dns.conf"
readonly V2RAY_DNS_DATA_DIR="/var/lib/joeltom-vpn/v2ray-dns"
readonly V2RAY_DNS_LOG_DIR="/var/log/joeltom-vpn"

# Default values (configurable)
readonly DEFAULT_V2RAY_PORT="237"
readonly DEFAULT_FASTDNS_UDP_PORT="5400"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_warn() { echo "[WARN] $*"; }

check_port_available() {
    local port="$1"
    if netstat -tulpn 2>/dev/null | grep -q ":${port} " || ss -tulpn 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi
    return 0
}

generate_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

init_v2ray_dns_dirs() {
    log_info "Creating V2RAY-DNS directories..."
    mkdir -p "$V2RAY_DNS_CONF_DIR"
    mkdir -p "$V2RAY_DNS_DATA_DIR"
    mkdir -p "$V2RAY_DNS_LOG_DIR"
    chmod 755 "$V2RAY_DNS_CONF_DIR"
    chmod 755 "$V2RAY_DNS_DATA_DIR"
    chmod 755 "$V2RAY_DNS_LOG_DIR"
    log_success "Directories created"
}

create_v2ray_dns_config() {
    log_info "Creating V2RAY-DNS configuration..."
    
    if [[ ! -f "$V2RAY_DNS_CONF_FILE" ]]; then
        cat > "$V2RAY_DNS_CONF_FILE" << 'CONF'
# JOELTOM VPN — V2RAY-DNS PROTOCOL CONFIGURATION
# This configuration file is automatically generated during installation
# Modify values below to customize your V2RAY-DNS protocol

# Server identity (for display purposes)
SERVER_NAME="JOELTOM"

# V2Ray + DNS Protocol Configuration
V2RAY_DNS_DOMAIN="example.com"           # Configure your real domain
V2RAY_DNS_PORT="237"                     # V2Ray + DNS port (MANDATORY)
FASTDNS_UDP_PORT="5400"                  # FastDNS UDP port (MANDATORY)

# DNS Configuration
V2RAY_DNS_NAMESERVER="ns1.example.com"   # DNS NameServer (configurable)

# FastDNS Public Key (required for authentication)
V2RAY_DNS_PUBLIC_KEY="CHANGE_ME"         # Replace with your FastDNS public key

# Encryption settings
V2RAY_DNS_ENCRYPTION="none"              # Encryption method for V2Ray

# Connection limits
V2RAY_DNS_DEFAULT_CONNECTIONS=3          # Default connection limit per account

# Admin settings (Telegram)
V2RAY_DNS_TELEGRAM_ENABLED=0             # Set to 1 to enable Telegram bot
V2RAY_DNS_TELEGRAM_CONFIG="/etc/joeltom-vpn/telegram.conf"  # Telegram config file

# Logging
V2RAY_DNS_LOG_FILE="/var/log/joeltom-vpn/v2ray-dns.log"
V2RAY_DNS_LOG_LEVEL="info"               # Log level: info, warn, error
CONF
        chmod 644 "$V2RAY_DNS_CONF_FILE"
        log_success "Configuration file created at: $V2RAY_DNS_CONF_FILE"
    else
        log_warn "Configuration file already exists at: $V2RAY_DNS_CONF_FILE"
    fi
}

check_v2ray_dns_ports() {
    log_info "Checking if required ports are available..."
    
    if ! check_port_available "$DEFAULT_V2RAY_PORT"; then
        log_error "Port $DEFAULT_V2RAY_PORT (V2Ray + DNS) is already in use"
        return 1
    fi
    
    if ! check_port_available "$DEFAULT_FASTDNS_UDP_PORT"; then
        log_error "Port $DEFAULT_FASTDNS_UDP_PORT (FastDNS UDP) is already in use"
        return 1
    fi
    
    log_success "All required ports are available"
    return 0
}

setup_v2ray_dns_service() {
    log_info "Setting up V2RAY-DNS systemd service..."
    
    cat > /etc/systemd/system/v2ray-dns.service << 'SERVICE'
[Unit]
Description=JOELTOM VPN — V2Ray + DNS Protocol
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/lib/joeltom-vpn/v2ray-dns
ExecStart=/usr/local/sbin/v2raydns-daemon
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
SERVICE
    
    systemctl daemon-reload
    log_success "Service configuration created"
}

install_v2ray_dns_dependencies() {
    log_info "Installing V2RAY-DNS dependencies..."
    
    # V2Ray binary should already be installed by core xray.sh
    if ! command -v xray &> /dev/null; then
        log_error "Xray binary not found. Please install Xray first."
        return 1
    fi
    
    # Check Python for utilities
    if ! command -v python3 &> /dev/null; then
        log_warn "Python3 not found, installing..."
        apt-get update && apt-get install -y python3 python3-pip
    fi
    
    # Install jq for JSON handling (already installed by main script)
    if ! command -v jq &> /dev/null; then
        apt-get install -y jq
    fi
    
    log_success "Dependencies installed"
}

setup_firewall_rules() {
    log_info "Configuring firewall rules for V2RAY-DNS..."
    
    # Check if UFW is enabled
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        log_info "Adding UFW rules..."
        ufw allow "$DEFAULT_V2RAY_PORT/tcp" 2>/dev/null || true
        ufw allow "$DEFAULT_FASTDNS_UDP_PORT/udp" 2>/dev/null || true
    fi
    
    # Check if iptables rules exist for these ports
    if ! iptables -L -n | grep -q ":${DEFAULT_V2RAY_PORT} "; then
        iptables -A INPUT -p tcp --dport "$DEFAULT_V2RAY_PORT" -j ACCEPT
        iptables -A INPUT -p udp --dport "$DEFAULT_FASTDNS_UDP_PORT" -j ACCEPT
    fi
    
    log_success "Firewall rules configured"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN INSTALLATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    log_info "Starting V2RAY-DNS protocol installation..."
    
    init_v2ray_dns_dirs
    create_v2ray_dns_config
    check_v2ray_dns_ports || exit 1
    install_v2ray_dns_dependencies
    setup_v2ray_dns_service
    setup_firewall_rules
    
    log_success "V2RAY-DNS protocol installed successfully!"
    log_info "Configuration file: $V2RAY_DNS_CONF_FILE"
    log_info "Data directory: $V2RAY_DNS_DATA_DIR"
    log_info "Edit configuration and run: systemctl enable v2ray-dns"
}

main "$@"
