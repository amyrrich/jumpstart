#!/bin/sh

## DON'T EDIT THIS SCRIPT ON A JUMPSTART SERVER
## Its home is 
## /local/cfengine/servers/jumpstart/all/inst/script/postjump-checks

PATH=/usr/bin:/usr/sbin
COLUMNS=`tput cols`
LINES=`tput lines`
export PATH COLUMNS LINES
scriptdir=`dirname $0`

# Read in common functions
. ${scriptdir}/funcs.sh

## GetEepromListing - read the variable from eeprom
GetEepromListing () {
  result=`eeprom ${1}`
}

## CheckTestResult

CheckTestResult () {
  if [ "X${result}" = "X${1}=true" ]; then
    status="passed"
  else
    status="failed"
  fi
}

## main

if [ "X${proc}" = "Xi386" ]; then
  # only check local-mac-address? on i386 machines
  GetEepromListing local-mac-address?
  CheckTestResult local-mac-address?
  PrintTestResult local-mac-address? ${status}

else
  ## check eeprom variables extensively for sparc

  ## these should all be set to true
  for testvar in auto-boot? local-mac-address? use-nvramrc?; do 
    GetEepromListing ${testvar}
    CheckTestResult ${testvar}
    PrintTestResult ${testvar} ${status}
  done

  ## diag-level should be min
  GetEepromListing diag-level
  if [ "X${result}" = "Xdiag-level=min" ]; then
    status="passed"
  else
    status="failed"
  fi
  PrintTestResult 'diag-level=min' ${status}


  ## nvramrc should contain an entry for jumpnet
  GetEepromListing nvramrc
  if [ "X`echo ${result} | sed -n '/devalias jumpnet/p'`" = "X" ]; then
    status="failed"
  else
    status="passed"
  fi
  PrintTestResult 'jumpnet devalias' ${status}
  
  if [ "X`echo ${result} | sed -n '/devalias mirror1/p'`" = "X" ]; then
    status="failed"
  else
    status="passed"
  fi
  PrintTestResult 'mirror1 devalias' ${status}


  ## diag-device should be set to jumpnet
  GetEepromListing diag-device
  if [ "X${result}" = "Xdiag-device=jumpnet:dhcp" ]; then
    status="passed"
  else
    status="failed"
  fi
  PrintTestResult 'diag-device=jumpnet:dhcp' ${status}

  ## boot-device should be set to "disk mirror1"
  GetEepromListing boot-device
  if [ "X`echo ${result} | awk '{print $2}'`" = "Xmirror1" ]; then
    status="passed"
  else
    status="failed"
  fi
  PrintTestResult 'boot-device contains mirror1' ${status}
fi  
