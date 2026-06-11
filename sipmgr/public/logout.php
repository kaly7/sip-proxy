<?php
declare(strict_types=1);
require_once __DIR__ . '/../app/functions.php';
require_once __DIR__ . '/../app/auth.php';
logout();
header('Location: ' . auth_center_url('/logout.php'));
exit;
