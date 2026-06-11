# SIP Proxy + Admin — Áttelepítési útmutató (Szerver_rv42)

> Ez a dokumentum a **Szerver_rv42** Claude számára készült a 194.152.151.76-os szerverre való telepítéshez.
> Kommunikáció: `MESSAGES.md` fájlban, `[Szerver_rv42]` és `[Szerver Claude]` jelzésekkel.

---

## Komponensek

| Komponens | Port | Leírás |
|-----------|------|--------|
| Asterisk PBX | 5060/UDP, 8088/WS | SIP szerver, WebRTC |
| Token API | 9451 | Python Flask push token szerver |
| SIP Admin panel | 9452 | PHP web admin (sipmgr/) |

---

## 1. Asterisk telepítése

```bash
sudo apt update && sudo apt install -y asterisk
asterisk --version  # 20.x kell
```

---

## 2. Kód klónozása

```bash
git clone https://github.com/kaly7/sip-proxy.git /var/www/html/sip-proxy
```

---

## 3. Asterisk config fájlok

```bash
sudo cp /var/www/html/sip-proxy/asterisk/pjsip.conf      /etc/asterisk/
sudo cp /var/www/html/sip-proxy/asterisk/extensions.conf  /etc/asterisk/
sudo cp /var/www/html/sip-proxy/asterisk/rtp.conf         /etc/asterisk/
sudo cp /var/www/html/sip-proxy/asterisk/http.conf        /etc/asterisk/
sudo cp /var/www/html/sip-proxy/asterisk/logger.conf      /etc/asterisk/
```

---

## 4. SSL tanúsítványok (Kaly másolja SCP-vel)

```bash
sudo mkdir -p /etc/asterisk/keys
# Kaly másolja:
# /etc/asterisk/keys/voip.pem      ← Apple VoIP PushKit cert (érvényes 2027.06.27-ig)
# /etc/asterisk/keys/asterisk.crt  ← DTLS/WebRTC cert
# /etc/asterisk/keys/asterisk.key  ← DTLS/WebRTC priv key
sudo chmod 640 /etc/asterisk/keys/*
sudo chown root:asterisk /etc/asterisk/keys/*
```

---

## 5. Python push rendszer

```bash
sudo mkdir -p /opt/sip-push
sudo cp /var/www/html/sip-proxy/push/token_server.py /opt/sip-push/
sudo cp /var/www/html/sip-proxy/push/send_push.py    /opt/sip-push/
sudo cp /var/www/html/sip-proxy/sip_apply.sh         /opt/sip-push/

# Függőségek
sudo apt install -y python3-flask python3-pip
# vagy: pip3 install flask --break-system-packages

# Szükséges JSON fájlok (Kaly másolja SCP-vel):
# /opt/sip-push/numbers.json   ← SIP szám adatok
# /opt/sip-push/tokens.json    ← PushKit tokenek (üres fájllal is indítható: echo '{}' > /opt/sip-push/tokens.json)

sudo touch /opt/sip-push/tokens.json
sudo chmod 664 /opt/sip-push/*.json
sudo chown www-data:www-data /opt/sip-push/*.json
```

### Token server systemd service

```bash
sudo tee /etc/systemd/system/sip-token-server.service > /dev/null <<'EOF'
[Unit]
Description=SIP Push Token Server
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/bin/python3 /opt/sip-push/token_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now sip-token-server
sudo systemctl status sip-token-server
```

---

## 6. sip_apply.sh sudo jogosultság

A PHP admin panel ezt hívja Asterisk reload-hoz:

```bash
sudo tee /etc/sudoers.d/sipmgr > /dev/null <<'EOF'
www-data ALL=(ALL) NOPASSWD: /opt/sip-push/sip_apply.sh
EOF
```

---

## 7. Apache — SIP Admin panel (port 9452)

```bash
# Port hozzáadása
grep -q "Listen 9452" /etc/apache2/ports.conf || echo "Listen 9452" | sudo tee -a /etc/apache2/ports.conf

# VirtualHost
sudo tee /etc/apache2/sites-available/sipmgr.conf > /dev/null <<'EOF'
<VirtualHost *:9452>
  DocumentRoot /var/www/html/sip-proxy/sipmgr/public
  <Directory /var/www/html/sip-proxy/sipmgr/public>
    AllowOverride All
    Require all granted
  </Directory>
  ErrorLog  /var/log/apache2/sipmgr_error.log
  CustomLog /var/log/apache2/sipmgr_access.log combined
</VirtualHost>
EOF

sudo a2ensite sipmgr
sudo systemctl reload apache2
```

---

## 8. SIP Admin konfigurálása

```bash
cp /var/www/html/sip-proxy/sipmgr/app/config.example.php \
   /var/www/html/sip-proxy/sipmgr/app/config.php
```

Szerkeszd a `config.php`-t:
- `auth_mode` → `'standalone'` (nincs auth_center)
- `admin_user` → pl. `'admin'`
- `admin_pass_hash` → generálj bcrypt hash-t:
  ```bash
  php -r "echo password_hash('VALASSZ_JELSZOT', PASSWORD_DEFAULT) . PHP_EOL;"
  ```
  A kimenetet másold be az `admin_pass_hash` mezőbe.

Az `admin_user` és `admin_pass_hash` értékeket **Kaly adja meg közvetlenül** (nem GitHubon).

---

## 9. Log fájlok

```bash
sudo touch /var/log/sip-push-apns.log
sudo chown www-data:www-data /var/log/sip-push-apns.log
```

---

## 10. Asterisk indítása

```bash
sudo systemctl enable --now asterisk
sudo systemctl status asterisk
# Ellenőrzés:
sudo asterisk -rx "pjsip show endpoints"
sudo asterisk -rx "pjsip show registrations"
```

---

## Portok összefoglalása

| Port | Protokoll | Szerepe |
|------|-----------|---------|
| 5060 | UDP | SIP upstream trunk (193.131.100.41) |
| 8088 | TCP/WS | Asterisk WebSocket (Flutter app) |
| 9451 | TCP | Token API (Python Flask) |
| 9452 | TCP | SIP Admin panel (Apache) |
| 10000–20000 | UDP/RTP | Hang adatfolyam |

**Fontos:** Az upstream SIP szerver (193.131.100.41) az 5060/UDP porton kommunikál — ennek nyitva kell lennie a tűzfalon!

---

## Kommunikáció

Ha valami nem megy, írj a `MESSAGES.md`-be `[Szerver_rv42]` jelzéssel.
