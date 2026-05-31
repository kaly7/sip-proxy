# sip-proxy

WebSocket ↔ SIP gateway Asterisk 20.19.0 alapon, Flutter softphone apphoz.

## Architektúra

```
Flutter app (iOS)
    │  VoIP PushKit értesítés (APNs)
    │  ws://192.168.16.22:8088/ws  (WebRTC/DTLS)
    ▼
Asterisk 20.19.0  (Debian 12, 192.168.16.22)
    │  UDP SIP / regisztráció
    ▼
193.131.100.41:5060  (upstream SIP szerver)
```

### Bejövő hívás folyamata (CallKit-first)

1. Upstream INVITE érkezik → Asterisk push-t küld az appnak (APNs HTTP/2)
2. App felébred → `reportNewIncomingCall()` → CallKit UI megjelenik
3. Felhasználó tappol „Fogadás" → app foreground-ba kerül → SIP regisztrál
4. Asterisk detektálja a regisztrációt → 1mp settle → INVITE küld
5. App (foreground-ban) WebRTC peer connection épül → 200 OK → hívás kapcsolódik
6. Hívás vége: Asterisk BYE → `FlutterCallkitIncoming.endAllCalls()`

## App belépési adatok

| | |
|---|---|
| Szerver | `ws://192.168.16.22:8088/ws` |
| Domain | `192.168.16.22` |
| Felhasználónév | `app1` |
| Jelszó | `app1234` |

## SIP szám

| | |
|---|---|
| Szám | `92400004` |
| Upstream | `193.131.100.41:5060` |
| SIP jelszó | `Oob8aiRaht1e` |

## Fájlok

### `asterisk/`
| Fájl | Útvonal a szerveren | Leírás |
|------|---------------------|--------|
| `pjsip.conf` | `/etc/asterisk/pjsip.conf` | Transportok, upstream trunk, WebRTC app endpoint |
| `extensions.conf` | `/etc/asterisk/extensions.conf` | Dialplan: kimenő + bejövő + push + retry logika |
| `rtp.conf` | `/etc/asterisk/rtp.conf` | `srtpreplayprotection=no` (WebRTC kompatibilitás) |
| `logger.conf` | `/etc/asterisk/logger.conf` | `verbose(4)` logging a messages.log-ba |
| `http.conf` | `/etc/asterisk/http.conf` | WebSocket HTTP szerver (port 8088) |

### `push/`
| Fájl | Útvonal a szerveren | Leírás |
|------|---------------------|--------|
| `token_server.py` | `/opt/sip-push/token_server.py` | Flask API (port 9451) — VoIP push token tárolás |
| `send_push.py` | `/opt/sip-push/send_push.py` | APNs push küldő script (Asterisk System() hívja) |

### Egyéb szerveren lévő fájlok
| Útvonal | Leírás |
|---------|--------|
| `/opt/sip-push/numbers.json` | SIP számok és app végpontok konfigja (admin panel írja) |
| `/opt/sip-push/sip_apply.sh` | sudo wrapper: konfig generálás + asterisk reload |
| `/etc/asterisk/keys/voip.pem` | Apple APNs VoIP tanúsítvány (érvényes 2027-06-27-ig) |
| `/var/log/sip-push-apns.log` | APNs push napló |

## Push notification

- Token szerver: `http://192.168.16.22:9451`
- App indításakor: `POST /register-token` — `{"user":"app1","token":"<PushKit token>"}`
- APNs host: `api.push.apple.com` (**production**, nem sandbox)
- Bundle ID: `com.kaly.sipApp`

## Admin panel

- URL: `http://192.168.16.22:9452`
- SSO: auth_center (port 90) — admin role szükséges
- Oldalak: Dashboard (végpont állapotok, regisztrációk), Napló (APNs + Asterisk log), Számok (CRUD)

## Dialplan logika (extensions.conf)

```
Polling loop:  max 45 iteráció × 1mp = 45 mp várakozás regisztrációra
Settle time:   1mp a regisztráció detektálása után (SIP stack settle)
BUSY retry:    max 8×, 2mp közönként (ha az app 486-ot küld)
Dial timeout:  30mp
```

## Visszaállítás

```bash
# Asterisk konfig visszamásolása:
sudo cp asterisk/pjsip.conf /etc/asterisk/pjsip.conf
sudo cp asterisk/extensions.conf /etc/asterisk/extensions.conf
sudo cp asterisk/rtp.conf /etc/asterisk/rtp.conf
sudo cp asterisk/logger.conf /etc/asterisk/logger.conf
sudo cp asterisk/http.conf /etc/asterisk/http.conf
sudo systemctl restart asterisk

# Push szerver indítása:
sudo mkdir -p /opt/sip-push
sudo cp push/token_server.py /opt/sip-push/
sudo cp push/send_push.py /opt/sip-push/
sudo chmod +x /opt/sip-push/send_push.py
nohup python3 /opt/sip-push/token_server.py > /tmp/sip-push.log 2>&1 &
```
