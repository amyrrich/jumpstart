#!/bin/sh
# This script is under cfengine control.  Please change it at
# cfd:/local/cfengine/servers/jumpstart/all/inst/script

# This script takes the name of a hostconf file (located under
# /inst/jumpstart/hostconf) and an os revision number of the target host.

scriptdir=`dirname $0`

hostconf=$1
osrev=$2
arch=$3

PrintUsage () {
  echo "Usage: <hostconf file> <os rev> <machine type>"
  echo "       <osrev> must be one of 8, 9, or 10"
  echo "       <machine type> must be one of sun4u, sun4v, or i86pc"
  exit 1
}

if [ "X${hostconf}" = X ]; then
  PrintUsage
fi

if [ "X${osrev}" != "X8" ] && [ "X${osrev}" != "X9" ] && [ "X${osrev}" != "X10" ]; then
  PrintUsage
fi

if [ "X${arch}" != "Xsun4u" ] && [ "X${arch}" != "Xsun4v" ] && [ "X${arch}" != "Xi86pc" ]; then
  PrintUsage
fi

echo "========================================================================="
echo "Checking Solaris ${osrev} ${arch} jumpstart configuration for ${hostconf}"
echo "========================================================================="

# Frist, determine the bare hostname of the client
OIFS="${IFS}"
IFS='.'
set -- ${hostconf}
IFS="${OIFS}"
barejsclient=${1}

# include the functions file
. ${scriptdir}/je-funcs.sh


# Make sure the hostconf file exists
if [ ! -r "${jsbase}/hostconf/${hostconf}" ]; then
  PrintError "     ERROR: hostconf file ${jsbase}/hostconf/${hostconf}"
  PrintError "            is unreadable or nonexistant: $?"
  exit 1
fi

# Make sure the host is in the correct dhcpd config file
indhcpdfile=`grep -l "option host-name \"${barejsclient}" ${dhcpddir}/*-dhcpd.conf`

if [ "$?" -ne 0 ]; then
  PrintError "     ERROR: host ${barejsclient} is not listed in"
  PrintError "            ${dhcpdfile}"
  exit 1
elif [ "${indhcpdfile}" != "${dhcpdfile}" ]; then
  PrintError "     ERROR: host ${barejsclient} found in"
  PrintError "            ${indhcpdfile}"
  PrintError "              should only be in"
  PrintError "            ${dhcpdfile}"
  exit 1
fi
  

case "${arch}" in 
i86pc)
  bootfile=`awk -F\" '/filename/ {print $2}' ${dhcpdfile} | sed s/pxegrub.//`
  cdromdir=`awk -F: '/'${bootfile}'.*jumpstart/ {print $2}' ${grubmenu} | uniq | sed s/,.*//`
  ;;
sun4*)
  cdromdir=`awk -F\" '/option SUNW.install-path/ {print $2}' ${dhcpdfile}`
  ;;
esac

if [ "X${cdromdir}" = X ]; then
  PrintError "     ERROR: cdrom directory is not listed in"
  case "${arch}" in
  i86pc)
    PrintError "            ${grubmenu}"
    ;;
  sun4*)
    PrintError "            ${dhcpdfile}"
    ;;
  esac
exit 1
fi

# it looks like the primary config file is in place and the host has been added
# to the correct dhcpd config gile, so lets start parsing the hostconf file
. ${jsbase}/hostconf/${hostconf}

###############################################################################
# profile
###############################################################################

