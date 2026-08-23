#!/bin/bash

UI="/usr/local/lib/joeltom-ui.sh"

if [ -f "$UI" ]; then
    source "$UI"
    k_header "JOELTOM VPN • XRAY"
else
    clear
fi

export SERVER_HOST="https://raw.githubusercontent.com/joeltom-tech/JOELTOM_VPN/main"
export DEBIAN_FRONTEND=noninteractive

RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
NC='\033[0m'

log() {
    printf '%b\n' "[INFO] $*"
}

err() {
    printf '%b\n' "${RED}[ERROR] $*${NC}" >&2
    exit 1
}

apt_install() {
    local packages=("$@")

    apt-get update -y
    apt-get install -y "${packages[@]}"
}

crontab_append_root() {
    local entry="$1"

    (
        crontab -l 2>/dev/null | grep -Fv -- "$entry" || true
        echo "$entry"
    ) | crontab -
}

setup_environment() {
    log "Gathering environment information..."

    MYIP=$(wget -qO- \
        --timeout=5 \
        --tries=2 \
        ipv4.icanhazip.com || echo "0.0.0.0")

    mkdir -p /etc/xray

    log "Installing firewall and time utilities..."

    apt_install iptables iptables-persistent curl wget
}

setup_ntp_chrony() {
    log "Configuring date/time and Chrony..."

    apt_install ntpdate chrony

    ntpdate -u pool.ntp.org >/dev/null 2>&1 || true

    if systemctl list-unit-files 2>/dev/null | grep -q '^chrony.service'; then
        systemctl enable --now chrony
        systemctl restart chrony
    elif systemctl list-unit-files 2>/dev/null | grep -q '^chronyd.service'; then
        systemctl enable --now chronyd
        systemctl restart chronyd
    fi

    timedatectl set-timezone Africa/Douala || true
}

install_dependencies() {
    log "Installing build/runtime dependencies..."

    apt_install \
        curl \
        socat \
        xz-utils \
        wget \
        apt-transport-https \
        gnupg \
        gnupg2 \
        dnsutils \
        lsb-release \
        unzip \
        pwgen \
        openssl \
        netcat-openbsd \
        cron \
        bash-completion \
        zip
}

get_domain() {
    local domain=""

    if [ -s /root/domain ]; then
        domain=$(tr -d '[:space:]' < /root/domain)
    elif [ -s /etc/xray/domain ]; then
        domain=$(tr -d '[:space:]' < /etc/xray/domain)
    fi

    if [ -z "$domain" ]; then
        err "Domain file not found. Expected /root/domain or /etc/xray/domain."
    fi

    echo "$domain"
}

