JOELTOM VPN Web

Interface web d'administration pour JOELTOM VPN ("JOELTOM_VPN").
Gestion complète des comptes VPN (SSH, SlowDNS, UDP Custom, ZipVPN, Xray) depuis un panel web moderne.

---

🚀 Installation

Via le menu (recommandé)

menu
# Sélectionner [18] JOELTOM VPN TUNNEL WEB
# Sélectionner [1] Installer JOELTOM VPN Web

Directement depuis le dossier source

cd /path/to/JOELTOM_VPN/joeltom-web
bash install.sh

L'installateur va :

1. Demander le username et password admin utilisés pour se connecter au panel.
2. Détecter automatiquement un port libre.
3. Utiliser le port "2087" par défaut, avec les ports "2096", "8787", "3001" et "9090" comme alternatives.
4. Installer Node.js 18+ si nécessaire.
5. Compiler le TypeScript.
6. Créer le service systemd "joeltom-web".
7. Démarrer automatiquement le panel.

---

🌐 Accès au panel

http://<IP-VPS>:<PORT>

Le port utilisé est affiché à la fin de l'installation et enregistré dans :

/etc/joeltom-vpn-web/config.json

---

⚙️ Configuration

Fichier :

/etc/joeltom-vpn-web/config.json

Exemple :

{
  "port": 2087,
  "admin_user": "admin",
  "admin_password": "votre_mot_de_passe",
  "jwt_secret": "secret_généré_automatiquement",
  "scripts_dir": "/usr/local/sbin",
  "db_dir": "/etc/joeltom-vpn-web"
}

Paramètre| Description
"port"| Port d'écoute du panel web
"admin_user"| Username du super admin initial
"admin_password"| Mot de passe du super admin initial
"jwt_secret"| Clé secrète JWT générée automatiquement
"scripts_dir"| Dossier des scripts JOELTOM VPN
"db_dir"| Dossier de la base de données SQLite

---

📋 Menu 18 — JOELTOM VPN Web

Accès depuis le menu principal :

menu → [18] JOELTOM VPN TUNNEL WEB

Option| Description
1| Modifier les identifiants admin
2| Manager Admin — créer, modifier, suspendre, promouvoir
3| Manager Client — créer, renouveler, suspendre, supprimer
4| Manager Plans/Produits — créer et gérer les offres
5| Logs & Audit — historique des actions
6| Statut & Contrôle du service
7| Mettre à jour JOELTOM VPN Web
8| Désinstaller JOELTOM VPN Web
0| Retour

---

🔌 Protocoles supportés

Protocole| Description| Mécanisme
"ssh"| SSH over WebSocket (Dropbear/OpenSSH)| "useradd" + "chage"
"slowdns"| SlowDNS avec partage du compte SSH| "useradd" + identifiants SlowDNS
"udpcustom"| UDP Custom| "useradd" + lien UDP
"vmess"| VMess Xray| Modification de la configuration Xray
"vless"| VLESS Xray| Modification de la configuration Xray
"trojan"| Trojan Xray| Modification de la configuration Xray
"zipvpn"| ZipVPN| "/etc/zivpn/users.db"

---

🏗️ Architecture

joeltom-web/
├── server/
│   ├── index.ts
│   ├── db.ts
│   ├── scripts.ts
│   ├── middleware/
│   │   └── auth.ts
│   └── routes/
│       ├── auth.ts
│       ├── admins.ts
│       ├── clients.ts
│       ├── plans.ts
│       └── logs.ts
├── public/
│   └── index.html
├── package.json
├── tsconfig.json
├── install.sh
├── joeltom-web.service
└── README.md

---

🔐 Sécurité

- Mots de passe protégés avec bcrypt (coût 12).
- Sessions JWT avec expiration de 24 heures.
- RBAC avec deux niveaux :
  - "super_admin" — accès complet.
  - "admin" — gestion des clients et plans.
- Fichier de configuration protégé avec "chmod 600".
- Validation stricte des données côté API.

---

🛠️ Gestion du service

Vérifier le statut

systemctl status joeltom-web

Redémarrer

systemctl restart joeltom-web

Arrêter

systemctl stop joeltom-web

Voir les logs en temps réel

journalctl -u joeltom-web -f

---

🗄️ Base de données

SQLite :

/etc/joeltom-vpn-web/joeltom.db

Tables principales :

admins
clients
plans
audit_logs
sessions

---

❌ Désinstallation

Depuis le menu :

menu → [18] → [8] Désinstaller JOELTOM VPN Web

Ou manuellement :

systemctl stop joeltom-web
systemctl disable joeltom-web

rm -rf /opt/joeltom-vpn-web

rm -rf /etc/joeltom-vpn-web

rm /etc/systemd/system/joeltom-web.service

systemctl daemon-reload

«⚠️ La suppression de "/etc/joeltom-vpn-web" supprime également les données et la base SQLite du panel.»

---

📡 API Reference

Méthode| Endpoint| Description
POST| "/api/auth/login"| Connexion
POST| "/api/auth/logout"| Déconnexion
GET| "/api/auth/me"| Informations de la session actuelle
POST| "/api/auth/change-password"| Modifier les identifiants
GET| "/api/admins"| Lister les administrateurs
POST| "/api/admins"| Créer un administrateur
PUT| "/api/admins/:id"| Modifier un administrateur
POST| "/api/admins/:id/suspend"| Suspendre un administrateur
POST| "/api/admins/:id/promote"| Promouvoir en "super_admin"
DELETE| "/api/admins/:id"| Supprimer un administrateur
GET| "/api/clients"| Lister les clients
POST| "/api/clients"| Créer un client et son compte système
POST| "/api/clients/:id/renew"| Renouveler un client
POST| "/api/clients/:id/suspend"| Suspendre un client
DELETE| "/api/clients/:id"| Supprimer un client
GET| "/api/plans"| Lister les plans
POST| "/api/plans"| Créer un plan
PUT| "/api/plans/:id"| Modifier un plan
DELETE| "/api/plans/:id"| Supprimer un plan
GET| "/api/logs"| Consulter les logs d'audit
GET| "/api/logs/stats"| Statistiques du tableau de bord
GET| "/api/health"| Vérification de l'état du service

---

💻 JOELTOM VPN

JOELTOM VPN Web — Panel moderne de gestion des comptes VPN.

JOELTOM VPN
Secure • Fast • Powerful