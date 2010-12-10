#!/bin/sh

###############################################################################
# Functions
###############################################################################

arch=`uname -m`

if [ "X${arch}" = "Xi86pc" ]; then
  proc='i386'
else
  proc='sparc'
fi

#######################################
PrintTestResult () {
#######################################
## print out the result of the test
  if [ ${2} = "failed" ]; then
    tput blink
    tput smul
    tput rev
  fi
  echo "Test for ${1}: ${2}"
  tput sgr0
}

