#!/bin/sh

# set up some initial variables

# The name of our global jumpstart domain
jsdomain='jumpnet.my.domain'
# The location of the boot files
tftpdir='/tftpboot'
# The location of the grub menu
grubmenu="${tftpdir}/boot/grub/menu.lst"
# Location of the base install directory
instbase='/inst'
# Location of the jumpstart config directory
jsbase="${instbase}/jumpstart"
# Location of the jumpstart data directory
datadir="${instbase}/data"

if [ "X${arch}" = "Xi86pc" ]; then
  proc='i386'
else
  proc='sparc'
fi

# Location of extpkgs based on arch and osrev
extpkgsdir="${datadir}/extpkgs/SunOS-5.${osrev}-${proc}"

# The directory containing the included dhcpd config files
dhcpddir='/usr/local/etc/dhcpd'
#dhcpddir='/tmp/dhcpd'
# dhcpd main configuration file
dhcpd_main_config="${dhcpddir}.conf"
# The dhcpd config file the machine should be in based on arch and osrev
dhcpdfile="${dhcpddir}/sol${osrev}-${arch}-dhcpd.conf"
# dhcpd init script
dhcpd_init='/etc/init.d/iscdhcpd'


###############################################################################
# Functions
###############################################################################

#######################################
PrintError () {
#######################################
# input is error text

  if [ "X${DEBUG}" = X ]; then
    tput blink
    tput smul
    tput rev
  fi
  echo "${1}"
  if [ "X${DEBUG}" = X ]; then
    tput sgr0
  fi
}


#######################################
check_diff_lines () {
#######################################
# input is a file name and the number of lines difference that's acceptable
# between the filename and filename.$$

  file=${1}
  maxdifflines=${2}

  if [ -f ${file} ] && [ -f ${file}.$$ ]; then
    # check the difference between the number of lines in the old and new
    # files.  If it's greater than ${difflines} then abort the changes
    nlines=`wc -l ${file}.$$ | awk {'print $1'}`
    olines=`wc -l ${file} | awk {'print $1'}`
    if [ -n ${olines} -a -n ${nlines} ]; then
      difflines=`expr ${olines} - ${nlines}`
    else
      PrintError "Couldn't determine number of lines for ${file}"
      PrintError "or ${file}.$$  Aborting!"
      exit 1
    fi

    if [ ${difflines} -gt ${maxdifflines} ]; then
      PrintError "Too many lines (${difflines}) missing from"
      PrintError "${file}!  Aborting!"
      rm -f ${file}.$$
      exit 1
    fi
  else
    PrintError "Could not open one or both of ${file} and/or ${file}.$$.  Aborting!"
    exit 1
  fi
}

#######################################
delete_dhcp_host () {
#######################################
# no input
# relies on the global barejsclient and dhcpddir variables

  # see if the client exists in a dhcpd config file, and delete it if so

  indhcpdfile=`grep -l "option host-name \"${barejsclient}" ${dhcpddir}/*-dhcpd.conf`

  if [ "$?" -eq 0 ]; then
  # we've found an entry, so let's delete it
  set -- ${indhcpdfile}
    for dhcpdconf in $@; do
      echo "Deleting previous entry for ${client} in ${dhcpdconf}."
      rm -f ${dhcpdconf}.$$ && \
        /usr/bin/sed -e '/^[      ]*$/d' -e "/^ *host ${barejsclient} .*/,/\}/d" < ${dhcpdconf} > ${dhcpdconf}.$$

      check_diff_lines ${dhcpdconf} 7
      mv -f ${dhcpdconf}.$$ ${dhcpdconf} && restart=1
    done
  else
    echo "No entry found for ${barejsclient}"
  fi
}

#######################################
restart_dhcpd () {
#######################################
# no input
# relies on global dhcpd_init and dhcpd_main_config variables

  if [ -x ${dhcpd_init} ] && [ -f ${dhcpd_main_config} ];  then
    ${dhcpd_init} stop && sleep 3 && ${dhcpd_init} start
  else
    PrintError "Could not execute ${dhcpd_init}: $!"
  fi
}

#######################################
tftp_file_name() {
#######################################
# Purpose : Determine the name to use for installing a file in ${tftpdir}.
#           Use an existing file if there is one that matches, otherwise
#           make up a new name with a version number suffix.
#
# Arguments :
#   $1 - the file to be installed
#   $2 - the prefix to use for forming a name
#
# Results :
#   Filename written to standard output.

  SRC=${1}
  BASE=${2}
  file_to_use=

  CONV_GRP=`echo ${arch} | tr "[a-z]" "[A-Z]"`

  # Determine the name to use for the file in bootdir.
  # Either use an existing file or make up a new name with a version
  # number appended.
  for bfile in ${tftpdir}/${BASE}.${CONV_GRP}.${osdir}* ; do
    # avoid symbolic links, or we can end up with inconsistent references
    if [ -h ${bfile} ]; then
      continue
    fi

    if cmp -s ${SRC} ${bfile}; then
      file_to_use=${bfile}
      break
    fi
  done

  if [ "${file_to_use}" ]; then
    file_to_use=`basename ${file_to_use}`
  else
    # Make this name not a subset of the old style names, so old style
    # cleanup will work.

    max=0
    for bfile in ${tftpdir}/${BASE}.${CONV_GRP}.${osdir}* ; do
      max_num=`expr ${bfile} : ".*${BASE}.${CONV_GRP}.${osdir}-\(.*\)"`
      if [ "${max_num}" -gt ${max} ]; then
        max=${max_num}
      fi
    done

    max=`expr ${max} + 1`
    file_to_use=${BASE}.${CONV_GRP}.${osdir}-${max}
  fi

  if [ ! -f ${tftpdir}/${file_to_use} ]; then
    if [ ! -f ${SRC} ]; then
      echo "Could not locate ${SRC}"
      exit 1
    fi
  cp ${SRC} ${tftpdir}/${file_to_use}
    if [ ! -f ${tftpdir}/${file_to_use} ]; then
      echo "Could not copy ${SRC} to ${tftpdir}/${file_to_use}"
      exit 1
    fi
    chmod 755 ${tftpdir}/${file_to_use}
  fi

  echo ${file_to_use}
}

