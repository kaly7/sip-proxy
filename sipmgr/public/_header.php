<?php
require_once __DIR__ . '/../app/auth.php';
require_admin();
$u     = current_user();
$title = $title ?? 'SIP Admin';
$page  = $page  ?? '';
?>
<!doctype html>
<html lang="hu">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= e($title) ?> – SIP Admin</title>
  <link rel="stylesheet" href="<?= e(asset_url('assets/bootstrap/bootstrap.min.css')) ?>">
  <link rel="stylesheet" href="<?= e(asset_url('assets/app.css')) ?>">
  <style>
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;600&display=swap');
    .sip-mono { font-family: 'JetBrains Mono', monospace; font-size: .82rem; }
    .pulse { display:inline-block; width:9px; height:9px; border-radius:50%; background:#198754;
             box-shadow:0 0 0 0 rgba(25,135,84,.4); animation:pulse-anim 1.8s infinite; vertical-align:middle; }
    .pulse.offline { background:#dc3545; box-shadow:none; animation:none; }
    @keyframes pulse-anim {
      0%   { box-shadow:0 0 0 0   rgba(25,135,84,.4) }
      70%  { box-shadow:0 0 0 8px rgba(25,135,84,0)  }
      100% { box-shadow:0 0 0 0   rgba(25,135,84,0)  }
    }
  </style>
</head>
<body>

<nav class="navbar navbar-expand-lg navbar-light bg-light border-bottom mb-4">
  <div class="container">
    <a class="navbar-brand fw-bold" href="<?= e(base_url('dashboard.php')) ?>">
      📡 SIP Admin
    </a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#nav">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div id="nav" class="collapse navbar-collapse">
      <ul class="navbar-nav me-auto mb-2 mb-lg-0">
        <li class="nav-item">
          <a class="nav-link <?= $page === 'dashboard' ? 'active fw-semibold' : '' ?>"
             href="<?= e(base_url('dashboard.php')) ?>">Dashboard</a>
        </li>
        <li class="nav-item">
          <a class="nav-link <?= $page === 'log' ? 'active fw-semibold' : '' ?>"
             href="<?= e(base_url('log.php')) ?>">Napló</a>
        </li>
        <li class="nav-item">
          <a class="nav-link <?= $page === 'numbers' ? 'active fw-semibold' : '' ?>"
             href="<?= e(base_url('numbers.php')) ?>">Számok</a>
        </li>
      </ul>
      <div class="d-flex align-items-center gap-2">
        <span class="text-muted small"><?= e($u['name'] ?? '') ?></span>
        <a class="btn btn-outline-secondary btn-sm" href="<?= e(auth_center_url('/apps.php')) ?>">Rendszerek</a>
        <a class="btn btn-outline-secondary btn-sm" href="<?= e(auth_center_url('/logout.php')) ?>">Kilépés</a>
      </div>
    </div>
  </div>
</nav>

<div class="container pb-4">

<?php
$_ok  = flash_get('ok');
$_err = flash_get('err');
if ($_ok):  ?><div class="alert alert-success alert-dismissible"><button type="button" class="btn-close" data-bs-dismiss="alert"></button><?= e($_ok) ?></div><?php endif;
if ($_err): ?><div class="alert alert-danger  alert-dismissible"><button type="button" class="btn-close" data-bs-dismiss="alert"></button><?= e($_err) ?></div><?php endif;
