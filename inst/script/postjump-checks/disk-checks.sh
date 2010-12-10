#!/bin/sh

## DON'T EDIT THIS SCRIPT ON A JUMPSTART SERVER
## Its home is 
## /local/cfengine/servers/jumpstart/all/inst/script/postjump-checks

PATH=/usr/bin:/usr/sbin

# Read in common functions
scriptdir=`dirname $0`

. ${scriptdir}/funcs.sh


swapdev=`awk '/^swap/ {next;} /swap/ {print $1}' /etc/vfstab`
dumpdev=`awk -F= '/^DUMPADM_DEVICE/ {print $2}' /etc/dumpadm.conf`
dumpadmon=`awk -F= '/^DUMPADM_ENABLE/ {print $2}' /etc/dumpadm.conf`
platform=`uname -m`
osver=`uname -r`
memsize=`/usr/local/bin/memconf| awk '/^total memory/ {print $4}' | sed 's/MB//'`
swapsize=`swap -l | grep ${swapdev} | awk '{print $4}'`
swapsize=`expr ${swapsize} / 2048`
diskdevs=`grep '^/dev\/' /etc/vfstab|grep -v /dev/md`
mdrootflag=`grep '^set md:mirrored_root_flag=1' /etc/system`

## Make sure that every /dev entry in /etc/vfstab is a metadevice
if [ "X${diskdevs}" = "X" ]; then
  status=passed
else
  status=failed
fi
PrintTestResult 'mirroring of all disks in /etc/vfstab' ${status}

## Make sure that all mirrors listed in /etc/vfstab have submirrors
status=passed
for mdevice in `awk '/^\/dev\/md\// {print $1}' /etc/vfstab` ; do
  numsubmirrors=`metastat ${mdevice} | grep "Submirror of" | wc -l`
  if [ ${numsubmirrors} -lt 2 ]; then
    status=failed
  fi
done

PrintTestResult 'each mirror having at least two submirrors' ${status}


## Make sure that md:mirrored_root_flag=1 is set in /etc/system
if [ "X${mdrootflag}" = "X" ]; then
  status=failed
else
  status=passed
fi
PrintTestResult 'md:mirrored_root_flag=1 setting in /etc/system' ${status}


## Make sure that the dump device is set to whatever swap is
if [ "X${swapdev}" = "X${dumpdev}" -o "X${dumpdev}" = "Xswap" ]; then
  status=passed
else
  status=failed
fi
PrintTestResult 'dump device set to swap' ${status}


## Make sure that dumpadm is turned on
if [ "X${dumpadmon}" = "X" ]; then
  status=failed
else
  status=passed
fi
PrintTestResult 'dumpdev enabled' ${status}


## Make sure savecore is enabled
case "${osver}" in
  5.8|5.9)

    if [ "X`grep '/usr/bin/savecore -m -f $DUMPADM_DEVICE' /etc/rc2.d/S74syslog" = "X" ]; then
      status=failed
    else
      status=passed
    fi
  ;;

  5.10)

    if [ "X`svcs -l svc:/system/dumpadm:default|grep enabled`" = "Xenabled	true" ]; then
      status=failed
    else
      status=passed
    fi

  ;;

  *)
    echo "SunOS version ${osver} not supported for this test."
    status=failed
  ;;

esac

PrintTestResult 'savecore enabled' ${status}


## Make sure the savecore init file exists
case "${osver}" in
  5.8|5.9)

    if [ -s /etc/rc2.d/S75savecore ]; then
      status=passed
    else
      status=failed
    fi
    PrintTestResult 'existance of non zero /etc/rc2.d/S75savecore' ${status}
  ;;

esac


## Make sure that swap size is equal to or greater than memsize
if [ ${memsize} -ge ${swapsize} ]; then
  status=failed
else
  status=passed
fi
PrintTestResult 'swap size greater than memory size' ${status}
