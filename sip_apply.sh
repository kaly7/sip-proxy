#!/bin/bash
# SIP konfig alkalmazó script — www-data futtatja sudo-val
set -e
cp /tmp/sip_new_pjsip.conf      /etc/asterisk/pjsip.conf
cp /tmp/sip_new_extensions.conf /etc/asterisk/extensions.conf
/usr/sbin/asterisk -rx "module reload res_pjsip"   2>/dev/null
/usr/sbin/asterisk -rx "dialplan reload"           2>/dev/null
echo "OK"
