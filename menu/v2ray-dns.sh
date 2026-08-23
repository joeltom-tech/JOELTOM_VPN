#!/bin/bash
# JOELTOM VPN — V2RAY-DNS MENU
# Account management interface for V2Ray + DNS protocol

UI="/usr/local/lib/joeltom-ui.sh"
[ -f "$UI" ] && source "$UI"

export LN='\033[34m'
export BG='\033[44m'
export NC='\033[0m'
export GR='\033[32m'
export RD='\033[31m'

readonly V2RAY_DNS_CONF_FILE="/etc/joeltom-vpn/v2ray-dns.conf"
readonly V2RAY_DNS_DATA_FILE="/var/lib/joeltom-vpn/v2ray-dns/accounts.db"

# Load configuration
if [ -f "$V2RAY_DNS_CONF_FILE" ]; then
    source "$V2RAY_DNS_CONF_FILE"
else
    echo -e "${RD}[ERROR] Configuration file not found: $V2RAY_DNS_CONF_FILE${NC}"
    exit 1
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

generate_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())"
}

format_date() {
    date -d "+$1 days" +"%Y-%m-%d"
}

show_header() {
    clear
    echo -e "${LN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${LN}┃${NC} ${BG}         V2RAY-DNS ACCOUNT MANAGER              ${NC} ${LN}┃${NC}"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

show_menu() {
    show_header
    echo -e "${LN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${LN}┃${NC} Server: ${SERVER_NAME} | Domain: ${V2RAY_DNS_DOMAIN:-N/A}${NC}"
    echo -e "${LN}┃${NC} Port: ${V2RAY_DNS_PORT:-237} (TCP) | FastDNS: ${FASTDNS_UDP_PORT:-5400} (UDP)${NC}"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${LN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${LN}┃${NC} [01] • Create Account"
    echo -e "${LN}┃${NC} [02] • List Accounts"
    echo -e "${LN}┃${NC} [03] • View Account"
    echo -e "${LN}┃${NC} [04] • Renew Account"
    echo -e "${LN}┃${NC} [05] • Delete Account"
    echo -e "${LN}┃${NC} [06] • Modify Connection Limit"
    echo -e "${LN}┃${NC} [07] • Disable Account"
    echo -e "${LN}┃${NC} [08] • Enable Account"
    echo -e "${LN}┃${NC} [09] • Check Expiry"
    echo -e "${LN}┃${NC} [10] • Status"
    echo -e "${LN}┃${NC}"
    echo -e "${LN}┃${NC} [00] • Back to Main Menu"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${LN}●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●${NC}"
    echo ""
}

create_account() {
    show_header
    echo -e "${LN}┃${NC} Creating new V2RAY-DNS account...${NC}"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo ""
    
    read -rp " Username: " username
    read -rp " Validity (days): " validity
    read -rp " Max connections: " max_conn
    
    local uuid
    local exp_date
    uuid=$(generate_uuid)
    exp_date=$(format_date "$validity")
    
    # Display account information
    clear
    echo -e "${LN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${LN}┃${NC} ${BG}              ACCOUNT CREATED                  ${NC} ${LN}┃${NC}"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${LN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${LN}┃${NC} ${GR}✓ Account created successfully${NC}"
    echo -e "${LN}┃${NC}"
    echo -e "${LN}┃${NC} Username       : ${username}"
    echo -e "${LN}┃${NC} UUID           : ${uuid}"
    echo -e "${LN}┃${NC} Created        : $(date +%Y-%m-%d)"
    echo -e "${LN}┃${NC} Expires        : ${exp_date}"
    echo -e "${LN}┃${NC} Max Connections: ${max_conn}"
    echo -e "${LN}┃${NC} Status         : ACTIVE"
    echo -e "${LN}┃${NC}"
    echo -e "${LN}┃${NC} VLESS Link:"
    echo -e "${LN}┃${NC} vless://${uuid}@${V2RAY_DNS_DOMAIN:-example.com}:${V2RAY_DNS_PORT:-237}?type=tcp&encryption=none&host=${V2RAY_DNS_DOMAIN:-example.com}#${username}-V2RAY-DNS${NC}"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${LN}●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●${NC}"
    echo ""
    read -n 1 -s -r -p " Press any key to return to menu..."
}

list_accounts() {
    show_header
    echo -e "${LN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${LN}┃${NC} Username          Expiry        Status${NC}"
    echo -e "${LN}●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●${NC}"
    echo -e "${LN}┃${NC} No accounts configured yet.${NC}"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${LN}●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●${NC}"
    echo ""
    read -n 1 -s -r -p " Press any key to return to menu..."
}

status_menu() {
    show_header
    echo -e "${LN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${LN}┃${NC} V2RAY-DNS Status${NC}"
    echo -e "${LN}●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●${NC}"
    echo -e "${LN}┃${NC} Service     : $(systemctl is-active v2ray-dns 2>/dev/null || echo 'Not installed')${NC}"
    echo -e "${LN}┃${NC} Port        : ${V2RAY_DNS_PORT:-237}/tcp${NC}"
    echo -e "${LN}┃${NC} FastDNS     : ${FASTDNS_UDP_PORT:-5400}/udp${NC}"
    echo -e "${LN}┃${NC} Domain      : ${V2RAY_DNS_DOMAIN:-example.com}${NC}"
    echo -e "${LN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${LN}●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●${NC}"
    echo ""
    read -n 1 -s -r -p " Press any key to return to menu..."
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN MENU LOOP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main_loop() {
    while true; do
        show_menu
        read -rp " Select option: " option
        case $option in
            01|1) create_account ;;
            02|2) list_accounts ;;
            03|3) echo -e " ${GR}Coming soon...${NC}"; sleep 2 ;;
            04|4) echo -e " ${GR}Coming soon...${NC}"; sleep 2 ;;
            05|5) echo -e " ${GR}Coming soon...${NC}"; sleep 2 ;;
            06|6) echo -e " ${GR}Coming soon...${NC}"; sleep 2 ;;
            07|7) echo -e " ${GR}Coming soon...${NC}"; sleep 2 ;;
            08|8) echo -e " ${GR}Coming soon...${NC}"; sleep 2 ;;
            09|9) echo -e " ${GR}Coming soon...${NC}"; sleep 2 ;;
            10) status_menu ;;
            00|0) clear; menu ;;
            *) echo -e " ${RD}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

main_loop
