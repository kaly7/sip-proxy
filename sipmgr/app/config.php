<?php
return [
    'module_slug'       => 'sipmgr',
    'app_name'          => 'SIP Admin',
    'base_path'         => '',
    'session_name'      => 'SIPMGR_SESSID',
    'port'              => 9452,
    'auth_center_port'  => 90,

    // 'auth_center' = SSO az auth_center modulon át (eredeti viselkedés)
    // 'standalone'  = helyi admin felhasználó, DB nélkül
    'auth_mode'       => 'auth_center',
    'admin_user'      => 'admin',
    'admin_pass_hash' => '',  // php -r "echo password_hash('JELSZO', PASSWORD_DEFAULT);"
];
