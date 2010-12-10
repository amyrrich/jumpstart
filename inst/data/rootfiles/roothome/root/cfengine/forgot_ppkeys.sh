#!/bin/sh

cd /root/cfengine/
/usr/local/sbin/cfagent -f./get-192.168.conf
sleep 5
/usr/local/sbin/cfagent -f./get-ppkey-10.11.conf
sleep 5
/usr/local/sbin/cfagent -v -f./cfengine.conf.initial > /root/cfengine/logs/cfengine.conf.forgot-ppkeys
sleep 5
/usr/local/sbin/cf.force
sleep 70
/usr/local/sbin/cf.force
