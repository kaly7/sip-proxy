#!/usr/bin/env python3
import sys, json, urllib.request, ssl
import http.client

VOIP_PEM = '/etc/asterisk/keys/voip.pem'
BUNDLE_ID = 'com.kaly.sipApp'
TOKEN_API = 'http://localhost:9451/get-token/app'
APNS_HOST = 'api.sandbox.push.apple.com'

def get_token():
    try:
        r = urllib.request.urlopen(TOKEN_API, timeout=3)
        return json.loads(r.read())['token']
    except:
        return None

def send_apns_push(device_token, caller_name, caller_id):
    ssl_ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ssl_ctx.load_cert_chain(VOIP_PEM)
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    payload = json.dumps({
        'caller_name': caller_name,
        'caller_id': caller_id
    }).encode()

    conn = http.client.HTTPSConnection(APNS_HOST, 443, context=ssl_ctx)
    headers = {
        'apns-topic': f'{BUNDLE_ID}.voip',
        'apns-push-type': 'voip',
        'apns-priority': '10',
        'content-type': 'application/json'
    }
    conn.request('POST', f'/3/device/{device_token}', payload, headers)
    resp = conn.getresponse()
    body = resp.read()
    conn.close()
    return resp.status, body

caller_name = sys.argv[1] if len(sys.argv) > 1 else 'Ismeretlen'
caller_id   = sys.argv[2] if len(sys.argv) > 2 else 'unknown'

token = get_token()
if token:
    status, body = send_apns_push(token, caller_name, caller_id)
    sys.stderr.write(f'APNs válasz: {status} {body}\n')
else:
    sys.stderr.write('Nincs token az adatbázisban\n')
