<?php
declare(strict_types=1);
require_once __DIR__ . '/../app/functions.php';
require_once __DIR__ . '/../app/sip_helper.php';

$page  = 'dashboard';
$title = 'Dashboard';

$endpoints     = sip_get_endpoints();
$registrations = sip_get_registrations();
$recent_events = sip_parse_apns_log(5);
$numbers       = sip_numbers_read();

// numbers.json indexelése app_username szerint
$num_by_app = [];
foreach ($numbers as $n) {
    $num_by_app[$n['app_username']] = $n;
}

// APNs log utolsó 50 eseményéből per-végpont statisztika
$all_events = sip_parse_apns_log(50);
$ep_stats   = []; // ['app_user'] => ['last_ts' => ..., 'results' => [true/false, ...]]
foreach ($all_events as $ev) {
    $app = $ev['app_user'] ?? '';
    if (!$app) continue;
    if (!isset($ep_stats[$app])) {
        $ep_stats[$app] = ['last_ts' => $ev['ts'] ?? null, 'results' => []];
    }
    if (count($ep_stats[$app]['results']) < 5) {
        $ep_stats[$app]['results'][] = $ev['ok'];
    }
}

// Upstream regisztrációk indexelése sorszám szerint (us-reg-N → N-edik engedélyezett szám)
$enabled_numbers = array_values(array_filter($numbers, fn($n) => !empty($n['enabled'])));

require __DIR__ . '/_header.php';
?>

<div class="d-flex align-items-center justify-content-between mb-4">
  <h1 class="h4 m-0">Dashboard</h1>
  <div class="d-flex align-items-center gap-2">
    <span class="text-muted small" id="last-refresh"></span>
    <button class="btn btn-sm btn-outline-secondary" onclick="location.reload()">&#8635; Frissítés</button>
  </div>
</div>

<div class="row g-3 mb-3">
  <!-- Endpoints -->
  <div class="col-12 col-lg-7">
    <div class="card shadow-sm h-100">
      <div class="card-header d-flex align-items-center py-2">
        <span class="fw-semibold">Végpontok</span>
        <span class="badge bg-secondary ms-auto"><?= count($endpoints) ?></span>
      </div>
      <div class="card-body p-0">
        <table class="table table-hover align-middle mb-0">
          <thead class="table-light">
            <tr>
              <th class="ps-3">Végpont</th>
              <th>SIP szám</th>
              <th>Állapot</th>
              <th>Utolsó hívás</th>
              <th title="Utolsó 5 push eredménye">Push</th>
            </tr>
          </thead>
          <tbody>
          <?php if (!$endpoints): ?>
            <tr><td colspan="5" class="text-muted text-center py-3 small">Nincs adat</td></tr>
          <?php else: foreach ($endpoints as $ep):
            $state      = strtolower(trim($ep['state']));
            $registered = ($state === 'not in use');
            $inuse      = ($state === 'in use') || ($state === 'ringing');

            $num_info = $num_by_app[$ep['name']] ?? null;
            $sip_num  = $num_info['sip_number'] ?? ($ep['username'] ?? '–');
            $label    = $num_info['label'] ?? '';

            $stats    = $ep_stats[$ep['name']] ?? null;
            $last_ts  = $stats['last_ts'] ?? null;
            $results  = $stats['results'] ?? [];
          ?>
            <tr>
              <td class="ps-3">
                <span class="sip-mono fw-semibold"><?= e($ep['name']) ?></span>
                <?php if ($label): ?>
                  <br><span class="text-muted" style="font-size:.75rem"><?= e($label) ?></span>
                <?php endif; ?>
              </td>
              <td class="sip-mono text-muted small"><?= e($sip_num) ?></td>
              <td>
                <?php if ($inuse): ?>
                  <span class="pulse me-1"></span><span class="badge bg-success">Aktív hívás</span>
                <?php elseif ($registered): ?>
                  <span class="pulse me-1"></span><span class="badge bg-success">Regisztrált</span>
                <?php else: ?>
                  <span class="pulse offline me-1"></span><span class="badge bg-secondary">Nem elérhető</span>
                <?php endif; ?>
              </td>
              <td class="text-muted small">
                <?php if ($last_ts): ?>
                  <span title="<?= e($last_ts) ?>"><?= e(substr($last_ts, 5, 11)) ?></span>
                <?php else: ?>
                  <span class="text-muted">–</span>
                <?php endif; ?>
              </td>
              <td>
                <?php if (!$results): ?>
                  <span class="text-muted small">–</span>
                <?php else:
                  foreach ($results as $r): ?>
                    <?php if ($r === true): ?>
                      <span title="OK" style="color:#198754;font-size:1rem">●</span>
                    <?php elseif ($r === false): ?>
                      <span title="Hiba" style="color:#dc3545;font-size:1rem">●</span>
                    <?php else: ?>
                      <span title="Ismeretlen" style="color:#adb5bd;font-size:1rem">●</span>
                    <?php endif; ?>
                  <?php endforeach; ?>
                <?php endif; ?>
              </td>
            </tr>
          <?php endforeach; endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- Registrations -->
  <div class="col-12 col-lg-5">
    <div class="card shadow-sm h-100">
      <div class="card-header d-flex align-items-center py-2">
        <span class="fw-semibold">Upstream regisztrációk</span>
        <span class="badge bg-secondary ms-auto"><?= count($registrations) ?></span>
      </div>
      <div class="card-body p-0">
        <table class="table table-hover align-middle mb-0">
          <thead class="table-light">
            <tr>
              <th class="ps-3">SIP szám</th>
              <th>Állapot</th>
              <th>Lejárat</th>
            </tr>
          </thead>
          <tbody>
          <?php if (!$registrations): ?>
            <tr><td colspan="3" class="text-muted text-center py-3 small">Nincs regisztráció</td></tr>
          <?php else: foreach ($registrations as $i => $reg):
            $ok     = ($reg['status'] === 'Registered');
            $expiry = $reg['expiry'];
            $expiry_cls = '';
            if ($ok && $expiry !== null) {
                if ($expiry < 20)       $expiry_cls = 'text-danger fw-semibold';
                elseif ($expiry < 60)   $expiry_cls = 'text-warning fw-semibold';
            }
            // SIP szám kinyerése a server URI-ból vagy numbers.json-ból
            $linked_num = $enabled_numbers[$i] ?? null;
            $display_num = $linked_num['sip_number'] ?? null;
            if (!$display_num) {
                preg_match('/sip:(\d+)@/', $reg['server'], $m);
                $display_num = $m[1] ?? $reg['server'];
            }
            $display_label = $linked_num['label'] ?? '';
          ?>
            <tr>
              <td class="ps-3">
                <span class="sip-mono fw-semibold"><?= e($display_num) ?></span>
                <?php if ($display_label): ?>
                  <br><span class="text-muted" style="font-size:.75rem"><?= e($display_label) ?></span>
                <?php endif; ?>
              </td>
              <td>
                <?php if ($ok): ?>
                  <span class="pulse me-1"></span><span class="badge bg-success">Registered</span>
                <?php else: ?>
                  <span class="pulse offline me-1"></span><span class="badge bg-danger"><?= e($reg['status']) ?></span>
                <?php endif; ?>
              </td>
              <td class="sip-mono small <?= $expiry_cls ?>">
                <?php if ($expiry !== null): ?>
                  <?= $expiry ?>s
                  <?php if ($expiry < 20): ?> ⚠️<?php endif; ?>
                <?php else: ?>–<?php endif; ?>
              </td>
            </tr>
          <?php endforeach; endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>

