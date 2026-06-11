<?php
declare(strict_types=1);
require_once __DIR__ . '/../app/functions.php';
require_once __DIR__ . '/../app/sip_helper.php';

$page  = 'numbers';
$title = 'Számkezelés';

$numbers = sip_numbers_read();
$error   = '';
$success = '';
$showForm = false;
$editNum  = null;

// ---- POST handling ----
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';

    if ($action === 'add' || $action === 'edit') {
        $id          = (int)($_POST['id'] ?? 0);
        $sip_number  = trim($_POST['sip_number'] ?? '');
        $sip_password= trim($_POST['sip_password'] ?? '');
        $app_username= trim($_POST['app_username'] ?? '');
        $app_password= trim($_POST['app_password'] ?? '');
        $label       = trim($_POST['label'] ?? '');

        if (!$sip_number || !$sip_password || !$app_username || !$app_password) {
            $error = 'Minden mező kitöltése kötelező.';
            $showForm = true;
            if ($action === 'edit') {
                foreach ($numbers as $n) { if ($n['id'] === $id) { $editNum = $n; break; } }
                $editNum = array_merge($editNum ?? [], compact('sip_number','sip_password','app_username','app_password','label'));
            }
        } elseif (count($numbers) >= 5 && $action === 'add') {
            $error = 'Maximum 5 szám adható hozzá.';
        } else {
            if ($action === 'add') {
                $numbers[] = [
                    'id'           => sip_next_id($numbers),
                    'label'        => $label,
                    'sip_number'   => $sip_number,
                    'sip_password' => $sip_password,
                    'app_username' => $app_username,
                    'app_password' => $app_password,
                    'enabled'      => true,
                ];
            } else {
                foreach ($numbers as &$n) {
                    if ($n['id'] === $id) {
                        $n['label']        = $label;
                        $n['sip_number']   = $sip_number;
                        $n['sip_password'] = $sip_password;
                        $n['app_username'] = $app_username;
                        $n['app_password'] = $app_password;
                        break;
                    }
                }
                unset($n);
            }
            sip_numbers_write($numbers);
            $result = sip_apply($numbers);
            if ($result['ok']) {
                $success = $action === 'add' ? 'Szám hozzáadva és Asterisk újratöltve.' : 'Szám mentve és Asterisk újratöltve.';
            } else {
                $success = ($action === 'add' ? 'Szám hozzáadva' : 'Szám mentve') . ', de az Asterisk újratöltés hibát jelzett.';
            }
            $numbers = sip_numbers_read();
        }
    }

    if ($action === 'toggle') {
        $id = (int)($_POST['id'] ?? 0);
        foreach ($numbers as &$n) {
            if ($n['id'] === $id) { $n['enabled'] = !($n['enabled'] ?? true); break; }
        }
        unset($n);
        sip_numbers_write($numbers);
        $result  = sip_apply($numbers);
        $success = 'Állapot változtatva.' . (!$result['ok'] ? ' (Asterisk reload hiba)' : '');
        $numbers = sip_numbers_read();
    }

    if ($action === 'delete') {
        $id = (int)($_POST['id'] ?? 0);
        $numbers = array_values(array_filter($numbers, fn($n) => $n['id'] !== $id));
        sip_numbers_write($numbers);
        $result  = sip_apply($numbers);
        $success = 'Szám törölve.' . (!$result['ok'] ? ' (Asterisk reload hiba)' : '');
        $numbers = sip_numbers_read();
    }

    if ($action === 'show_form') {
        $showForm = true;
    }
    if ($action === 'show_edit') {
        $id = (int)($_POST['id'] ?? 0);
        foreach ($numbers as $n) { if ($n['id'] === $id) { $editNum = $n; break; } }
        $showForm = true;
    }
}

require __DIR__ . '/_header.php';
?>

<div class="d-flex align-items-center justify-content-between mb-4">
  <h1 class="h4 m-0">Számkezelés</h1>
  <?php if (!$showForm && count($numbers) < 5): ?>
    <form method="post">
      <input type="hidden" name="action" value="show_form">
      <button class="btn btn-sm btn-primary">+ Új szám</button>
    </form>
  <?php endif; ?>
</div>

<?php if ($error): ?>
  <div class="alert alert-danger py-2"><?= e($error) ?></div>
<?php endif; ?>
<?php if ($success): ?>
  <div class="alert alert-success py-2"><?= e($success) ?></div>
<?php endif; ?>

