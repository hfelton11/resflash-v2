#!/bin/sh

# Mount a resflash image or filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see resflash-PERMISSION for details

set -o errexit
set -o nounset
if set -o|grep -q pipefail; then
  set -o pipefail
fi

. $(dirname ${0})/resflash.sub

if [ ${#} -ne 1 ]; then
  echo "Usage: ${0} resflash_img_or_fs"
  exit 1
fi

mount_img_or_fs ${1}
echo ${MNTPATH}

