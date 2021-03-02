#!/bin/sh

# Unmount a mounted resflash image or filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see resflash-PERMISSION for details

set -o errexit
set -o nounset
if set -o|grep -q pipefail; then
  set -o pipefail
fi

. $(dirname ${0})/resflash.sub

umount_all

rm -r /tmp/resflash.??????

