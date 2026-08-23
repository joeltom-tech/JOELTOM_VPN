#!/bin/bash

UI="/usr/local/lib/joeltom-ui.sh"

if [ -f "$UI" ]; then
    source "$UI"
    k_header "JOELTOM VPN • SSHWS"
else
    clear
fi

export DEBIAN_FRONTEND=noninteractive
export SERVER_HOST="https://raw.githubusercontent.com/joeltom-tech/JOELTOM_VPN/main"

setup_variables() {
    MYIP=$(wget -qO- --timeout=10 ipv4.icanhazip.com || true)
    NET=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -n1)

    if [ -f /etc/os-release ]; then
        source /etc/os-release
        ver="${VERSION_ID:-unknown}"
    else
        ver="unknown"
    fi
}

set_simple_password() {
    echo "[INFO] Configuring password policy..."

    if ! curl -fsSL "${SERVER_HOST}/module/password" | \
        openssl aes-256-cbc -d -a -pass pass:scvps07gg -pbkdf2 \
        > /etc/pam.d/common-password; then

        echo "[ERROR] Failed to download/decrypt password configuration."
        return 1
    fi

    chmod 644 /etc/pam.d/common-password
}

setup_rc_local() {
    cat > /etc/systemd/system/rc-local.service <<'END'
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
END

    cat > /etc/rc.local <<'END'
#!/bin/bash
exit 0
END

    chmod +x /etc/rc.local

    systemctl daemon-reload
    systemctl enable rc-local.service >/dev/null 2>&1 || true
    systemctl start rc-local.service >/dev/null 2>&1 || true
}

disable_ipv6() {
    echo "[INFO] Disabling IPv6..."

    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true

    if ! grep -q "^net.ipv6.conf.all.disable_ipv6=1" /etc/sysctl.conf; then
        echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
    fi

    if ! grep -q "^net.ipv6.conf.default.disable_ipv6=1" /etc/sysctl.conf; then
        echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
    fi

    if [ -f /etc/rc.local ]; then
        if ! grep -q "ipv6/conf/all/disable_ipv6" /etc/rc.local; then
            sed -i '/^exit 0$/i echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
        fi
    fi
}

configure_nginx() {
    echo "[INFO] Installing Nginx..."

    apt-get update -y
    apt-get install -y nginx

    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-available/default
    rm -f /etc/nginx/conf.d/default.conf

    if ! wget -q --timeout=30 --tries=3 \
        -O /etc/nginx/nginx.conf \
        "${SERVER_HOST}/module/nginx.conf"; then

        echo "[ERROR] Failed to download nginx.conf."
        return 1
    fi

    if [ ! -s /etc/nginx/nginx.conf ]; then
        echo "[ERROR] nginx.conf is empty."
        return 1
    fi

    if [[ ! -s /etc/xray/xray.crt || ! -s /etc/xray/xray.key ]]; then
        echo "[ERROR] Xray certificate missing:"
        echo "        /etc/xray/xray.crt"
        echo "        /etc/xray/xray.key"
        return 1
    fi

    domain=$(cat /etc/xray/domain 2>/dev/null || true)

    if [[ -z "$domain" ]]; then
        echo "[ERROR] Domain not found in /etc/xray/domain."
        return 1
    fi

    sed -i "s/server_name \*\.xxxxxx;/server_name *.$domain;/g" \
        /etc/nginx/nginx.conf

    sed -i "s/server_name xxxxxx;/server_name $domain;/g" \
        /etc/nginx/nginx.conf

    sed -i "s#https://xxxxxx:86/#https://$domain:86/#g" \
        /etc/nginx/nginx.conf

    if ! nginx -t; then
        echo "[ERROR] Invalid Nginx configuration."
        return 1
    fi

    mkdir -p /etc/systemd/system/nginx.service.d

    printf '%s\n' \
        "[Service]" \
        "ExecStartPost=/bin/sleep 0.1" \
        > /etc/systemd/system/nginx.service.d/override.conf

    systemctl daemon-reload
    systemctl enable nginx
    systemctl restart nginx

    echo "[OK] Nginx configured."
}

setup_web_directories() {
    echo "[INFO] Setting up web directory..."

    mkdir -p /home/vps/public_html

    if ! wget -q --timeout=30 --tries=3 \
        -O /home/vps/public_html/index.html \
        "${SERVER_HOST}/module/index"; then

        echo "[ERROR] Failed to download index.html."
        return 1
    fi

    chown -R www-data:www-data /home/vps/public_html
}

