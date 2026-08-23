#!/bin/bash
set -u
UI="/usr/local/lib/katashie-ui.sh"; [ -f "$UI" ] && source "$UI"
SERVER_HOST="https://raw.githubusercontent.com/joeltom-tech/JOELTOM_VPN/main"
TMP_DIR="$(mktemp -d /tmp/joeltom-update.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

[ -f "$UI" ] && k_header "JOELTOM VPN — OTA UPDATE" || clear
printf '%b\n' "${K_CYAN}  Repository :${K_RESET} $SERVER_HOST"
printf '%b\n' "${K_CYAN}  Mode       :${K_RESET} atomic file replacement (configuration preserved)"
k_sep K_YELLOW

fetch(){ local url="$1" dst="$2"; curl -fsSL --connect-timeout 10 --max-time 120 "$url" -o "$dst"; }
install_group(){
  local group="$1" base="$2"; shift 2
  local f tmp
  for f in "$@"; do
    tmp="$TMP_DIR/$group-$f"
    k_step "Mise à jour $group/$f"; if fetch "$SERVER_HOST/$base/$f.sh" "$tmp"; then chmod +x "$tmp"; install -m 755 "$tmp" "/usr/local/sbin/${f}"; k_done; else printf '%b\n' " ${K_RED}✘${K_RESET}"; k_err "Échec de $f"; return 1; fi
  done
}

CORE=(sshws xray vpn websocket setup_zivpn setup_dns setup_udp validator)
MENU=(dns zivpn expiry domain iptools menu socks ssh status trojan vless vmess netguard port log tgbot uninstall update web fastdns)
MODULE=(config.json nginx.conf proxy3.js runn.service service-wsdropbear ws-stunnel ws-stunnel.service xray.service ssl_renew.sh index badvpn@.service udp_config.json zvpn.json)

# Core sources are refreshed for the next maintenance/reinstall without replacing live protocol configs.
mkdir -p /usr/local/lib/joeltom-core
for f in "${CORE[@]}"; do
  tmp="$TMP_DIR/core-$f"
  k_step "Core/$f"; if fetch "$SERVER_HOST/core/$f.sh" "$tmp"; then chmod +x "$tmp"; install -m 755 "$tmp" "/usr/local/lib/joeltom-core/$f.sh"; k_done; else printf '%b\n' " ${K_RED}✘${K_RESET}"; k_err "Échec de core/$f"; fi
done

for f in "${MENU[@]}"; do
  tmp="$TMP_DIR/menu-$f"
  k_step "Menu/$f"; if fetch "$SERVER_HOST/menu/$f.sh" "$tmp"; then chmod +x "$tmp"; install -m 755 "$tmp" "/usr/local/sbin/$f"; k_done; else printf '%b\n' " ${K_RED}✘${K_RESET}"; k_err "Échec de menu/$f"; fi
done

mkdir -p /usr/local/lib
k_step "UI JOELTOM"; if fetch "$SERVER_HOST/module/joeltom-ui.sh" "$TMP_DIR/ui"; then install -m 644 "$TMP_DIR/ui" /usr/local/lib/joeltom-ui.sh; k_done; else printf '%b\n' " ${K_RED}✘${K_RESET}"; k_err "UI introuvable"; fi

k_step "Version"; if fetch "$SERVER_HOST/version" "$TMP_DIR/version"; then install -m 644 "$TMP_DIR/version" /etc/version; k_done; else printf '%b\n' " ${K_RED}✘${K_RESET}"; fi
k_step "Port information"; if fetch "$SERVER_HOST/port_info" "$TMP_DIR/port_info"; then mkdir -p /etc/xray; install -m 644 "$TMP_DIR/port_info" /etc/xray/port_info; k_done; else printf '%b\n' " ${K_RED}✘${K_RESET}"; fi

# Refresh the launcher itself without forcing a reboot.
k_step "Launcher JOELTOM"; if fetch "$SERVER_HOST/joeltom.sh" "$TMP_DIR/joeltom.sh"; then chmod +x "$TMP_DIR/joeltom.sh"; install -m 755 "$TMP_DIR/joeltom.sh" /root/joeltom.sh; k_done; else printf '%b\n' " ${K_RED}✘${K_RESET}"; fi

# Update the web panel only when it is already installed; data/config stay in /etc/joeltom-vpn-web.
if [ -d /opt/joeltom-vpn-web ] && [ -f /opt/joeltom-vpn-web/install.sh ]; then
  printf '%b\n' "${K_MAGENTA}  Web Panel détecté — mise à jour en conservant la configuration.${K_RESET}"
  JOELTOM_WEB_DIR="/opt/joeltom-vpn-web"; JOELTOM_REPO_URL="https://github.com/joeltom-tech/JOELTOM_VPN.git"; WEB_TMP="$TMP_DIR/repo"
  if git clone --depth 1 "$JOELTOM_REPO_URL" "$WEB_TMP" >/dev/null 2>&1 && [ -d "$WEB_TMP/joeltom-web" ]; then
    cp -rf "$WEB_TMP/katashie-web"/. "$JOELTOM_WEB_DIR/"
    if [ -d "$JOELTOM_WEB_DIR/frontend" ]; then
      cd "$JOELTOM_WEB_DIR/frontend" && npm install --quiet >/dev/null 2>&1 && npm run build >/dev/null 2>&1 || true
    fi
    cd "$JOELTOM_WEB_DIR" && npm install --production=false --quiet >/dev/null 2>&1 && npm run build >/dev/null 2>&1 || true
    systemctl daemon-reload
    systemctl restart joeltom-web 2>/dev/null || true
    k_ok "Web Panel mis à jour."
  else
    k_err "Impossible de récupérer le Web Panel."
  fi
fi

k_sep K_MAGENTA
k_ok "Mise à jour JOELTOM VPN terminée."
printf '%b\n' "${K_DIM}  Les données /etc/joeltom-vpn-web et /etc/xray ne sont pas supprimées.${K_RESET}"
printf '%b\n' "${K_YELLOW}  Un redémarrage n'est pas imposé.${K_RESET}"
sleep 2
