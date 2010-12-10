#!/usr/local/bin/perl

$hostname = `/bin/hostname`;

$hour = "11";
$minute = "00";

`( crontab -l ; echo '# Emergency Broken CFengine - this should be deleted by cf.crontabs' ) | crontab`;
`( crontab -l ; echo '$minute $hour * * * /usr/local/sbin/cf.crontabs' ) | crontab`;