install_badvpn() {
    echo "[INFO] Installing BadVPN..."

    if ! wget -q --timeout=30 --tries=3 \
        -O /usr/bin/badvpn-udpgw \
        "${SERVER_HOST}/module/newudpgw"; then

        echo "[ERROR] Failed to download BadVPN."
        return 1
    fi

    chmod +x /usr/bin/badvpn-udpgw

    if ! wget -q --timeout=30 --tries=3 \
        -O /etc/systemd/system/badvpn@.service \
        "${SERVER_HOST}/module/badvpn@.service"; then

        echo "[ERROR] Failed to download BadVPN service."
        return 1
    fi

    systemctl daemon-reload

    systemctl enable --now badvpn@7100
    systemctl enable --now badvpn@7200
    systemctl enable --now badvpn@7300

    echo "BadVPN installed and started on ports 7100-7300."
}

configure_ssh_dropbear() {
    echo "[INFO] Configuring SSH and Dropbear..."

    apt-get update -y
    apt-get install -y dropbear

    if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' \
            /etc/ssh/sshd_config
    else
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    fi

    for port in 500 40000 81 51443 58080 666; do
        if ! grep -q "^Port $port$" /etc/ssh/sshd_config; then
            echo "Port $port" >> /etc/ssh/sshd_config
        fi
    done

    if sshd -t; then
        systemctl restart ssh
    else
        echo "[ERROR] Invalid SSH configuration."
        return 1
    fi

    if [ -f /etc/default/dropbear ]; then
        sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear

        if grep -q "^DROPBEAR_PORT=" /etc/default/dropbear; then
            sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=143/' \
                /etc/default/dropbear
        else
            echo "DROPBEAR_PORT=143" >> /etc/default/dropbear
        fi

        if grep -q "^DROPBEAR_EXTRA_ARGS=" /etc/default/dropbear; then
            sed -i \
                's#^DROPBEAR_EXTRA_ARGS=.*#DROPBEAR_EXTRA_ARGS="-p 50000 -p 109 -p 110 -p 69"#' \
                /etc/default/dropbear
        else
            echo 'DROPBEAR_EXTRA_ARGS="-p 50000 -p 109 -p 110 -p 69"' \
                >> /etc/default/dropbear
        fi
    fi

    grep -qxF "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells
    grep -qxF "/usr/sbin/nologin" /etc/shells || echo "/usr/sbin/nologin" >> /etc/shells

    systemctl daemon-reload
    systemctl enable --now dropbear
}

configure_stunnel() {
    STUNNEL_VERSION="5.75"
    STUNNEL_URL="https://www.stunnel.org/downloads/stunnel-${STUNNEL_VERSION}.tar.gz"
    INSTALL_DIR="/usr/local/bin"
    ETC_DIR="/etc/stunnel5"
    CONF_FILE="$ETC_DIR/stunnel5.conf"
    PEM_FILE="$ETC_DIR/stunnel5.pem"
    SYSTEMD_UNIT="/etc/systemd/system/stunnel5.service"

    echo "[INFO] Installing stunnel dependencies..."

    apt-get update -y
    apt-get install -y \
        build-essential \
        libssl-dev \
        libwrap0-dev \
        zlib1g-dev \
        unzip \
        wget \
        openssl

    cd /root || return 1

    rm -rf "stunnel-${STUNNEL_VERSION}"
    rm -f "stunnel-${STUNNEL_VERSION}.tar.gz"

    echo "[INFO] Downloading stunnel ${STUNNEL_VERSION}..."

    if ! wget -q --timeout=30 --tries=3 \
        -O "stunnel-${STUNNEL_VERSION}.tar.gz" \
        "$STUNNEL_URL"; then

        echo "[ERROR] Failed to download stunnel."
        return 1
    fi

    tar xzf "stunnel-${STUNNEL_VERSION}.tar.gz" || return 1

    cd "stunnel-${STUNNEL_VERSION}" || return 1

    ./configure --prefix=/usr/local || return 1
    make -j"$(nproc)" || return 1
    make install || return 1

    cp /usr/local/bin/stunnel "$INSTALL_DIR/stunnel5"
    chmod 755 "$INSTALL_DIR/stunnel5"

    echo "[INFO] Setting up certificates..."

    rm -rf "$ETC_DIR"
    mkdir -p "$ETC_DIR"

    if [[ -f /etc/xray/xray.crt && -f /etc/xray/xray.key ]]; then
        echo "[INFO] Using existing Xray certificates."

        cat /etc/xray/xray.key \
            /etc/xray/xray.crt \
            > "$PEM_FILE"
    else
        echo "[INFO] Generating self-signed certificate..."

        openssl req -new -x509 -days 1095 -nodes \
            -subj "/C=CM/ST=Centre/L=Yaounde/O=JOELTOMVPN/OU=stunnel/CN=$(hostname -f)/emailAddress=admin@localhost" \
            -out "$ETC_DIR/stunnel.crt" \
            -keyout "$ETC_DIR/stunnel.key"

        cat "$ETC_DIR/stunnel.key" \
            "$ETC_DIR/stunnel.crt" \
            > "$PEM_FILE"
    fi

    chmod 600 "$PEM_FILE"

    echo "[INFO] Writing stunnel configuration..."

    cat > "$CONF_FILE" <<EOF
cert = $PEM_FILE
client = no
foreground = yes
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear-447]
accept = 447
connect = 127.0.0.1:109