# check to make sure the profile exists
if [ -r "${jsbase}/prof/${profile}" ]; then

  # check to see if the host is configured for live upgrade
  if [ ${osrev} -gt 8 ]; then
    if [ `grep "^filesys.* /lu" "${jsbase}/prof/${profile}"|wc -l` -ne 0 ]; then
      echo "System is partitioned for liveupgrade"
    else
      PrintError "     ERROR: System is NOT partitioned for liveupgrade"
    fi
  fi

  if [ "${osrev}" -lt 10 ]; then

  #############################################################################
  # disksuitemirror
  #############################################################################

  # check to see if the disk should be mirrored and that the same number
  # of mirrors and boot disk partitions exist
    if [ "X${disksuitemirror}" != "X" ]; then
      echo "System disks are configured for mirroring"
      for part in ${disksuitemirror}; do
        rootpart=`grep "filesys.* ${part}" "${jsbase}/prof/${profile}"`
        sparepart=`grep "filesys.* /spare${part}" "${jsbase}/prof/${profile}"`
        if [ "X${rootpart}" = X ]; then
          PrintError "     ERROR: missing boot partition for ${part} in"
          PrintError "            ${jsbase}/prof/${profile}"
        fi
        if [ "X${sparepart}" = X ]; then
          PrintError "     ERROR: missing mirror partition for ${part} in"
          PrintError "            ${jsbase}/prof/${profile}"
        fi
      done
  
      ##########################################################################
      # disksuiteswap mirror
      ##########################################################################
      # first, check and see if we're using rootdisk in the profile instead of
      # explicit disk definitions for the boot disk
      if [ "X`grep \"^filesys.*rootdisk\" \"${jsbase}/prof/${profile}\"`" = X ]; then
        rootdisk=0
      else
        rootdisk=1
      fi

      missing=''
      nummissing=0

      # make sure the disksuiteswapmirror is set up correctly
      if [ "X${disksuiteswapmirror}" != X ]; then 
        for part in `echo ${disksuiteswapmirror} | tr : " "`; do
          swapline=`grep "${part}" "${jsbase}/prof/${profile}" | /usr/local/bin/awk '{print $4}'`
          if [ "${swapline}" != "swap" ] && [ "${swapline}" != "/spare/swap" ]; then
            missing="${part} ${missing}"
            nummissing=`expr ${nummissing} + 1`
          fi
        done
        if [ ${nummissing} -gt 0 ]; then
          if [ ${rootdisk} -eq 1 ] && [ ${nummissing} -gt 1 ]; then
            PrintError "     ERROR: missing hostconf disksuiteswap mirror definition for"
            PrintError "            ${missing} in ${jsbase}/prof/${profile}"
          elif [ ${rootdisk} -eq 0 ]; then
            PrintError "     ERROR: missing hostconf disksuiteswap mirror definition for" 
            PrintError "            ${missing} in ${jsbase}/prof/${profile}"
          fi
        fi
      else
        PrintError "     ERROR: missing hostconf disksuiteswapmirror definition"
      fi
    else
      # see if we have /spare bits listed in the profile even though we don't have
      # disksuitemirroring turned on
      if [ "X`grep \"filesys.* /spare\" \"${jsbase}/prof/${profile}\" |grep -v /spare/md1`" != X ]; then
        PrintError "     WARNING: /spare paritions found in profile ${profile} but"
        PrintError "       disksuite mirroring is not configured"
      else
        PrintError "     WARNING: System disks are NOT configured to be mirrored"
      fi
    fi
  else
    nonmirrored=`grep "^filesys" "${jsbase}/prof/${profile}" | grep -v mirror`
    if [ "X${nonmirrored}" != 'X' ]; then
      PrintError "     WARNING: non mirrored filesystems in ${jsbase}/prof/${profile}"
      PrintError "     ${nonmirrored}"
    else
      echo "System is configured for mirrored disks"
    fi 
  fi
else
  PrintError "     ERROR: missing or unreadble profile ${profile} in"
  PrintError "            ${jsbase}/prof: $?"
fi

###############################################################################
# ospkglist
###############################################################################
clustertoc="${cdromdir}/Solaris_${osrev}/Product/.clustertoc"

