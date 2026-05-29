# sip-proxy

WebSocket ↔ SIP gateway Asterisk 20.19.0 alapon, Flutter softphone apphoz.

## Architektúra

```
Flutter app  →  ws://192.168.16.22:8088/ws  →  Asterisk (Debian 12, ez a szerver)
                                                        ↕ UDP SIP
                                               193.131.100.41:5060 (upstream Asterisk)
```

## App belépési adatok

| | |
|---|---|
| Szerver | `ws://192.168.16.22:8088/ws` |
| Domain | `192.168.16.22` |
| Felhasználónév | `app` |
| Jelszó | `app1234` |

## Fájlok

### `asterisk/`
| Fájl | Útvonal a szerveren | Leírás |
|------|---------------------|--------|
| `pjsip.conf` | `/etc/asterisk/pjsip.conf` | PJSIP: transportok, upstream trunk, WebRTC endpoint |
| `extensions.conf` | `/etc/asterisk/extensions.conf` | Dialplan: kimenő + bejövő + push logika |
| `http.conf` | `/etc/asterisk/http.conf` | WebSocket HTTP szerver (port 8088) |

### `push/`
| Fájl | Útvonal a szerveren | Leírás |
|------|---------------------|--------|
| `token_server.py` | `/opt/sip-push/token_server.py` | Flask API (port 9451) — VoIP push token tárolás |
| `send_push.py` | `/opt/sip-push/send_push.py` | APNs push küldő AGI script |

## Push notification

- Token szerver: `http://192.168.16.22:9451`
- App indításakor: `POST /register-token` — `{"user":"app","token":"<PushKit token>"}`
- `voip.pem`: `/etc/asterisk/keys/voip.pem` (Apple APNs tanúsítvány, érvényes 2027-06-27-ig)
- APNs host: `api.sandbox.push.apple.com` (fejlesztői build)

## Visszaállítás

```bash
# Konfig fájlok visszamásolása:
sudo cp asterisk/pjsip.conf /etc/asterisk/pjsip.conf
sudo cp asterisk/extensions.conf /etc/asterisk/extensions.conf
sudo cp asterisk/http.conf /etc/asterisk/http.conf
sudo systemctl restart asterisk

# Push szerver indítása:
mkdir -p /opt/sip-push
cp push/token_server.py /opt/sip-push/
cp push/send_push.py /opt/sip-push/
chmod +x /opt/sip-push/send_push.py
nohup python3 /opt/sip-push/token_server.py > /tmp/sip-push.log 2>&1 &
```
