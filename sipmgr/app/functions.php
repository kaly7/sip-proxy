<?php
declare(strict_types=1);

require_once __DIR__ . '/db.php';

function base_url(string $path = ''): string {
  $bp = rtrim((string)config()['base_path'], '/');
  $p  = ltrim($path, '/');
  return $bp . '/' . $p;
}

function asset_url(string $path): string { return base_url($path); }

function e(?string $s): string {
  return htmlspecialchars((string)$s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function start_session(): void {
  if (session_status() !== PHP_SESSION_ACTIVE) {
    session_name((string)config()['session_name']);
    session_set_cookie_params([
      'lifetime' => 0,
      'path'     => '/',
      'domain'   => '',
      'secure'   => false,
      'httponly' => true,
      'samesite' => 'Lax',
    ]);
    session_start();
  }
}

function flash_set(string $k, string $v): void { start_session(); $_SESSION['_flash'][$k] = $v; }
function flash_get(string $k): ?string {
  start_session();
  if (!isset($_SESSION['_flash'][$k])) return null;
  $v = (string)$_SESSION['_flash'][$k];
  unset($_SESSION['_flash'][$k]);
  return $v;
}

function csrf_token(): string {
  start_session();
  if (empty($_SESSION['_csrf'])) $_SESSION['_csrf'] = bin2hex(random_bytes(16));
  return (string)$_SESSION['_csrf'];
}

function verify_csrf(): void {
  start_session();
  $ok = isset($_POST['_csrf'], $_SESSION['_csrf'])
     && hash_equals((string)$_SESSION['_csrf'], (string)$_POST['_csrf']);
  if (!$ok) { http_response_code(400); exit('CSRF hiba'); }
}

function redirect(string $path): void { header('Location: ' . base_url($path)); exit; }

function _host_no_port(): string {
  $h = $_SERVER['HTTP_HOST'] ?? ($_SERVER['SERVER_NAME'] ?? 'localhost');
  return explode(':', $h)[0];
}

function cfg(string $key, $default = null) {
  $parts = explode('.', $key);
  $val   = config();
  foreach ($parts as $p) {
    if (!is_array($val) || !array_key_exists($p, $val)) return $default;
    $val = $val[$p];
  }
  return $val;
}

// Kalória számítás: food_item + mennyiség alapján
function calc_calories(int $calories_per_100g, int $amount_g): int {
  return (int)round($calories_per_100g * $amount_g / 100);
}

// BMI számítás
function calc_bmi(float $weight_kg, int $height_cm): float {
  if ($height_cm <= 0) return 0.0;
  $h = $height_cm / 100;
  return round($weight_kg / ($h * $h), 1);
}

// BMI kategória
function bmi_category(float $bmi): string {
  return match (true) {
    $bmi < 18.5 => 'Sovány',
    $bmi < 25.0 => 'Normál',
    $bmi < 30.0 => 'Túlsúlyos',
    default     => 'Obez',
  };
}

// Étkezési időpont magyar neve
function meal_label(string $meal_type): string {
  return match ($meal_type) {
    'reggeli'  => 'Reggeli',
    'tizorai'  => 'Tíz órai',
    'ebed'     => 'Ebéd',
    'uzsonna'  => 'Uzsonna',
    'vacsora'  => 'Vacsora',
    default    => ucfirst($meal_type),
  };
}

// Mai dátum
function today(): string { return date('Y-m-d'); }

// Étel ikon étkezés szerint
function meal_icon(string $meal_type): string {
  return match ($meal_type) {
    'reggeli'  => '☀️',
    'tizorai'  => '🍎',
    'ebed'     => '🍽️',
    'uzsonna'  => '☕',
    'vacsora'  => '🌙',
    default    => '🍴',
  };
}

// Haladás szín Bootstrap szerint (0-100%)
function progress_color(float $pct): string {
  return match (true) {
    $pct <= 60  => 'success',
    $pct <= 90  => 'warning',
    $pct <= 110 => 'danger',
    default     => 'dark',
  };
}

// Egyszerű normalize: kisbetű + ékezetek nélkül (kereséshez)
function normalize_str(string $s): string {
  $s = mb_strtolower($s, 'UTF-8');
  $from = ['á','é','í','ó','ö','ő','ú','ü','ű','Á','É','Í','Ó','Ö','Ő','Ú','Ü','Ű'];
  $to   = ['a','e','i','o','o','o','u','u','u','a','e','i','o','o','o','u','u','u'];
  return str_replace($from, $to, $s);
}

require_once __DIR__ . '/auth.php';
