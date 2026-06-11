<?php
declare(strict_types=1);
require_once __DIR__ . '/../app/functions.php';
require_once __DIR__ . '/../app/auth.php';
require_login();
header('Location: ' . base_url('dashboard.php'));
exit;
