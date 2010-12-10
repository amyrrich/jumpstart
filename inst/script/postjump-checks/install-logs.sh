#!/bin/sh

## DON'T EDIT THIS SCRIPT ON A JUMPSTART SERVER
## Its home is 
## /local/cfengine/servers/jumpstart/all/inst/script/postjump-checks

PATH=/usr/bin:/usr/sbin
scriptdir=`dirname $0`

# Read in common functions
. ${scriptdir}/funcs.sh


## make sure we have a > 0 length install log
if [ -s /var/sadm/install_data/install_log ]; then
  status=passed
else
  status=failed
fi
PrintTestResult '/var/sadm/install_data/install_log existance' ${status}

## verify that there are no unsuccessful ospkg installs
badpkginstalls=`grep "^Installation of" /var/sadm/install_data/install_log | grep -v successful`
if [ "X${badpkginstalls}" = "X" ]; then
  status=passed
else
  status=failed
fi
PrintTestResult '/var/sadm/install_data/install_log failed packages' ${status}

## verify that there are no unknown packages in the the ospkg file
badpkginstalls=`grep -i "WARNING: Unknown package" /var/sadm/install_data/install_log`
if [ "X${badpkginstalls}" = "X" ]; then
  status=passed
else
  status=failed
fi
PrintTestResult '/var/sadm/install_data/install_log unknown packages' ${status}

## make sure we have a > 0 length patch log
if [ -s /var/sadm/install_data/patch.log ]; then
  status=passed
else
  status=failed
fi
PrintTestResult '/var/sadm/install_data/patch.log existance' ${status}


## make sure we have a > 0 length extpkgs log
if [ -s /var/sadm/install_data/extpkg-install.log ]; then
  status=passed
else
  status=failed
fi
PrintTestResult '/var/sadm/install_data/extpkg-install.log existance' ${status}

## verify that there are no unsuccessful extpkg installs
badpkginstalls=`grep "^Installation of" /var/sadm/install_data/extpkg-install.log | grep -v successful`
if [ "X${badpkginstalls}" = "X" ]; then
  status=passed
else
  status=failed
fi
PrintTestResult '/var/sadm/install_data/extpkg-install.log failed packages' ${status}

## verify that there are no missing extpkgs
badpkginstalls=`grep "not found. Skipping." /var/sadm/install_data/extpkg-install.log | grep -v successful`
if [ "X${badpkginstalls}" = "X" ]; then
  status=passed
else
  status=failed
fi
PrintTestResult '/var/sadm/install_data/extpkg-install.log missing packages' ${status}
