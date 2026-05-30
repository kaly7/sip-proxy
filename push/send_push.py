#!/usr/bin/env python3
import sys, json, subprocess, urllib.request
from datetime import datetime

VOIP_PEM   = '/etc/asterisk/keys/voip.pem'
BUNDLE_ID  = 'com.kaly.sipApp'
TOKEN_API  = 'http://localhost:9451/get-token/app'
APNS_HOST  = 'api.sandbox.push.apple.com'
LOG_FILE   = '/var/log/sip-push-apns.log'

def log(msg):
    ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{ts}] {msg}\n'
    with open(LOG_FILE, 'a') as f:
        f.write(line)
    sys.stderr.write(line)

def get_token():
    try:
        r = urllib.request.urlopen(TOKEN_API, timeout=3)
        return json.loads(r.read())['token']
    except Exception as e:
        log(f'Token hiba: {e}')
        return None

def send_apns_push(device_token, caller_name, caller_id):
    payload = json.dumps({'caller_name': caller_name, 'caller_id': caller_id})
    cmd = [
        'curl', '--http2', '--silent', '--show-error',
        '--cert', VOIP_PEM,
        '--key',  VOIP_PEM,
        '-H', f'apns-topic: {BUNDLE_ID}.voip',
        '-H', 'apns-push-type: voip',
        '-H', 'apns-priority: 10',
        '-H', 'content-type: application/json',
        '-d', payload,
        '-w', '\nHTTP_STATUS:%{http_code}',
        f'https://{APNS_HOST}/3/device/{device_token}'
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    return result.stdout, result.stderr, result.returncode

caller_name = sys.argv[1] if len(sys.argv) > 1 else 'Ismeretlen'
caller_id   = sys.argv[2] if len(sys.argv) > 2 else 'unknown'

log(f'Push kérés: caller={caller_id} name={caller_name}')

token = get_token()
if not token:
    log('Nincs VoIP push token')
    sys.exit(1)

log(f'Token: {token[:16]}...')

try:
    stdout, stderr, rc = send_apns_push(token, caller_name, caller_id)
    log(f'curl rc={rc} stdout={stdout.strip()} stderr={stderr.strip()}')
except Exception as e:
    log(f'curl hiba: {e}')
