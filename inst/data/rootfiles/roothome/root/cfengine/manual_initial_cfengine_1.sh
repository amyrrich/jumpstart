#!/bin/sh

#####################################################################
##
## This is the first half of the manual run of the cfengine scripts 
## for machines that do not have a secondary NIC.
##
## This set of scripts and the scripts they call modify the following 
## files:
##
##   # /etc/hosts
##   # /etc/netmasks
##   # /etc/defaultrouter
##   # /etc/hostname.* files
##   # root's crontab
##
#####################################################################

if [ ! -d "/mnt/jumpstart" ]; then 

  if [ "5.9" = `/bin/uname -r` ] ; then
     ln -s /usr/sbin/dig /usr/local/bin/dig
  fi

  if [ "5.10" = `/bin/uname -r` ] ; then
      ln -s /usr/sbin/dig /usr/local/bin/dig
  fi

  echo "Running network setup for a single NIC."
  /root/cfengine/scripts/clean_hosts-SINGLE_NIC.pl 

  if [ "5.8" = `/bin/uname -r` ] ; then
      echo "Turning on ufslogging."
      /root/cfengine/scripts/enable_ufslogging.pl 
  fi

  echo "Updating the motd."
  /root/cfengine/scripts/patched_motd.pl

  echo "Fixing initial cfengine domain."
  /root/cfengine/scripts/fix_domain.pl

  echo "Running first cfengine."
  echo "Connecting to get the key..."
  /usr/local/sbin/cfagent --file /root/cfengine/get-ppkey-192.168.conf -v
 
  /usr/local/sbin/cfagent --file /root/cfengine/cfengine.conf.initial -v > /root/cfengine/logs/cfengine_run_log.1
  echo "Done running first cfengine - logs in /root/cfengine/logs/"

  echo "Setting up a default 11 am cfengine in case something breaks."
  /root/cfengine/scripts/crontab-cfengine.pl

  echo "Copying the second half of the JumpNet manual install to the startup"
  echo "directory."

  /bin/cp /root/cfengine/scripts/S99manual_initial_cfengine_2 /etc/rc3.d/S99manual_initial_cfengine_2

  echo "Get the NOC to take this machine out of the JumpNet and put on the"
  echo "public network.  Then reboot it."
else
   echo "/mnt/jumpstart still exists, not running cfengine script."
fi
