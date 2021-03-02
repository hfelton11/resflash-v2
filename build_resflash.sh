#!/bin/sh

# resflash master build script
# Copyright Brian Conway <bconway@rcesoftware.com>, see resflash-PERMISSION for details

set -o errexit
set -o nounset
if set -o|grep -q pipefail; then
  set -o pipefail
fi
#set -o xtrace # DEBUG

BINDIR=$(dirname ${0})
. ${BINDIR}/resflash.sub
. ${BINDIR}/build_resflash.sub

VERSION=6.8.2
BYTESECT=512
fwupdate=ALL
pkgpath=https://cdn.openbsd.org/%m/
swapsizemb=0
addswap=

if [ ${#} -eq 0 ]; then
  usage_and_exit
else
  BUILDARGS=${*}
fi

# Parse options

while :; do
  case ${1} in
    -i) fwupdate=INTEL; shift;;
    -n) fwupdate=NONE; shift;;
    -p) pkgdir=${2}; shift 2;;
    --part_p) pdisk=${2}; shift 2;;
    --pkg_list) pkglist=${2}; shift 2;;
    --pkg_path) pkgpath=${2}; shift 2;;
    -s) com0sp=${2}; shift 2;;
    --swap) swapsizemb=${2}; shift 2;;
    -V) echo "resflash ${VERSION}"; exit 1;;
    -*) usage_and_exit;;
    *) break;;
  esac
done

case ${#} in
  2) imgsizemb=${1}
     basedir=${2};;
  *) usage_and_exit;;
esac

# Verify root user

if [ $(id -u) -ne 0 ]; then
  echo 'Must be run as root.'
  exit 1
fi

# Verify available vnds

if [ $(vnconfig -l|grep -c 'not in use') -lt 2 ]; then
  ${ESCECHO} "Not enough vnds are available:\n$(vnconfig -l)"
  exit 1
fi

${ESCECHO} "resflash ${VERSION}\n"

# Validate base unpacking

validate_base_dir ${basedir} ${imgsizemb} ${swapsizemb}
set_attr_by_machine ${MACHINE}

# Leave one set of logs for debugging
rm -rf /tmp/resflash.??????
BUILDPATH=$(mktemp -t -d resflash.XXXXXX)
DATE=$(date +%Y%m%d_%H%M)

trap "umount_all; echo \*\*\* Error encountered. BUILDPATH: ${BUILDPATH} \
\*\*\*; exit 1" ERR INT

# Build disk image and populate boot data

. ${BINDIR}/mkimg.sh

# Build and configure primary filesystem

. ${BINDIR}/mkfs.sh

# Clean up

umount_all

echo 'Calculating disk image checksum'
for image in resflash-*-${DATE}.img; do
  cksum -a ${ALG} -h ${image}.cksum ${image}
done

${ESCECHO} 'Build complete!\n\nFile sizes:'
ls -lh resflash-*-${DATE}.{fs,img}|awk -safe '{ print $5"\t"$9 }'
${ESCECHO} "Disk usage:\n$(du -h resflash-*-${DATE}.{fs,img})"