install_xray() {
    log "Preparing directories for Xray..."

    local domainSock_dir="/run/xray"

    mkdir -p "$domainSock_dir"
    chown www-data:www-data "$domainSock_dir"

    mkdir -p /var/log/xray /etc/xray

    chown -R www-data:www-data /var/log/xray
    chmod 755 /var/log/xray

    for f in access.log error.log access2.log error2.log; do
        [ -f "/var/log/xray/$f" ] || touch "/var/log/xray/$f"
    done

    chown www-data:www-data /var/log/xray/*.log

    log "Installing official Xray core..."

    if ! bash -c "$(curl -fsSL \
        https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
        -- install -u www-data; then

        err "Failed to install official Xray."
    fi

    log "Replacing official Xray with MOD v25.3.31..."

    local tmpdir="/tmp/xray-mod-install"
    local tmpzip="$tmpdir/Xray_core_mod.zip"

    rm -rf "$tmpdir"
    mkdir -p "$tmpdir"

    if ! curl -fsSL \
        "https://github.com/dotywrt/Xray-core-mod/releases/download/v25.3.31/Xray-linux-64-v25.3.31.zip" \
        -o "$tmpzip"; then

        err "Failed to download Xray MOD v25.3.31."
    fi

    if ! unzip -oq "$tmpzip" -d "$tmpdir"; then
        err "Failed to unzip Xray MOD release."
    fi

    if [ ! -f "$tmpdir/xray" ]; then
        err "Xray binary was not found in MOD archive."
    fi

    mv -f "$tmpdir/xray" /usr/local/bin/xray
    chmod +x /usr/local/bin/xray

    rm -rf "$tmpdir"

    [ -x /usr/local/bin/xray ] || err "Xray binary not installed."

    log "Xray installation completed."
}

install_ssl() {
    local domain
    domain=$(get_domain)

    log "Using domain: $domain"

    log "Stopping services for standalone certificate issuance..."

    systemctl stop nginx 2>/dev/null || true
    systemctl stop xray 2>/dev/null || true

    mkdir -p /root/.acme.sh

    log "Installing ACME client..."

    if ! curl -fsSL \
        --connect-timeout 15 \
        --max-time 120 \
        https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh \
        -o /root/.acme.sh/acme.sh; then

        err "Failed to download acme.sh."
    fi

    chmod +x /root/.acme.sh/acme.sh

    /root/.acme.sh/acme.sh --upgrade --auto-upgrade || true

    /root/.acme.sh/acme.sh \
        --set-default-ca \
        --server letsencrypt || err "Failed to configure Let's Encrypt."

    log "Issuing TLS certificate for $domain..."

    if ! /root/.acme.sh/acme.sh \
        --issue \
        -d "$domain" \
        --standalone \
        -k ec-256; then

        err "Failed to issue TLS certificate for $domain."
    fi

    mkdir -p /etc/xray

    if ! /root/.acme.sh/acme.sh \
        --install-cert \
        -d "$domain" \
        --ecc \
        --fullchain-file /etc/xray/xray.crt \
        --key-file /etc/xray/xray.key; then

        err "Failed to install TLS certificate."
    fi

    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        err "TLS certificate files were not created."
    fi

    chmod 644 /etc/xray/xray.crt
    chmod 600 /etc/xray/xray.key

    log "TLS certificate installed successfully."

    if ! wget -q \
        --timeout=30 \
        --tries=3 \
        -O /usr/local/bin/ssl_renew.sh \
        "${SERVER_HOST}/module/ssl_renew.sh"; then

        err "Failed to download ssl_renew.sh."
    fi

    chmod +x /usr/local/bin/ssl_renew.sh

    crontab_append_root \
        "15 3 * * * /usr/local/bin/ssl_renew.sh >/dev/null 2>&1"
}

configure_xray() {
    log "Fetching Xray configuration and systemd units..."

    mkdir -p /home/vps/public_html
    mkdir -p /etc/xray

    if ! wget -q \
        --timeout=30 \
        --tries=3 \
        -O /etc/xray/config.json \
        "${SERVER_HOST}/module/config.json"; then

        err "Failed to download Xray config.json."
    fi

    [ -s /etc/xray/config.json ] ||
        err "Xray config.json is empty."

    chmod 644 /etc/xray/config.json
    chown root:root /etc/xray/config.json

    if ! wget -q \
        --timeout=30 \
        --tries=3 \
        -O /etc/systemd/system/xray.service \
        "${SERVER_HOST}/module/xray.service"; then

        err "Failed to download xray.service."
    fi

    if ! wget -q \
        --timeout=30 \
        --tries=3 \
        -O /etc/systemd/system/runn.service \
        "${SERVER_HOST}/module/runn.service"; then

        err "Failed to download runn.service."
    fi

    chmod 644 /etc/systemd/system/xray.service
    chmod 644 /etc/systemd/system/runn.service

    rm -rf \
        /etc/systemd/system/xray.service.d \
        /etc/systemd/system/xray@.service

    systemctl daemon-reload
}

configure_nginx() {
    log "Configuring Nginx for Xray..."

    apt_install nginx

    local domain
    domain=$(get_domain)

    if ! wget -q \
        --timeout=30 \
        --tries=3 \
        -O /etc/nginx/nginx.conf \
        "${SERVER_HOST}/module/nginx.conf"; then

        err "Failed to download Nginx configuration."
    fi

    [ -s /etc/nginx/nginx.conf ] ||
        err "Nginx configuration is empty."

    sed -i \
        "s/server_name \*\.xxxxxx;/server_name *.$domain;/g" \
        /etc/nginx/nginx.conf

    sed -i \
        "s/server_name xxxxxx;/server_name $domain;/g" \
        /etc/nginx/nginx.conf

    sed -i \
        "s#https://xxxxxx:86/#https://$domain:86/#g" \
        /etc/nginx/nginx.conf

    chmod 644 /etc/nginx/nginx.conf
    chown root:root /etc/nginx/nginx.conf

    if ! nginx -t; then
        err "Invalid Nginx configuration."
    fi

    systemctl daemon-reload
}

restart_services() {
    log "Enabling and restarting services..."

    systemctl daemon-reload

    systemctl enable xray.service
    systemctl enable nginx.service
    systemctl enable runn.service

    systemctl restart xray.service
    systemctl restart nginx.service
    systemctl restart runn.service

    sleep 2

    if ! systemctl is-active --quiet xray.service; then
        systemctl --no-pager -l status xray.service || true
        err "Xray service failed to start."
    fi

    if ! systemctl is-active --quiet nginx.service; then
        systemctl --no-pager -l status nginx.service || true
        err "Nginx service failed to start."
    fi

    if ! systemctl is-active --quiet runn.service; then
        systemctl --no-pager -l status runn.service || true
        err "runn.service failed to start."
    fi
}

finalize() {
    if [ -f /root/domain ]; then
        mv -f /root/domain /etc/xray/domain
    fi

    rm -f ./xray.sh

    clear
}

main() {
    setup_environment
    setup_ntp_chrony
    install_dependencies
    install_xray
    install_ssl
    configure_xray
    configure_nginx
    restart_services

    log "XRAY Core Installed Successfully."

    sleep 3

    finalize
}

main