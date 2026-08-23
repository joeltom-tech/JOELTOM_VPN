# JOELTOM VPN — V2RAY-DNS PROTOCOL

## Overview

V2RAY-DNS is an independent protocol module for JOELTOM VPN that provides:

- **V2Ray + DNS** on port **237** (TCP)
- **FastDNS UDP** on port **5400**
- Individual account management with unique UUIDs
- Per-account connection limits
- Account expiration and renewal
- Optional Telegram bot administration

## Architecture

```
V2RAY-DNS Protocol
├── V2Ray + DNS (Port 237/TCP)
│   ├── VLESS protocol
│   ├── Unique UUID per account
│   └── Configurable domain
├── FastDNS UDP (Port 5400/UDP)
│   ├── DNS tunneling
│   ├── Public key authentication
│   └── NameServer configuration
└── Account Management
    ├── Database storage
    ├── Expiration tracking
    ├── Connection limiting
    └── Telegram administration
```

## Configuration

Main configuration file:
```bash
/etc/joeltom-vpn/v2ray-dns.conf
```

### Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `SERVER_NAME` | JOELTOM | Display name |
| `V2RAY_DNS_DOMAIN` | example.com | Your actual domain |
| `V2RAY_DNS_PORT` | 237 | V2Ray + DNS port |
| `FASTDNS_UDP_PORT` | 5400 | FastDNS UDP port |
| `V2RAY_DNS_NAMESERVER` | ns1.example.com | DNS NameServer |
| `V2RAY_DNS_PUBLIC_KEY` | CHANGE_ME | FastDNS public key |
| `V2RAY_DNS_DEFAULT_CONNECTIONS` | 3 | Default connection limit |

## Installation

### Automatic Installation

The V2RAY-DNS protocol is installed during the main JOELTOM VPN installation:

```bash
curl -fsSL https://raw.githubusercontent.com/joeltom-tech/JOELTOM_VPN/main/autoinstall.sh | sudo bash
```

### Manual Installation

```bash
bash core/setup_v2ray_dns.sh
```

## Usage

### Access the Menu

```bash
menu
# Then select option [25] V2RAY-DNS
```

### Create an Account

```
Menu Option: [01] Create Account
- Enter username
- Enter validity (days)
- Enter max connections
```

### View VLESS Link

Format:
```
vless://UUID@DOMAIN:237?type=tcp&encryption=none&host=DOMAIN#USERNAME-V2RAY-DNS
```

Example:
```
vless://101e3c06-bfe8-4571-9a4e-36b06f5bb057@example.com:237?type=tcp&encryption=none&host=example.com#testuser-V2RAY-DNS
```

## Account Management

### Create Account
```bash
menu → [25] V2RAY-DNS → [01] Create Account
```

### List Accounts
```bash
menu → [25] V2RAY-DNS → [02] List Accounts
```

### View Account Details
```bash
menu → [25] V2RAY-DNS → [03] View Account
```

### Renew Account
```bash
menu → [25] V2RAY-DNS → [04] Renew Account
# Extend expiry date
```

### Delete Account
```bash
menu → [25] V2RAY-DNS → [05] Delete Account
```

### Modify Connection Limit
```bash
menu → [25] V2RAY-DNS → [06] Modify Connection Limit
# Change max connections for a user
```

### Disable/Enable Account
```bash
menu → [25] V2RAY-DNS → [07] Disable Account
menu → [25] V2RAY-DNS → [08] Enable Account
```

## Telegram Administration

### Enable Telegram Bot

1. Create configuration file:
```bash
sudo nano /etc/joeltom-vpn/telegram.conf
```

2. Add your credentials:
```bash
BOT_TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
ADMIN_ID="YOUR_TELEGRAM_ID"
```

3. Set permissions:
```bash
sudo chmod 600 /etc/joeltom-vpn/telegram.conf
```

4. Enable in v2ray-dns.conf:
```bash
V2RAY_DNS_TELEGRAM_ENABLED=1
```

### Telegram Bot Commands

| Command | Description |
|---------|-------------|
| `/create` | Create new account |
| `/list` | List all accounts |
| `/info USERNAME` | View account info |
| `/delete USERNAME` | Delete account |
| `/renew USERNAME DAYS` | Renew account |
| `/limit USERNAME COUNT` | Change connection limit |
| `/disable USERNAME` | Disable account |
| `/enable USERNAME` | Enable account |
| `/status` | Show service status |
| `/help` | Show help message |

## Ports Used

| Service | Port | Protocol | Purpose |
|---------|------|----------|----------|
| V2Ray + DNS | 237 | TCP | VLESS proxy |
| FastDNS | 5400 | UDP | DNS tunneling |

## Firewall Configuration

The installation script automatically configures firewall rules:

```bash
# TCP port 237
ufw allow 237/tcp

# UDP port 5400
ufw allow 5400/udp

# Or with iptables
iptables -A INPUT -p tcp --dport 237 -j ACCEPT
iptables -A INPUT -p udp --dport 5400 -j ACCEPT
```

## Account Data Storage

Accounts are stored in:
```bash
/var/lib/joeltom-vpn/v2ray-dns/accounts.db
```

Each account contains:
- Username
- UUID (unique identifier)
- Creation date
- Expiration date
- Max connections
- Status (active/inactive)

## Security

### Telegram Token Security

- Token stored in: `/etc/joeltom-vpn/telegram.conf`
- File permissions: `600` (owner only)
- Never logged or printed
- Not included in version control (`.gitignore`)

### UUID Generation

- Unique UUID per account (not hardcoded)
- Generated on account creation
- Cannot be reused

## Logging

Logs are stored at:
```bash
/var/log/joeltom-vpn/v2ray-dns.log
```

Log level can be configured:
```bash
V2RAY_DNS_LOG_LEVEL="info"  # info, warn, error
```

## Troubleshooting

### Port Already in Use

Check which service is using the port:
```bash
netstat -tulpn | grep :237
netstat -tulpn | grep :5400
```

### Configuration Not Found

Ensure the configuration file exists:
```bash
sudo cat /etc/joeltom-vpn/v2ray-dns.conf
```

### Service Not Starting

Check service status:
```bash
sudo systemctl status v2ray-dns
sudo journalctl -u v2ray-dns -n 50
```

## Uninstallation

```bash
# Stop service
sudo systemctl stop v2ray-dns
sudo systemctl disable v2ray-dns

# Remove service file
sudo rm /etc/systemd/system/v2ray-dns.service

# Remove configuration
sudo rm -rf /etc/joeltom-vpn/v2ray-dns.conf

# Remove data
sudo rm -rf /var/lib/joeltom-vpn/v2ray-dns

# Reload systemd
sudo systemctl daemon-reload
```

## Important Notes

⚠️ **CRITICAL RULES:**

- ✅ V2RAY-DNS is a completely independent protocol
- ✅ Port 237 and 5400 must be available
- ✅ Existing protocols are never affected
- ✅ Each account has a unique UUID
- ✅ Telegram token must be configured locally
- ✅ Connection limits are per-account, not global
- ✅ Expiration checking is automatic
- ✅ Configuration is centralized and easily modifiable

## Support

For issues or questions, refer to:
- Main documentation: `/docs/`
- Configuration file: `/etc/joeltom-vpn/v2ray-dns.conf`
- Logs: `/var/log/joeltom-vpn/v2ray-dns.log`

---

**JOELTOM VPN — V2RAY-DNS Protocol**

*Secure • Fast • Independent*