[openssh-777]
accept = 777
connect = 127.0.0.1:22

[openvpn-442]
accept = 442
connect = 127.0.0.1:1194

[openssh-8181]
accept = 8181
connect = 127.0.0.1:22
EOF

    echo "[INFO] Creating systemd service..."

    cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=Stunnel5 Service
Documentation=https://stunnel.org
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/stunnel5 $CONF_FILE
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable stunnel5.service
    systemctl restart stunnel5.service

    rm -rf "/root/stunnel-${STUNNEL_VERSION}"
    rm -f "/root/stunnel-${STUNNEL_VERSION}.tar.gz"

    echo "[OK] Stunnel5 installed."
}

install_ddos_deflate() {
    echo "[INFO] Installing DDOS Deflate..."

    apt-get install -y cron

    if [ -d "/usr/local/ddos" ]; then
        echo "Previous DDOS Deflate installation already exists."
        return 0
    fi

    mkdir -p /usr/local/ddos

    wget -q -O /usr/local/ddos/ddos.conf \
        http://www.inetbase.com/scripts/ddos/ddos.conf

    wget -q -O /usr/local/ddos/LICENSE \
        http://www.inetbase.com/scripts/ddos/LICENSE

    wget -q -O /usr/local/ddos/ignore.ip.list \
        http://www.inetbase.com/scripts/ddos/ignore.ip.list

    wget -q -O /usr/local/ddos/ddos.sh \
        http://www.inetbase.com/scripts/ddos/ddos.sh

    chmod 0755 /usr/local/ddos/ddos.sh

    ln -sf /usr/local/ddos/ddos.sh /usr/local/sbin/ddos

    /usr/local/ddos/ddos.sh --cron >/dev/null 2>&1 || true
}

setup_firewall() {
    echo "[INFO] Configuring firewall..."

    apt-get install -y iptables-persistent

    for t in \
        "get_peers" \
        "announce_peer" \
        "find_node" \
        "BitTorrent" \
        "BitTorrent protocol" \
        "peer_id=" \
        ".torrent" \
        "announce.php?passkey=" \
        "torrent" \
        "announce" \
        "info_hash"
    do
        iptables -A FORWARD \
            -m string \
            --string "$t" \
            --algo bm \
            -j DROP || true
    done

    iptables-save > /etc/iptables.up.rules
    iptables-restore -t < /etc/iptables.up.rules || true

    netfilter-persistent save || true
    netfilter-persistent reload || true
}

setup_cronjobs() {
    echo "[INFO] Configuring cron jobs..."

    cat > /etc/cron.d/re_otm <<'END'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 2 * * * root /sbin/reboot
END

    cat > /etc/cron.d/xp_otm <<'END'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/bin/xp
END

    echo "7" > /home/re_otm

    chmod 644 /etc/cron.d/re_otm
    chmod 644 /etc/cron.d/xp_otm

    systemctl restart cron || true
}

