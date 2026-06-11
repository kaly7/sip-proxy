<?php
declare(strict_types=1);
require_once __DIR__ . '/../app/auth.php';

if (current_user()) { redirect('dashboard.php'); }

$error  = isset($_GET['err']) && $_GET['err'] === 'noadmin' ? 'Nincs hozzáférési jogosultságod ehhez a modulhoz.' : '';
$return = trim($_GET['return'] ?? '');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $user = trim($_POST['username'] ?? '');
  $pass = $_POST['password'] ?? '';
  if (attempt_login($user, $pass)) {
    $dest = ($return !== '' && strpos($return, '//') === false) ? $return : base_url('dashboard.php');
    header('Location: ' . $dest);
    exit;
  }
  $error = 'Hibás felhasználónév vagy jelszó.';
}
?>
<!doctype html>
<html lang="hu">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Bejelentkezés – SIP Admin</title>
  <link rel="stylesheet" href="<?= e(asset_url('assets/bootstrap/bootstrap.min.css')) ?>">
</head>
<body class="bg-dark">
<div class="d-flex align-items-center justify-content-center" style="min-height:100vh">
  <div class="card shadow-sm" style="width:360px">
    <div class="card-body p-4">
      <h4 class="card-title text-center mb-1">📡 SIP Admin</h4>
      <p class="text-center text-muted small mb-4">Perfect-Phone SIP kezelő</p>

      <?php if ($error): ?>
        <div class="alert alert-danger py-2"><?= e($error) ?></div>
      <?php endif; ?>

      <form method="post">
        <div class="mb-3">
          <label class="form-label">Felhasználónév</label>
          <input type="text" name="username" class="form-control" autofocus autocomplete="username" required>
        </div>
        <div class="mb-3">
          <label class="form-label">Jelszó</label>
          <input type="password" name="password" class="form-control" autocomplete="current-password" required>
        </div>
        <button type="submit" class="btn btn-dark w-100">Bejelentkezés</button>
      </form>
    </div>
  </div>
</div>
<script src="<?= e(asset_url('assets/bootstrap/bootstrap.bundle.min.js')) ?>"></script>
</body>
</html>