<!-- Recent push events -->
<div class="card shadow-sm">
  <div class="card-header py-2 d-flex align-items-center">
    <span class="fw-semibold">Legutóbbi push értesítések</span>
    <a href="<?= e(base_url('log.php')) ?>" class="btn btn-sm btn-link ms-auto py-0">Teljes napló →</a>
  </div>
  <div class="card-body p-0">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light">
        <tr>
          <th class="ps-3">Időpont</th>
          <th>Végpont</th>
          <th>Hívó szám</th>
          <th>Hívó neve</th>
          <th>APNs eredmény</th>
        </tr>
      </thead>
      <tbody>
      <?php if (!$recent_events): ?>
        <tr><td colspan="5" class="text-muted text-center py-4 small">Még nincs push esemény</td></tr>
      <?php else: foreach ($recent_events as $ev): ?>
        <tr>
          <td class="ps-3 sip-mono text-muted small"><?= e($ev['ts'] ?? '–') ?></td>
          <td class="sip-mono"><?= e($ev['app_user'] ?? '–') ?></td>
          <td class="sip-mono"><?= e($ev['caller_id'] ?? '–') ?></td>
          <td class="text-muted small"><?= e($ev['caller_name'] ?? '–') ?></td>
          <td>
            <?php if ($ev['ok'] === true): ?>
              <span class="badge bg-success">HTTP 200 – OK</span>
            <?php elseif ($ev['ok'] === false): ?>
              <span class="badge bg-danger">HTTP <?= (int)$ev['status_code'] ?><?= !empty($ev['apns_body']) ? ' – ' . e($ev['apns_body']) : '' ?></span>
            <?php else: ?>
              <span class="badge bg-secondary">–</span>
            <?php endif; ?>
          </td>
        </tr>
      <?php endforeach; endif; ?>
      </tbody>
    </table>
  </div>
</div>

<script>
document.getElementById('last-refresh').textContent =
  'Frissítve: ' + new Date().toLocaleTimeString('hu-HU');
setTimeout(() => location.reload(), 30000);
</script>

<?php require __DIR__ . '/_footer.php'; ?>
