<?php
declare(strict_types=1);
require_once __DIR__ . '/../app/functions.php';
require_once __DIR__ . '/../app/sip_helper.php';

$page  = 'log';
$title = 'Napló';

// Filters
$f_from     = trim($_GET['from']     ?? '');
$f_to       = trim($_GET['to']       ?? '');
$f_endpoint = trim($_GET['endpoint'] ?? '');
$f_search   = trim($_GET['search']   ?? '');
$per_page   = 20;
$p          = max(1, (int)($_GET['page'] ?? 1));

// All events
$all_events = sip_parse_apns_log(2000);

// Apply filters
$filtered = array_filter($all_events, function ($ev) use ($f_from, $f_to, $f_endpoint, $f_search) {
    if ($f_from && ($ev['ts'] ?? '') < $f_from . ' 00:00:00') return false;
    if ($f_to   && ($ev['ts'] ?? '') > $f_to   . ' 23:59:59') return false;
    if ($f_endpoint && ($ev['app_user'] ?? '') !== $f_endpoint) return false;
    if ($f_search   && !str_contains($ev['caller_id'] ?? '', $f_search)
                    && !str_contains($ev['caller_name'] ?? '', $f_search)) return false;
    return true;
});
$filtered = array_values($filtered);

$total      = count($filtered);
$total_pages = max(1, (int)ceil($total / $per_page));
$p          = min($p, $total_pages);
$page_events = array_slice($filtered, ($p - 1) * $per_page, $per_page);

// Collect unique endpoints for filter dropdown
$all_endpoints = array_unique(array_filter(array_column($all_events, 'app_user')));
sort($all_endpoints);

// Asterisk log
$ast_lines = sip_parse_asterisk_log(300);

require __DIR__ . '/_header.php';
?>

<div class="d-flex align-items-center justify-content-between mb-4">
  <h1 class="h4 m-0">Napló</h1>
</div>

<!-- Filter bar -->
<form method="get" class="card shadow-sm mb-3">
  <div class="card-body py-2">
    <div class="row g-2 align-items-end">
      <div class="col-6 col-md-2">
        <label class="form-label small mb-1">Dátum (tól)</label>
        <input type="date" name="from" class="form-control form-control-sm" value="<?= e($f_from) ?>">
      </div>
      <div class="col-6 col-md-2">
        <label class="form-label small mb-1">Dátum (ig)</label>
        <input type="date" name="to" class="form-control form-control-sm" value="<?= e($f_to) ?>">
      </div>
      <div class="col-6 col-md-2">
        <label class="form-label small mb-1">Végpont</label>
        <select name="endpoint" class="form-select form-select-sm">
          <option value="">– mind –</option>
          <?php foreach ($all_endpoints as $ep): ?>
            <option value="<?= e($ep) ?>" <?= $f_endpoint === $ep ? 'selected' : '' ?>><?= e($ep) ?></option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="col-6 col-md-3">
        <label class="form-label small mb-1">Hívószám keresés</label>
        <input type="text" name="search" class="form-control form-control-sm" placeholder="pl. 0630…" value="<?= e($f_search) ?>">
      </div>
      <div class="col-12 col-md-3 d-flex gap-2 pt-1">
        <button type="submit" class="btn btn-sm btn-primary">Szűrés</button>
        <a href="<?= e(base_url('log.php')) ?>" class="btn btn-sm btn-outline-secondary">Törlés</a>
        <a href="<?= e(base_url('log.php') . '?export=csv&' . http_build_query(['from'=>$f_from,'to'=>$f_to,'endpoint'=>$f_endpoint,'search'=>$f_search])) ?>"
           class="btn btn-sm btn-outline-success ms-auto">↓ CSV</a>
      </div>
    </div>
  </div>
</form>

<?php
// CSV export
if (isset($_GET['export']) && $_GET['export'] === 'csv') {
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="sip-log-' . date('Y-m-d') . '.csv"');
    echo "\xEF\xBB\xBF"; // UTF-8 BOM
    echo "Időpont,Végpont,Hívó szám,Hívó neve,HTTP kód,Eredmény\n";
    foreach ($filtered as $ev) {
        $ok_str = $ev['ok'] === true ? 'OK' : ($ev['ok'] === false ? 'Hiba' : '–');
        printf("%s,%s,%s,%s,%s,%s\n",
            $ev['ts'] ?? '',
            $ev['app_user'] ?? '',
            $ev['caller_id'] ?? '',
            $ev['caller_name'] ?? '',
            $ev['status_code'] ?? '',
            $ok_str
        );
    }
    exit;
}
?>

<!-- Call log -->
<div class="card shadow-sm mb-3">
  <div class="card-header py-2 d-flex align-items-center">
    <span class="fw-semibold">Hívásnapló</span>
    <span class="badge bg-secondary ms-2"><?= $total ?> esemény</span>
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
      <?php if (!$page_events): ?>
        <tr><td colspan="5" class="text-muted text-center py-4 small">Nincs találat</td></tr>
      <?php else: foreach ($page_events as $ev): ?>
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
  <?php if ($total_pages > 1): ?>
  <div class="card-footer py-2">
    <nav>
      <ul class="pagination pagination-sm mb-0 justify-content-center">
        <?php for ($i = 1; $i <= $total_pages; $i++):
          $q = http_build_query(['from'=>$f_from,'to'=>$f_to,'endpoint'=>$f_endpoint,'search'=>$f_search,'page'=>$i]);
        ?>
          <li class="page-item <?= $i === $p ? 'active' : '' ?>">
            <a class="page-link" href="<?= e(base_url('log.php') . '?' . $q) ?>"><?= $i ?></a>
          </li>
        <?php endfor; ?>
      </ul>
    </nav>
  </div>
  <?php endif; ?>
</div>

<!-- Asterisk messages -->
<div class="card shadow-sm">
  <div class="card-header py-2 d-flex align-items-center">
    <span class="fw-semibold">Asterisk üzenetek</span>
    <span class="text-muted small ms-2">(legutóbbi 300 releváns sor)</span>
  </div>
  <div class="card-body p-0">
    <div style="max-height:420px; overflow-y:auto; font-size:.78rem; line-height:1.5;">
      <table class="table table-sm mb-0">
        <tbody>
        <?php if (!$ast_lines): ?>
          <tr><td class="text-muted text-center py-3">Nincs adat</td></tr>
        <?php else: foreach ($ast_lines as $row):
          $bg = match($row['level']) {
            'error'   => 'background-color:#f5c2c7 !important; color:#58151c',
            'warning' => 'background-color:#ffe69c !important; color:#4d3a00',
            'notice'  => 'background-color:#9eeaf9 !important; color:#084298',
            default   => 'background-color:transparent; color:#495057',
          };
        ?>
          <tr>
            <td class="sip-mono ps-3" style="white-space:pre-wrap; word-break:break-all; <?= $bg ?>"><?= e($row['line']) ?></td>
          </tr>
        <?php endforeach; endif; ?>
        </tbody>
      </table>
    </div>
  </div>
</div>

<?php require __DIR__ . '/_footer.php'; ?>
