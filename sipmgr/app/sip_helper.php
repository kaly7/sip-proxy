<?php
declare(strict_types=1);

const SIP_NUMBERS_FILE  = '/opt/sip-push/numbers.json';
const SIP_APNS_LOG      = '/var/log/sip-push-apns.log';
const SIP_AST_LOG       = '/var/log/asterisk/messages.log';
const SIP_APPLY_SCRIPT  = '/opt/sip-push/sip_apply.sh';
const SIP_PJSIP_CONF    = '/etc/asterisk/pjsip.conf';
const SIP_EXT_CONF      = '/etc/asterisk/extensions.conf';
const SIP_UPSTREAM_IP   = '193.131.100.41';

// ---------------------------------------------------------------------------
// Asterisk CLI
// ---------------------------------------------------------------------------

function asterisk_cmd(string $cmd): string {
    $out = shell_exec('sudo /usr/sbin/asterisk -rx ' . escapeshellarg($cmd) . ' 2>/dev/null');
    return $out ?? '';
}

// ---------------------------------------------------------------------------
// Parse: endpoints
// Returns: [['name'=>'app1','username'=>'app1','state'=>'Unavailable'|'Not in use'|..., 'channels'=>0], ...]
// ---------------------------------------------------------------------------

function sip_get_endpoints(): array {
    $raw  = asterisk_cmd('pjsip show endpoints');
    $rows = [];
    foreach (explode("\n", $raw) as $line) {
        if (!preg_match('/^\s+Endpoint:\s+(\S+)\s+(\S.*?\S)\s+(\d+)\s+of/', $line, $m)) continue;
        $name = $m[1];
        if (in_array($name, ['<Endpoint/CID.....................................>'], true)) continue;
        $rows[] = [
            'name'     => $name,
            'state'    => trim($m[2]),
            'channels' => (int)$m[3],
        ];
    }
    // Extract usernames from InAuth lines
    $lines = explode("\n", $raw);
    $current = null;
    foreach ($lines as $line) {
        if (preg_match('/^\s+Endpoint:\s+(\S+)/', $line, $m)) {
            $current = $m[1];
        }
        if ($current && preg_match('/InAuth:\s+\S+\/(\S+)/', $line, $m)) {
            foreach ($rows as &$r) {
                if ($r['name'] === $current) { $r['username'] = $m[1]; break; }
            }
            unset($r);
        }
    }
    // Csak az app végpontokat mutatjuk (app1, app2, ...); upstream-in és us-N trunk-ok nem kellenek
    return array_values(array_filter($rows, fn($r) => str_starts_with($r['name'], 'app')));
}

// ---------------------------------------------------------------------------
// Parse: registrations
// Returns: [['name'=>'us-reg-1','server'=>'sip:193...','auth'=>'us-auth-1','status'=>'Registered','expiry'=>100], ...]
// ---------------------------------------------------------------------------

function sip_get_registrations(): array {
    $raw  = asterisk_cmd('pjsip show registrations');
    $rows = [];
    foreach (explode("\n", $raw) as $line) {
        // Formátum: " us-reg-1/sip:193.131.100.41   us-auth-1   Registered   (exp. 46s)"
        if (!preg_match('/^\s+(\S+\/sip:\S+)\s+(\S+)\s+(\w+)\s*(?:\(exp\.\s*(\d+)s\))?/', $line, $m)) continue;
        [$name, $server] = explode('/', $m[1], 2);
        $rows[] = [
            'name'   => $name,
            'server' => $server,
            'auth'   => $m[2],
            'status' => $m[3],
            'expiry' => isset($m[4]) ? (int)$m[4] : null,
        ];
    }
    return $rows;
}

// ---------------------------------------------------------------------------
// Parse: APNs log
// Groups log lines into push events: [['ts','caller_id','caller_name','app_user','status_code','status_text','ok'], ...]
// ---------------------------------------------------------------------------

