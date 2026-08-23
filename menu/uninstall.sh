#!/bin/bash
UI="/usr/local/lib/joeltom-ui.sh"; [ -f "$UI" ] && source "$UI"
[ -f "$UI" ] && k_header "JOELTOM VPN • UNINSTALL" || clear
printf '%b\n' "${K_RED}╭────────────────────────────────────────────────────────────────╮"
printf '%b\n' "│  DÉSINSTALLATION COMPLÈTE — JOELTOM VPN                     │"
printf '%b\n' "╰────────────────────────────────────────────────────────────────╯${K_RESET}"
printf '%b\n' "${K_YELLOW}⚠ Cette opération supprime les composants installés par KATASHIE.${K_RESET}"
printf '%b\n' "${K_YELLOW}⚠ Elle ne supprime pas OpenSSH ni les fichiers personnels non liés.${K_RESET}"
printf '%b\n' "${K_YELLOW}⚠ Les comptes VPN et données JOELTOM seront perdus.${K_RESET}"
read -r -p " Confirmer la purge complète ? (y/N) : " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { k_info "Désinstallation annulée."; exit 0; }

mkdir -p /var/log/joeltom
exec > >(tee -a /var/log/joeltom/uninstall.log) 2>&1

stop_disable(){
  local s
  for s in "$@"; do systemctl stop "$s" 2>/dev/null || true; systemctl disable "$s" 2>/dev/null || true; done
}

k_spinner "Arrêt des services JOELTOM" 8
stop_disable xray zivpn joeltom_bot joeltom-web dropbear stunnel5 ws-dropbear ws-stunnel sshws sshwsssl hysteria-server tuic-server dnstt udp-custom ohp squid nginx

pkill -f '/usr/local/sbin/proxy3.js' 2>/dev/null || true
pkill -f 'proxy3.js' 2>/dev/null || true
tmux kill-session -t sshws 2>/dev/null || true
tmux kill-session -t sshwsssl 2>/dev/null || true

k_spinner "Suppression des unités systemd et tâches automatiques" 8
rm -f /etc/systemd/system/katashie* /etc/systemd/system/xray* /etc/systemd/system/tuic-server.service /etc/systemd/system/hysteria-server.service /etc/systemd/system/dnstt.service
rm -f /etc/systemd/system/ws-dropbear.service /etc/systemd/system/ws-stunnel.service /etc/systemd/system/stunnel5.service /etc/systemd/system/udp-custom.service
rm -f /etc/cron.d/joeltom* /etc/cron.d/joeltom-web-watchdog
rm -f /usr/local/bin/katashie-web-watchdog.sh /usr/local/sbin/joeltom* /usr/local/sbin/proxy3.js
systemctl daemon-reload
systemctl reset-failed

k_spinner "Suppression des données JOELTOM" 8
rm -rf /etc/joeltom /etc/joeltom_bot /etc/joeltom-vpn-web /etc/xray /etc/zivpn /etc/slowdns /etc/tuic /etc/hysteria
rm -rf /opt/joeltom /opt/JOELTOM /opt/joeltom-vpn-web /root/joeltom_core_bot /root/joeltom_bot_engine
rm -f /root/joeltom.sh /root/domain
rm -rf /root/.acme.sh
rm -f /etc/systemd/system/multi-user.target.wants/joeltom_bot.service

k_spinner "Nettoyage Nginx / certificats joeltom" 8
rm -f /etc/nginx/sites-enabled/joeltom /etc/nginx/sites-available/joeltom
rm -f /etc/nginx/conf.d/joeltom.conf
rm -rf /etc/letsencrypt
nginx -t >/dev/null 2>&1 || true

k_spinner "Nettoyage des fichiers temporaires" 6
rm -f /tmp/joeltom-* /tmp/JOELTOM-* /tmp/joeltom-update.*
rm -rf /usr/local/lib/joeltom-core /usr/local/lib/joeltom-ui.sh

k_ok "Désinstallation JOELTOM VPN terminée."
printf '%b\n' "${K_GREEN}Ports 80/443 restitués aux services restants du VPS.${K_RESET}"
printf '%b\n' "${K_CYAN}Journal de cette purge : /var/log/joeltom/uninstall.log${K_RESET}"
rm -f /usr/local/sbin/menu /usr/local/sbin/update /usr/local/sbin/uninstall
exit 0
