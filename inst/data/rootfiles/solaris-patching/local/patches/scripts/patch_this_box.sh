#!/bin/sh

######
## This script runs after you've unzipped the patch cluster and want to
## start applying patches to a new BE.
##
## It does check to see if LiveUpgrade has been set up, and sets it up if
## it hasn't.
######

PATH=/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/sbin
export PATH

date

# import functions

scriptdir=`dirname $0`

. ${scriptdir}/lu-funcs.sh

# Obtain information about the type of machine and OS
douname

# first make sure that the diag-switch? is set to false, otherwise luactivate
# fails on the T2000s

if [ "X${PROC}" = 'Xsparc' ]; then
  /usr/sbin/eeprom 'diag-switch?=false'
fi

# create the pca directory so there's a place to download patches
mkdir -p /local/patches/pca

# Location of the patchdiag.xref file
XREFDIR="/local/patches/os/${OS}-${OSREV}-${PROC}"

if [ ! -s "${XREFDIR}/patchdiag.xref" ]; then
  echo
  echo "ERROR!"
  echo
  echo " patchdiag.xref file ${XREFDIR}/patchdiag.xref"
  echo " is missing or zero size. Check"
  echo " cfd.my.domain:/local/cfengine/patches/os/${OS}-${OSREV}-${PROC}/patchdiag.xref"
  echo " and re-run /usr/local/sbin/cf.monthlypatches"
  echo
  echo "Aborting."
  echo
  exit 1
fi

# Check to make sure nothing's mounted on /local/patches/patchmnt. If so, exit
mkdir -p /local/patches/patchmnt

chk_mntpt /local/patches/patchmnt
if [ "X${MNTFS}" != 'X' ]; then
  echo
  echo "ERROR!"
  echo
  echo " ${MNTFS} is mounted on /local/patches/patchmnt."
  echo " Please umount ${MNTFS} and then rerun this script."
  echo 
  echo "Aborting."
  echo
  exit 1
fi

# Make sure there are no inactive BEs.  If there are, print an error and exit.
chk_inactive_be

# generate a name for the new be
name_new_be RC
if [ "X${NEW_BE}" != 'X' ]; then
  NEWBE=${NEW_BE}
fi


# Check to see if we're using ZFS or UFS for the root filesystem
POOL=`/bin/df -k / | awk -F/ '/ROOT/ {print $1}'`

if [ "X${POOL}" = 'X' ]; then
  # Our root filesystem is on a UFS partition

  # make sure the /lu partitions are umounted and commented out of /etc/vfstab
  prep_lu_mnts

  # Determine the current root and var partitions
  CURROOT=`/bin/df -k / | awk '/^\/dev/ {print $1}'`
  CURVAR=`/bin/df -k /var | awk '/^\/dev/ {print $1}'`

  # Check to see if there are any BEs configured at all
  chk_default_be

  # If not, determine the name for the default BE
  if [ "X${NOLU}" = 'X1' ]; then
    name_new_be JS
    if [ "X${NEW_BE}" != 'X' ]; then
      CURBE=${NEW_BE}
    fi
  fi

  # Determine what the new BE partitions for / and /var should be
  set_lu_partitions

  # create the new boot environment
  if [ -x /etc/lib/lu/lubootdevice ]; then
    LUROOT=`/etc/lib/lu/lubootdevice`
  elif [ -x /etc/lib/lu/lurootdev ]; then
    LUROOT=`/etc/lib/lu/lurootdev`
  else
    echo "Can not determine current root device"
    exit 1
  fi

  # perform the lucreate
  if [ ${NOLU} -eq 1 ]; then
    echo "lucreate -C ${LUROOT} -c ${CURBE} -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n ${NEWBE}"
    lucreate -C ${LUROOT} -c "${CURBE}" -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n "${NEWBE}" || exit 1
  else
    echo "lucreate -C - -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n ${NEWBE}"
    lucreate -m /:${NEWROOT}:ufs -m /var:${NEWVAR}:ufs -n "${NEWBE}" || exit 1
  fi
else
  # We're on a ZFS partition and ZFS has already set up an inital boot env
  lucreate -n ${NEWBE} -p ${POOL}
fi
  
date

# mount the new boot environment and patch it.
# any other modifications that need to happen to the new BE should go inside
# this if block.

MNTBE=`lumount ${NEWBE}`
if [ "X${MNTBE}" != 'X' ]; then
  # Set the location of the current /var in the init script used to clean up
  # after booting off of the new BE and put that init script in place

  chmod 755 ${MNTBE}/var
  sed "s](REPLACEMESTUB)]${CURVAR}]" < ${scriptdir}/lupostreboot > ${MNTBE}/etc/rc2.d/S45lupostreboot
  chmod 755 ${MNTBE}/etc/rc2.d/S45lupostreboot

  # perform the patching with pca
  /usr/local/sbin/pca -X ${XREFDIR} -y -R ${MNTBE} -i 

  # Print out all the patches that didn't get applied
  echo "Checking to see if there are any patches that did not get applied."
  /usr/local/sbin/pca -X ${XREFDIR} -y -R ${MNTBE} -l

  # update the MOTD
  LONGDATE=`/bin/date "+%e %B %Y"`
  sed -e "s/\(.*patched \).*/\1${LONGDATE}/" < /etc/motd > ${MNTBE}/etc/motd

  # explicitly set permissions on the new var mount point since live upgrade
  # sets it to 700 in Solaris 9 (as of 09/16/2008)
  umount /.alt.${NEWBE}/var &&  chmod 755 /.alt.${NEWBE}/var

  # umount the new be and make it active
  luumount ${NEWBE} && luactivate -s ${NEWBE}
  lustatus

  echo "To boot off the new boot environment, MAKE SURE that /usr/bin is in your"
  echo "PATH before /usr/local/bin (you can su - root to achieve this) and then run:"
  echo "init 6"
else
  echo
  echo "ERROR!"
  echo
  echo " Unable to mount ${NEWBE}"
  echo
  echo "Aborting."
  echo
  exit 1
fi

date