function sip_parse_apns_log(int $limit = 500): array {
    if (!file_exists(SIP_APNS_LOG)) return [];
    $lines  = file(SIP_APNS_LOG, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (!$lines) return [];
    $lines  = array_reverse($lines); // newest first

    $events = [];
    $cur    = null;

    foreach ($lines as $line) {
        // [2026-05-30 12:02:18] Push kérés: app1 <- 06704341171 (Hívó neve)
        if (preg_match('/^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] Push kérés: (\S+) <- (\S+) \(([^)]*)\)/', $line, $m)) {
            if ($cur) $events[] = $cur;
            $cur = ['ts' => $m[1], 'app_user' => $m[2], 'caller_id' => $m[3], 'caller_name' => $m[4], 'status_code' => null, 'ok' => null];
            continue;
        }
        // Legacy format: Push kérés: caller=... name=...
        if (preg_match('/^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\] Push kérés: caller=(\S+) name=(\S+)/', $line, $m)) {
            if ($cur) $events[] = $cur;
            $cur = ['ts' => $m[1], 'app_user' => 'app1', 'caller_id' => $m[2], 'caller_name' => $m[3], 'status_code' => null, 'ok' => null];
            continue;
        }
        if ($cur && preg_match('/curl rc=\d+ stdout=.*?HTTP_STATUS:(\d+)/', $line, $m)) {
            $code = (int)$m[1];
            $cur['status_code'] = $code;
            $cur['ok']          = ($code === 200);
            // Extract reason if present
            if (preg_match('/stdout=(\{[^}]+\})/', $line, $rm)) {
                $cur['apns_body'] = $rm[1];
            }
        }
    }
    if ($cur) $events[] = $cur;

    return array_slice($events, 0, $limit);
}

// ---------------------------------------------------------------------------
// Parse: Asterisk messages log — relevant lines only
// ---------------------------------------------------------------------------

function sip_parse_asterisk_log(int $limit = 300): array {
    if (!file_exists(SIP_AST_LOG)) return [];
    $lines = file(SIP_AST_LOG, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if (!$lines) return [];

    $keywords = ['INVITE', 'Dial', 'dial', 'push', 'Push', 'System',
                 'app1', 'app2', 'app3', 'app4', 'app5',
                 'Registered', 'Unregistered', 'Reachable', 'Unreachable',
                 'WebSocket', 'busy', 'congested', 'failed', 'rejected',
                 'ring-app', 'from-upstream', 'Gosub', 'Hangup'];

    $filtered = [];
    foreach (array_reverse($lines) as $line) {
        foreach ($keywords as $kw) {
            if (str_contains($line, $kw)) {
                if (str_contains($line, '] ERROR[')) {
                    $level = 'error';
                } elseif (str_contains($line, '] WARNING[')) {
                    $level = 'warning';
                } elseif (str_contains($line, '] NOTICE[')) {
                    $level = 'notice';
                } elseif (str_contains($line, 'busy') || str_contains($line, 'congested')
                       || str_contains($line, 'failed') || str_contains($line, 'rejected')
                       || str_contains($line, 'Unreachable') || str_contains($line, 'abruptly')) {
                    $level = 'warning';
                } elseif (str_contains($line, 'Reachable') || str_contains($line, 'Registered')
                       || str_contains($line, 'Added contact')) {
                    $level = 'notice';
                } else {
                    $level = 'other';
                }
                $filtered[] = ['line' => $line, 'level' => $level];
                break;
            }
        }
        if (count($filtered) >= $limit) break;
    }
    return $filtered;
}

// ---------------------------------------------------------------------------
// Numbers JSON CRUD
// ---------------------------------------------------------------------------

function sip_numbers_read(): array {
    if (!file_exists(SIP_NUMBERS_FILE)) return [];
    $json = file_get_contents(SIP_NUMBERS_FILE);
    return json_decode($json ?: '[]', true) ?? [];
}

function sip_numbers_write(array $numbers): void {
    file_put_contents(SIP_NUMBERS_FILE, json_encode($numbers, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

function sip_next_id(array $numbers): int {
    return $numbers ? max(array_column($numbers, 'id')) + 1 : 1;
}

function sip_next_app_username(array $numbers): string {
    $used = array_column($numbers, 'app_username');
    for ($i = 1; $i <= 10; $i++) {
        if (!in_array("app$i", $used, true)) return "app$i";
    }
    return 'app' . (count($numbers) + 1);
}

// ---------------------------------------------------------------------------
// Config generation
// ---------------------------------------------------------------------------

function sip_generate_pjsip(array $numbers): string {
    $out = <<<'INI'
; === Transportok ===

[transport-ws]
type=transport
protocol=ws
bind=0.0.0.0:8088

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

; === Sablonok ===

[upstream-tpl](!)
type=endpoint
transport=transport-udp
context=from-upstream
disallow=all
allow=ulaw
allow=alaw
allow=g722

[app-tpl](!)
type=endpoint
transport=transport-ws
disallow=all
allow=ulaw
allow=alaw
allow=g722
webrtc=yes
dtls_cert_file=/etc/asterisk/keys/asterisk.crt
dtls_private_key=/etc/asterisk/keys/asterisk.key
dtls_verify=fingerprint
dtls_setup=actpass
direct_media=no
rtp_symmetric=yes

; === Bejövő upstream forgalom ===

[upstream-in]
type=endpoint
transport=transport-udp
context=from-upstream
disallow=all
allow=ulaw
allow=alaw
allow=g722

[upstream-identify]
type=identify
endpoint=upstream-in
match=193.131.100.41

INI;

    $n = 0;
    foreach ($numbers as $num) {
        if (empty($num['enabled'])) continue;
        $n++;
        $sip = $num['sip_number'];
        $pw  = $num['sip_password'];
        $app = $num['app_username'];
        $apw = $num['app_password'];
        $ip  = SIP_UPSTREAM_IP;
        $out .= <<<INI

; ===========================================================================
; === {$n}. szám: {$sip} → {$app} ===
; ===========================================================================

[us-auth-{$n}]
type=auth
auth_type=userpass
username={$sip}
password={$pw}

[us-aor-{$n}]
type=aor
contact=sip:{$sip}@{$ip}:5060

[us-{$n}](upstream-tpl)
outbound_auth=us-auth-{$n}
aors=us-aor-{$n}
from_user={$sip}
from_domain={$ip}

[us-reg-{$n}]
type=registration
outbound_auth=us-auth-{$n}
server_uri=sip:{$ip}
client_uri=sip:{$sip}@{$ip}
retry_interval=60
contact_user={$sip}
expiration=120

[app-auth-{$n}]
type=auth
auth_type=userpass
username={$app}
password={$apw}

[{$app}]
type=aor
max_contacts=1
remove_existing=yes

[{$app}](app-tpl)
context=from-app-{$n}
auth=app-auth-{$n}
aors={$app}

INI;
    }
    return $out;
}

function sip_generate_extensions(array $numbers): string {
    $out = "; === Kimenő hívások ===\n\n";
    $n   = 0;
    foreach ($numbers as $num) {
        if (empty($num['enabled'])) continue;
        $n++;
        $out .= "[from-app-{$n}]\nexten => _[+0-9].,1,Dial(PJSIP/\${EXTEN}@us-{$n})\n same => n,Hangup()\n\n";
    }

    $out .= "; === Bejövő hívások ===\n\n[from-upstream]\n";
    $n = 0;
    foreach ($numbers as $num) {
        if (empty($num['enabled'])) continue;
        $n++;
        $sip = $num['sip_number'];
        $app = $num['app_username'];
        $out .= "exten => {$sip},1,Gosub(ring-app,s,1({$app}))\n same => n,Hangup()\n\n";
    }

    // Fallback: first enabled number
    $first = null;
    foreach ($numbers as $num) { if (!empty($num['enabled'])) { $first = $num['sip_number']; break; } }
    if ($first) $out .= "exten => s,1,Goto({$first},1)\n\n";

    $out .= <<<'EXT'

; === Hívás + push subroutine ===
; ARG1 = app endpoint neve (pl. app1)
; Ha az app regisztrált: azonnal tárcsáz.
; Ha nincs: push küld, majd 1 mp-enként ellenőrzi (max 20x), és
; amint az app csatlakozik, azonnal csenget — nem vár fix ideig.

[ring-app]
exten => s,1,NoOp(Bejövő hívás: ${ARG1} <- ${CALLERID(num)})
 same => n,GotoIf($["${PJSIP_AOR(${ARG1},contact)}" != ""]?dial)
 same => n,Ringing()
 same => n,System(/opt/sip-push/send_push.py "${CALLERID(name)}" "${CALLERID(num)}" "${ARG1}")
 same => n,Set(WAIT_COUNT=0)
 same => n(waitloop),GotoIf($[${WAIT_COUNT} >= 20]?done)
 same => n,Wait(1)
 same => n,Set(WAIT_COUNT=$[${WAIT_COUNT}+1])
 same => n,GotoIf($["${PJSIP_AOR(${ARG1},contact)}" = ""]?waitloop)
 same => n(dial),Dial(PJSIP/${ARG1},30)
 same => n(done),Return()
EXT;
    return $out;
}

// ---------------------------------------------------------------------------
// Apply: write + reload
// ---------------------------------------------------------------------------

function sip_apply(array $numbers): array {
    $pjsip = sip_generate_pjsip($numbers);
    $exts  = sip_generate_extensions($numbers);

    $tmpP = '/tmp/sip_new_pjsip.conf';
    $tmpE = '/tmp/sip_new_extensions.conf';

    file_put_contents($tmpP, $pjsip);
    file_put_contents($tmpE, $exts);
    chmod($tmpP, 0644);
    chmod($tmpE, 0644);

    $out = shell_exec('sudo ' . escapeshellarg(SIP_APPLY_SCRIPT) . ' 2>&1');
    $ok  = (str_contains($out ?? '', 'OK') || trim($out ?? '') === '');

    return ['ok' => $ok, 'output' => trim($out ?? '')];
}
