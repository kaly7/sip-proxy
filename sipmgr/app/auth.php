<?php
declare(strict_types=1);

require_once __DIR__ . '/functions.php';

function authcfg(): array {
  return [
    'dsn'  => 'mysql:host=127.0.0.1;dbname=auth_db;charset=utf8mb4',
    'user' => 'ppdb',
    'pass' => 'abrakadabra',
  ];
}

function auth_pdo(): PDO {
  static $pdo = null;
  if ($pdo instanceof PDO) return $pdo;
  $c = authcfg();
  $pdo = new PDO($c['dsn'], $c['user'], $c['pass'], [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
  return $pdo;
}

function _module_role(PDO $pdo, int $userId, string $moduleKey): ?string {
  $st = $pdo->prepare("
    SELECT r.role_key
    FROM user_module_roles umr
    JOIN modules m ON m.id = umr.module_id
    JOIN roles r   ON r.id = umr.role_id
    WHERE umr.user_id = ? AND m.module_key = ? AND m.is_enabled = 1
    LIMIT 1
  ");
  $st->execute([$userId, $moduleKey]);
  $rk = $st->fetchColumn();
  if (!$rk) return null;
  return match ((string)$rk) {
    'admin' => 'admin',
    'user'  => 'user',
    default => 'user',
  };
}

function _is_standalone(): bool {
  return (config()['auth_mode'] ?? 'auth_center') === 'standalone';
}

function try_sso_from_auth_center(): void {
  if (_is_standalone()) return;
  // Megosztott FEJLESZTES_SESSID session — auth_center user_id-ja közvetlenül elérhető.
  // $_SESSION['user'] kulcsot NEM olvassuk: más modulok (pl. fitnessmgr) is írnak bele,
  // esetleg 'user' role-lal, ami logout-ot váltana ki. Saját '_sipmgr_user' kulcsot használunk.
  $uid = !empty($_SESSION['user_id']) ? (int)$_SESSION['user_id'] : null;
  if (!$uid) return;

  try {
    $pdo  = auth_pdo();
    $role = _module_role($pdo, $uid, (string)config()['module_slug']);
    if (!$role) return;

    $st = $pdo->prepare("SELECT username, full_name, is_active FROM users WHERE id=? LIMIT 1");
    $st->execute([$uid]);
    $u = $st->fetch();
    if (!$u || !(int)($u['is_active'] ?? 0)) return;

    $_SESSION['_sipmgr_user'] = [
      'id'       => $uid,
      'username' => (string)($u['username'] ?? ''),
      'name'     => (string)($u['full_name'] ?? $u['username'] ?? ''),
      'role'     => $role,
    ];
  } catch (Throwable $e) {}
}

function attempt_login(string $username, string $password): bool {
  start_session();
  $username = trim($username);
  if ($username === '' || $password === '') return false;

  if (_is_standalone()) {
    $cfg = config();
    if ($username !== ($cfg['admin_user'] ?? '')) return false;
    if (!password_verify($password, (string)($cfg['admin_pass_hash'] ?? ''))) return false;
    $_SESSION['_sipmgr_user'] = ['id' => 1, 'username' => $username, 'name' => $username, 'role' => 'admin'];
    return true;
  }

  try {
    $pdo = auth_pdo();
    $st  = $pdo->prepare("SELECT id, username, full_name, password_hash, is_active FROM users WHERE username=? LIMIT 1");
    $st->execute([$username]);
    $u = $st->fetch();
    if (!$u || !(int)($u['is_active'] ?? 0)) return false;
    if (!password_verify($password, (string)$u['password_hash'])) return false;

    $role = _module_role($pdo, (int)$u['id'], (string)config()['module_slug']) ?? 'user';

    $_SESSION['_sipmgr_user'] = [
      'id'       => (int)$u['id'],
      'username' => (string)$u['username'],
      'name'     => (string)($u['full_name'] ?? $u['username']),
      'role'     => $role,
    ];
    return true;
  } catch (Throwable $e) { return false; }
}

function logout(): void {
  start_session();
  unset($_SESSION['_sipmgr_user']);
}

function current_user(): ?array {
  start_session();
  if (empty($_SESSION['_sipmgr_user']) || !is_array($_SESSION['_sipmgr_user'])) {
    try_sso_from_auth_center();
  }
  return (isset($_SESSION['_sipmgr_user']) && is_array($_SESSION['_sipmgr_user']))
    ? $_SESSION['_sipmgr_user'] : null;
}

function require_login(): void {
  if (!current_user()) {
    $return = urlencode($_SERVER['REQUEST_URI'] ?? '/');
    header('Location: ' . base_url("login.php?return={$return}"));
    exit;
  }
}

function auth_center_url(string $path = '/'): string {
  $host = _host_no_port();
  $port = (int)(config()['auth_center_port'] ?? 90);
  return 'http://' . $host . ':' . $port . $path;
}

function require_admin(): void {
  $u = current_user();
  if (!$u || ($u['role'] ?? '') !== 'admin') {
    if (_is_standalone()) {
      header('Location: ' . base_url('login.php?err=noadmin'));
    } else {
      header('Location: ' . auth_center_url('/'));
    }
    exit;
  }
}