<!-- Add/Edit form -->
<?php if ($showForm): ?>
<div class="card shadow-sm mb-4" id="num-form">
  <div class="card-header py-2 fw-semibold">
    <?= $editNum ? 'Szám szerkesztése' : 'Új szám hozzáadása' ?>
  </div>
  <div class="card-body">
    <form method="post">
      <input type="hidden" name="action" value="<?= $editNum ? 'edit' : 'add' ?>">
      <?php if ($editNum): ?>
        <input type="hidden" name="id" value="<?= (int)$editNum['id'] ?>">
      <?php endif; ?>
      <div class="row g-3">
        <div class="col-md-3">
          <label class="form-label small">SIP szám</label>
          <input type="text" name="sip_number" class="form-control form-control-sm sip-mono"
                 placeholder="pl. 92400004" required
                 value="<?= e($editNum['sip_number'] ?? '') ?>">
        </div>
        <div class="col-md-3">
          <label class="form-label small">SIP jelszó</label>
          <input type="text" name="sip_password" class="form-control form-control-sm sip-mono"
                 required value="<?= e($editNum['sip_password'] ?? '') ?>">
        </div>
        <div class="col-md-2">
          <label class="form-label small">App felhasználó</label>
          <input type="text" name="app_username" class="form-control form-control-sm sip-mono"
                 required value="<?= e($editNum['app_username'] ?? sip_next_app_username($numbers)) ?>">
        </div>
        <div class="col-md-2">
          <label class="form-label small">App jelszó</label>
          <input type="text" name="app_password" class="form-control form-control-sm sip-mono"
                 required value="<?= e($editNum['app_password'] ?? '') ?>">
        </div>
        <div class="col-md-2">
          <label class="form-label small">Megjegyzés (opcionális)</label>
          <input type="text" name="label" class="form-control form-control-sm"
                 placeholder="pl. Porta" value="<?= e($editNum['label'] ?? '') ?>">
        </div>
      </div>
      <div class="mt-3 d-flex gap-2">
        <button type="submit" class="btn btn-sm btn-primary">Mentés &amp; Reload</button>
        <a href="<?= e(base_url('numbers.php')) ?>" class="btn btn-sm btn-outline-secondary">Mégsem</a>
      </div>
    </form>
  </div>
</div>
<?php endif; ?>

<!-- Numbers table -->
<div class="card shadow-sm">
  <div class="card-header py-2 d-flex align-items-center">
    <span class="fw-semibold">Regisztrált számok</span>
    <span class="badge bg-secondary ms-2"><?= count($numbers) ?> / 5</span>
  </div>
  <div class="card-body p-0">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light">
        <tr>
          <th class="ps-3">#</th>
          <th>SIP szám</th>
          <th>App felhasználó</th>
          <th>App jelszó</th>
          <th>Megjegyzés</th>
          <th>Állapot</th>
          <th class="text-end pe-3">Műveletek</th>
        </tr>
      </thead>
      <tbody>
      <?php if (!$numbers): ?>
        <tr><td colspan="7" class="text-muted text-center py-4 small">Még nincs szám felvéve</td></tr>
      <?php else: foreach ($numbers as $i => $num): ?>
        <tr>
          <td class="ps-3 text-muted small"><?= $i + 1 ?></td>
          <td class="sip-mono fw-semibold"><?= e($num['sip_number']) ?></td>
          <td class="sip-mono text-muted"><?= e($num['app_username']) ?></td>
          <td>
            <span class="sip-mono text-muted pw-mask" data-pw="<?= e($num['app_password']) ?>">••••••••</span>
            <button type="button" class="btn btn-link btn-sm p-0 ms-1 eye-btn" title="Megmutat">👁</button>
          </td>
          <td class="text-muted small"><?= e($num['label'] ?: '–') ?></td>
          <td>
            <?php if ($num['enabled'] ?? true): ?>
              <span class="badge bg-success">Aktív</span>
            <?php else: ?>
              <span class="badge bg-secondary">Letiltva</span>
            <?php endif; ?>
          </td>
          <td class="text-end pe-3">
            <div class="d-flex gap-1 justify-content-end">
              <!-- Edit -->
              <form method="post" class="d-inline">
                <input type="hidden" name="action" value="show_edit">
                <input type="hidden" name="id" value="<?= (int)$num['id'] ?>">
                <button class="btn btn-sm btn-outline-primary py-0 px-2">Szerk.</button>
              </form>
              <!-- Toggle -->
              <form method="post" class="d-inline">
                <input type="hidden" name="action" value="toggle">
                <input type="hidden" name="id" value="<?= (int)$num['id'] ?>">
                <button class="btn btn-sm <?= ($num['enabled'] ?? true) ? 'btn-outline-warning' : 'btn-outline-success' ?> py-0 px-2">
                  <?= ($num['enabled'] ?? true) ? 'Letilt' : 'Engedélyez' ?>
                </button>
              </form>
              <!-- Delete -->
              <form method="post" class="d-inline" onsubmit="return confirm('Biztosan törlöd a(z) <?= e(addslashes($num['sip_number'])) ?> számot?')">
                <input type="hidden" name="action" value="delete">
                <input type="hidden" name="id" value="<?= (int)$num['id'] ?>">
                <button class="btn btn-sm btn-outline-danger py-0 px-2">Törlés</button>
              </form>
            </div>
          </td>
        </tr>
      <?php endforeach; endif; ?>
      </tbody>
    </table>
  </div>
</div>

<?php
$extraJs = <<<'JS'
<script>
document.querySelectorAll('.eye-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const span = btn.previousElementSibling;
    if (span.textContent === '••••••••') {
      span.textContent = span.dataset.pw;
      btn.textContent = '🙈';
    } else {
      span.textContent = '••••••••';
      btn.textContent = '👁';
    }
  });
});
</script>
JS;
?>

<?php require __DIR__ . '/_footer.php'; ?>
