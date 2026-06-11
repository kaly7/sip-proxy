<?php
// IDEIGLENES DEBUG - törlendő
session_name('FEJLESZTES_SESSID');
session_start();
header('Content-Type: text/plain');
echo "COOKIES:\n";
foreach ($_COOKIE as $k => $v) echo "  $k = $v\n";
echo "\nSESSION:\n";
print_r($_SESSION);