cleanup_system() {
    echo "[INFO] Cleaning system..."

    apt-get autoclean -y >/dev/null 2>&1 || true

    apt-get -y --purge remove \
        samba* \
        apache2* \
        bind9* \
        sendmail* \
        >/dev/null 2>&1 || true

    apt-get autoremove -y >/dev/null 2>&1 || true

    history -c 2>/dev/null || true

    if ! grep -q "^unset HISTFILE$" /etc/profile; then
        echo "unset HISTFILE" >> /etc/profile
    fi

    rm -f /root/*.pem
    rm -f /root/ssh.sh
    rm -f /root/bbr.sh
}

restart_services() {
    echo "[INFO] Restarting services..."

    systemctl restart nginx 2>/dev/null || true
    systemctl restart ssh 2>/dev/null || true
    systemctl restart dropbear 2>/dev/null || true
    systemctl restart fail2ban 2>/dev/null || true
    systemctl restart vnstat 2>/dev/null || true
    systemctl restart cron 2>/dev/null || true
}

update_banner() {
    echo "[INFO] Updating SSH banner..."

    if wget -q --timeout=30 --tries=3 \
        -O /etc/issue.net \
        "${SERVER_HOST}/module/issue.net"; then

        if ! grep -q "^Banner /etc/issue.net$" /etc/ssh/sshd_config; then
            echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
        fi
    fi

    if [ -f /etc/default/dropbear ]; then
        if grep -q "^DROPBEAR_BANNER=" /etc/default/dropbear; then
            sed -i \
                's#^DROPBEAR_BANNER=.*#DROPBEAR_BANNER="/etc/issue.net"#' \
                /etc/default/dropbear
        else
            echo 'DROPBEAR_BANNER="/etc/issue.net"' \
                >> /etc/default/dropbear
        fi
    fi
}

install_depsws() {
    echo "[INFO] Installing WebSocket dependencies..."

    apt-get update -y
    apt-get install -y wget curl python3
}

install_ws_scripts() {
    echo "[INFO] Downloading WebSocket scripts..."

    if ! wget -q --timeout=30 --tries=3 \
        -O /usr/local/bin/ws-dropbear \
        "${SERVER_HOST}/module/dropbear-ws.py"; then

        echo "[ERROR] Failed to download ws-dropbear."
        return 1
    fi

    if ! wget -q --timeout=30 --tries=3 \
        -O /usr/local/bin/ws-stunnel \
        "${SERVER_HOST}/module/ws-stunnel"; then

        echo "[ERROR] Failed to download ws-stunnel."
        return 1
    fi

    chmod +x /usr/local/bin/ws-dropbear
    chmod +x /usr/local/bin/ws-stunnel
}

install_ws_services() {
    echo "[INFO] Setting up WebSocket services..."

    if ! wget -q --timeout=30 --tries=3 \
        -O /etc/systemd/system/ws-dropbear.service \
        "${SERVER_HOST}/module/service-wsdropbear"; then

        echo "[ERROR] Failed to download ws-dropbear.service."
        return 1
    fi

    if ! wget -q --timeout=30 --tries=3 \
        -O /etc/systemd/system/ws-stunnel.service \
        "${SERVER_HOST}/module/ws-stunnel.service"; then

        echo "[ERROR] Failed to download ws-stunnel.service."
        return 1
    fi

    chmod 644 /etc/systemd/system/ws-dropbear.service
    chmod 644 /etc/systemd/system/ws-stunnel.service

    systemctl daemon-reload
}

enable_start_ws_services() {
    echo "[INFO] Enabling and starting WebSocket services..."

    for service in ws-dropbear ws-stunnel; do
        systemctl enable "${service}.service"
        systemctl restart "${service}.service"

        if systemctl is-active --quiet "${service}.service"; then
            echo "[OK] ${service} is running."
        else
            echo "[WARNING] ${service} failed to start."
            systemctl --no-pager -l status "${service}.service" || true
        fi
    done
}

mainws() {
    install_depsws
    install_ws_scripts
    install_ws_services
    enable_start_ws_services

    echo ""
    echo "[*] SSH WebSocket Installed Successfully!"
    echo "[*] Loading..."

    sleep 3
    clear
}

main() {
    setup_variables

    set_simple_password
    setup_rc_local
    disable_ipv6

    configure_nginx
    setup_web_directories

    install_badvpn
    configure_ssh_dropbear
    configure_stunnel

    install_ddos_deflate
    setup_firewall
    setup_cronjobs

    cleanup_system
    update_banner
    restart_services

    echo ""
    echo "[*] SSH Tunnel Installed Successfully."
    echo "[*] Loading..."

    sleep 5
    clear

    mainws
}

main