#!/bin/sh

# Build disk image and populate boot data
# Copyright Brian Conway <bconway@rcesoftware.com>, see resflash-PERMISSION for details

if [ -n "${com0sp+1}" ]; then
  COM0="com0_${com0sp}-"
else
  COM0=
fi
IMAGE=resflash-${MACHINE}-${imgsizemb}MB-${COM0}${DATE}.img
echo "Creating disk image: ${IMAGE}"

# Build the disk image

dd if=/dev/zero of=${IMAGE} bs=1m count=0 seek=${imgsizemb} status=none

# Fdisk the image

get_next_vnd
imgvnd=${nextvnd}
vnconfig ${imgvnd} ${IMAGE}

# CHS is bogus, we're not going to deal with it and require an LBA-aware BIOS
${ESCECHO} "e 0\n${DOSPARTID}\n\n64\n$((DOSPARTMB * 1024 * 1024 / BYTESECT))\n\
e 3\nA6\n\n$((DOSPARTMB * 1024 * 1024 / BYTESECT + 64))\n*\n\
flag ${FLAGPART}\n\
update\n\
write\n\
exit\n"|fdisk -e ${imgvnd} >> ${BUILDPATH}/00.mkimg.00.fdisk.img 2>&1

if [ -f ${basedir}/usr/mdec/mbr ]; then
  fdisk -uy -f ${basedir}/usr/mdec/mbr ${imgvnd} >> \
  ${BUILDPATH}/00.mkimg.01.fdisk.updatembr 2>&1
fi
fdisk -v ${imgvnd} >> ${BUILDPATH}/00.mkimg.02.fdisk.out 2>&1

# Build the disklabel: ${MBRPARTMB} MB /mbr, optional swap, two /, 100+ MB /cfg

dlroot=$(bc -e "${fssizekb} * 1024 / ${BYTESECT}" -e quit)
if [ ${swapsizemb} -gt 0 ]; then
  dlswap=$(bc -e "${swapsizemb} * 1024 * 1024 / ${BYTESECT}" -e quit)
  addswap="a b\n\n${dlswap}\n\n"
fi

${ESCECHO} "a a\n$(((DOSPARTMB + 1) * 1024 * 1024 / BYTESECT))\n\
$((MBRPARTMB * 1024 * 1024 / BYTESECT))\n\n\
${addswap}\
a d\n\n${dlroot}\n\n\
a e\n\n${dlroot}\n\n\
a f\n\n\n\n\
q\n\n"|disklabel -E ${imgvnd} >> ${BUILDPATH}/00.mkimg.03.disklabel.img 2>&1
disklabel ${imgvnd} >> ${BUILDPATH}/00.mkimg.04.disklabel.out 2>&1

# Create /mbr, /cfg, and /${DOSMNT} filesystems and mount

mkdir -p ${BUILDPATH}/mbr ${BUILDPATH}/cfg ${BUILDPATH}/${DOSMNT}
newfs -O 2 ${imgvnd}a >> ${BUILDPATH}/00.mkimg.05.newfs.a 2>&1
newfs -O 2 ${imgvnd}f >> ${BUILDPATH}/00.mkimg.06.newfs.f 2>&1
newfs_msdos -L ${DOSMNT} ${imgvnd}i >> ${BUILDPATH}/00.mkimg.07.newfs.i 2>&1
mount -o async,noatime /dev/${imgvnd}a ${BUILDPATH}/mbr
mount -o async,noatime /dev/${imgvnd}f ${BUILDPATH}/cfg
mount -o async,noatime /dev/${imgvnd}i ${BUILDPATH}/${DOSMNT}
mkdir -p ${BUILDPATH}/mbr/etc ${BUILDPATH}/cfg/{etc,var} \
${BUILDPATH}/cfg/upgrade_overlay/{etc,home,root,var} \
${BUILDPATH}/${DOSMNT}/${DOSBOOTDIR}
chmod 700 ${BUILDPATH}/cfg/upgrade_overlay/root

# Install biosboot(8), boot(8) on amd64/i386, kernels on octeon, and
# boot.conf most places

if [ ${MACHINE} == 'amd64' ] || [ ${MACHINE} == 'i386' ]; then
  # Binaries for installboot, biosboot(8), and boot(8) must match
  if [ ${CROSSARCH} -eq 0 ]; then
    installboot -v -r ${BUILDPATH}/mbr ${imgvnd} /usr/mdec/biosboot \
    /usr/mdec/boot >> ${BUILDPATH}/00.mkimg.08.installboot.pc 2>&1
  else
    installboot -v -r ${BUILDPATH}/mbr ${imgvnd} ${basedir}/usr/mdec/biosboot \
    ${basedir}/usr/mdec/boot >> ${BUILDPATH}/00.mkimg.09.installboot.cross 2>&1
  fi
  echo 'set device hd0d' >> ${BUILDPATH}/mbr/etc/boot.conf
elif [ ${MACHINE} == 'octeon' ]; then
  cp ${basedir}/bsd.d ${BUILDPATH}/${DOSMNT}/bsd
  if [ -f ${basedir}/bsd.rd ]; then
    cp ${basedir}/bsd.rd ${BUILDPATH}/${DOSMNT}
  fi
fi

# Install ${DOSBOOTBINS} bootloaders, if available

for bootbin in ${DOSBOOTBINS}; do
  if [ -f ${basedir}/usr/mdec/${bootbin} ]; then
    cp ${basedir}/usr/mdec/${bootbin} ${BUILDPATH}/${DOSMNT}/${DOSBOOTDIR}
  fi
done

# Set com0 console, if directed

if [ -n "${com0sp+1}" ] && [ ${MACHINE} != 'octeon' ]; then
  # Change speed first to skip extra 5s wait
  echo "stty com0 ${com0sp}" >> ${BUILDPATH}/mbr/etc/boot.conf
  echo 'set tty com0' >> ${BUILDPATH}/mbr/etc/boot.conf
fi