for ospkgsfile in ${ospkglist}; do
  if [ -r "${jsbase}/ospkg/${ospkgsfile}" ]; then 

  # only handle adds, not deletes

    for pkg in `/usr/local/bin/awk '/^ *#/ {next;} /add/ {print $1 ":" $2}' < "${jsbase}/ospkg/${ospkgsfile}"`; do
      OIFS="$IFS"
      IFS=":"
      set -- ${pkg}
      IFS="$OIFS"

      type="$1"
      name="$2"

      # if it's a package, just look for the dir (or the dir ending with a .u
      # in the OS distribution dir
      if [ "${type}" = package ]; then
        if [ ! -d "${cdromdir}/Solaris_${osrev}/Product/${name}" ] && \
          [ ! -d "${cdromdir}/Solaris_${osrev}/Product/${name}.u" ]; then
          PrintError "     ERROR: ospkg file ${jsbase}/ospkg/${ospkgsfile}"
          PrintError "            missing package directory for ${name} in"
          PrintError "       ${cdromdir}/Solaris_${osrev}/Product"
        fi
      # if it's a cluster, parse ${cdromdir}/Solaris_X/Product/.clustertoc for
      # CLUSTER=name
      elif [ "${type}" = cluster ]; then
        if [ "X`grep \"^CLUSTER=${name}\$\" \"${cdromdir}/Solaris_${osrev}/Product/.clustertoc\"`" = X ]; then
          PrintError "     ERROR: ospkg file ${jsbase}/ospkg/${ospkgsfile}"
          PrintError "            missing cluster definition for ${name} in"
          PrintError "       ${cdromdir}/Solaris_${osrev}/Product/.clustertoc"
        fi
      else
        PrintError "     ERROR: unrecognized ospkg file type ${type} for ${name} in"
        PrintError "            ${jsbase}/ospkg/${ospkgsfile}"
      fi
    done
  else
    PrintError "     ERROR: ${jsbase}/ospkg/${ospkgsfile} is unreadable"
    PrintError "            or does not exist: $?"
  fi
done

###############################################################################
# extpkglist
###############################################################################

# make sure that all of the packages in each extpkg file exist
for extpkgsfile in ${extpkglist}; do
  if [ -r "${jsbase}/extpkgs/${extpkgsfile}" ]; then
    for file in `/usr/local/bin/awk '/^[0-9a-zA-Z]/ {print $1}' < ${jsbase}/extpkgs/${extpkgsfile}`; do
      if [ ! -r "${extpkgsdir}/${file}" ] && [ ! -d "${extpkgsdir}/${file}" ]; then
        PrintError "     ERROR: can not find readable file or directory ${file}"
        PrintError "            in ${extpkgsdir}: $?"
      fi
    done
  else
    PrintError "     ERROR: ${jsbase}/extpkgs/${extpkgsfile} is unreadable"
    PrintError "            or does not exist: $?"
  fi
done

###############################################################################
# packagelist
###############################################################################
reqpkgs="RICHPse SunExplorer Legato"

if [ ${osrev} = 8 ]; then
  reqpkgs="${reqpkgs} disksuite-4.2.1"
elif [ ${osrev} = 9 ]; then
  reqpkgs="${reqpkgs} J*DK"
elif [ ${osrev} = 10 ]; then
  reqpkgs="${reqpkgs}"
fi

for package in ${reqpkgs}; do
  if [ "X`grep \"${package}\" \"${jsbase}/hostconf/${hostconf}\"`" = X ]; then
    PrintError "     ERROR: missing ${package} in hostconf packagelist definition"
  fi
done

for packagedir in ${packagelist}; do
  if [ ! -r "${datadir}/packages/${packagedir}/install" ]; then
    PrintError "     ERROR: missing or unreadable install file for ${packagedir}"
    PrintError "            in ${datadir}/packages/${packagedir}: $?"
  fi
done

###############################################################################
# patchlist
###############################################################################
for patchdir in ${patchlist}; do
  if [ ! -r "${datadir}/patches/SunOS-5.${osrev}-sparc/${patchdir}/patch_order" ]; then
    PrintError "     ERROR: no patch_order file for ${patchdir} in"
    PrintError "            ${datadir}/patches/SunOS-5.${osrev}-sparc/${patchdir}: $?"
  fi
done

###############################################################################
# rootfiles
###############################################################################
for filedir in ${rootfiles}; do
  if [ ! -d "${datadir}/rootfiles/${filedir}" ]; then
    PrintError "     ERROR: missing rootfile dir ${datadir}/rootfiles/${filedir}: $?"
  fi
done

###############################################################################
# postscr
###############################################################################
for script in ${postscr}; do
  if [ ! -r "${jsbase}/post/${script}" ]; then
    PrintError "     ERROR: missing or unreadable postscr file"
    PrintError "            ${jsbase}/post/${script}: $?"
  fi
done

###############################################################################
# postreboot
###############################################################################
for script in ${postreboot}; do
  if [ ! -r "${jsbase}/post/${script}" ]; then
    PrintError "     ERROR: missing or unreadble postreboot file"
    PrintError "            ${jsbase}/post/${script}"
  fi
done
