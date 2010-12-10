#!/bin/sh

###############################################################################
# This set of functions is used in both js-tab:/inst/jumpstart/post and
# cfd:/local/cfengine/patches/scripts
# please try to keep them ocnsistent
###############################################################################

###############################################################################
## Functions to aid in patching with live upgrade and pca
###############################################################################

PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/sbin
export PATH

###############################################################################
## Check to see what's mounted on the specified mount point.
## If there is a mount, return to the calling script with a value of 1.
## and store the name of the mountpoint(s) in ${MNTFS}
##
## Function requires that a mount point is passed to it.
## Function globally sets MNTFS
###############################################################################

chk_mntpt () {

  MNTFS=''
  MNTPT=$1

  MNTFS=`df -k | grep " ${MNTPT}$" | awk '{print $6}'`
  if [ "X${MNTFS}" != 'X' ]; then
     return 1
  fi
}


###############################################################################
## Make sure there are no inactive BEs.  If there are, print an error and exit.
##
## Function globally sets INACTIVE_BE
###############################################################################


chk_inactive_be () {

  INACTIVE_BE=''
  INACTIVE_BE=`lustatus  2>&1 | awk '{if ($3 ~ /no/) print $1}'`
  if [ "X${INACTIVE_BE}" != 'X' ]; then
    echo "Inactive BE ${INACTIVE_BE} found."
    echo "Please run ludelete ${INACTIVE_BE} and re-run this script."
    exit 1
  fi
}


###############################################################################
## Construct the name of the new boot environment based on the OS name,
## revision of the OS, Solaris release version, the current date, and the type
## of BE (jumpstart, JS or patch, RC fed in from the calling script)
##
## NOTE: A BE name must not exceed 30 characters in length and must consist
## only of alphanumeric characters and other ASCII characters that are not
## special to the Unix shell.
##
## Function requires that OSREV is set and a BE type (JS or RC) is passed to it.
## Function globally sets NEW_BE, CDREV, CURDATE, NEW_BE.
###############################################################################

name_new_be () {
  BE_TYPE=$1
  CURDATE=`/bin/date "+%Y.%m.%d-%H.%M"`

  NEW_BE=''
  CDREV=`awk '/Solaris/ {print $3}' /etc/release | sed 's/\//\./'`

  NEW_BE="${OSREV}_${CDREV}-${CURDATE}-${BE_TYPE}"
}

###############################################################################
## Check and make sure /lu/root and /lu/var aren't mounted;
## if they are, unmount them and remove them from /etc/vfstab
##
## Function globally sets FS, FSLINE, MNTFS
###############################################################################

prep_lu_mnts () {
  cp /etc/vfstab /etc/vfstab.backup.$$

  for FS in /lu/root /lu/var ; do
    FSLINE=''
    MNTFS=''

    chk_mntpt ${FS}
    if [ "X${MNTFS}" = "X${FS}" ]; then
      umount ${FS}
    fi
    
    FSLINE=`grep "^/dev.*${FS}" /etc/vfstab`
    MNTFS=`echo ${FSLINE} | awk '{print $3}'`
    if [ "X${MNTFS}" = "X${FS}" ]; then
      sed -e "s:^${FSLINE}$:# ${FSLINE}:" < /etc/vfstab > /etc/vfstab.$$
      if [ -s /etc/vfstab.$$ ]; then
        mv /etc/vfstab.$$ /etc/vfstab
      else
        echo "Commenting out entries in /etc/vfstab failed, exiting"
        rm -f /etc/vfstab.$$
        exit 1
      fi
    fi
  done
}



###############################################################################
## Check to see if any BEs are configured.  If not, set NOLU to 1.
## 
## Function globally sets NOLU and LUCUR
###############################################################################

chk_default_be () {

  NOLU=0
  LUCUR=''
  LUCUR=`lucurr 2>&1 | awk '{print $1}' |sort -u`

  if [ "X${LUCUR}" = 'XERROR:' ]; then
    NOLU=1
  fi
}


###############################################################################
## Determine which root/var pair we're currently using, then determine the new
## root/var pair.
##
## NOTE: Root is either on 0/1 or 5, var is on 3 or 6.
##
## Function requires that OSREV and CURROOT are set
## Function globally sets NEWROOT, NEWVAR, CURROOTSLICE, MIRROR_PREFIX
###############################################################################

set_lu_partitions () {

  NEWROOT=''
  NEWVAR=''
  CURROOTSLICE=''
  MIRROR_PREFIX=''

  # first check to see if we're on a cluster node that numbers the local
  # disks as /dev/md/dsk/d<nodenumber><slice>0
  if [ `echo ${CURROOT} | wc -m` -gt 16 ]; then
    MIRROR_PREFIX=`echo ${CURROOT} | sed -e 's#/dev/md/dsk/d\([0-9]\).*#\1#'`
  fi

  case "${CURROOT}" in
    /dev/md/dsk/d0 | /dev/md/dsk/d10 | /dev/md/dsk/d[1-9]10 )
      # it's a metadevice on the jumpstarted slice
      # it may or may not be a cluster node
      NEWROOT=/dev/md/dsk/d${MIRROR_PREFIX}50
      NEWVAR=/dev/md/dsk/d${MIRROR_PREFIX}60
      ;;

    /dev/md/dsk/d50 |/dev/md/dsk/d[1-9]50 )
      # it's a metadevice on the non-jumpstart slice
      if [ "X${OSREV}" = 'X5.9' ]; then
        # it's solaris 9 and may or may not be a cluster node
        NEWROOT=/dev/md/dsk/d${MIRROR_PREFIX}10
      elif [ "X${MIRROR_PREFIX}" = 'X' ]; then
        # it's solaris 10 or greater and not a cluster node
        NEWROOT=/dev/md/dsk/d0
      else
        # it's solaris 10 or greater and a cluster node
        NEWROOT=/dev/md/dsk/d${MIRROR_PREFIX}00
      fi
      NEWVAR=/dev/md/dsk/d${MIRROR_PREFIX}30
      ;;

    /dev/dsk* )
      # we're not using a metadevice
      NEWROOT=`echo ${CURROOT} | sed -e 's#\(/dev/dsk/.*s\).*#\1#'`
      CURROOTSLICE=`echo ${CURROOT} | sed -e 's/.*s\(.*\)/\1/'`

      if [ "X${CURROOTSLICE}" = "X0" ] || [ "X${CURROOTSLICE}" = 'X1' ]; then
        NEWVAR="${NEWROOT}6"
        NEWROOT="${NEWROOT}5"
      elif [ "X${CURROOTSLICE}" = "X5" ] && [ "X${OSREV}" = 'X5.9' ]; then
        NEWVAR="${NEWROOT}3"
        NEWROOT="${NEWROOT}1"
      else
        NEWVAR="${NEWROOT}3"
        NEWROOT="${NEWROOT}0"
      fi
      ;;

    *) 
      echo "The root partition is in an unexpected location: ${CURROOT}"
      exit 1
      ;;
  esac
}

###############################################################################
## Determine os, version, architecture, and processor type of the machine
##
## Function requires that a variables CURROOT is set
## Function globally sets OS, OSREV, ARCH, and PROC
###############################################################################

douname () {

  set -- `uname -srmp`
  if [ $# -eq 4 -a ! -z "$4" ]; then
    OS="$1"
    OSREV="$2"
    ARCH="$3"
    PROC="$4"
  else
    echo "uname -srmp call failed, output: $*" 
    exit 1
  fi
}
