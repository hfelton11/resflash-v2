#!/bin/sh

# Build and configure primary filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see resflash-PERMISSION for details

FS=resflash-${MACHINE}-${imgsizemb}MB-${COM0}${DATE}.fs
echo "Creating filesystem: ${FS}"

# Build the filesystem, preallocated or on the p partition:
# https://gitlab.com/bconway/resflash/-/issues/19

if [ -n "${pdisk+1}" ]; then
  ${ESCECHO} "a p\n\n${dlroot}\n\n\
  q\n\n"|disklabel -E ${pdisk} >> ${BUILDPATH}/01.mkfs.00.disklabel.fs 2>&1
  disklabel ${pdisk} >> ${BUILDPATH}/01.mkfs.01.disklabel.out 2>&1
  fspart=${pdisk}p
else
  dd if=/dev/zero of=${FS} bs=1k count=${fssizekb} status=none
  get_next_vnd
  fsvnd=${nextvnd}
  vnconfig ${fsvnd} ${FS}
  fspart=${fsvnd}c
fi

# Newfs the filesystem

newfs -O 2 ${fspart} >> ${BUILDPATH}/01.mkfs.02.newfs.fs 2>&1

# Mount and populate filesystem

echo 'Populating filesystem and configuring fstab'
mkdir -p ${BUILDPATH}/fs
mount -o async,noatime /dev/${fspart} ${BUILDPATH}/fs
tar cf - -C ${basedir} .|tar xpf - -C ${BUILDPATH}/fs
mkdir -p ${BUILDPATH}/fs/cfg ${BUILDPATH}/fs/mbr ${BUILDPATH}/fs/${DOSMNT}

# Add resflash hooks

mkdir -p ${BUILDPATH}/fs/resflash
cp -p ${BINDIR}/host/* ${BUILDPATH}/fs/resflash
cp -p ${BINDIR}/resflash.sub ${BUILDPATH}/fs/resflash
cp -p ${BINDIR}/LICENSE ${BUILDPATH}/fs/resflash
chown -R root:wheel ${BUILDPATH}/fs/resflash
echo "version: ${VERSION}" >> ${BUILDPATH}/fs/resflash/BUILD
echo "build command: ${0} ${BUILDARGS}" >> ${BUILDPATH}/fs/resflash/BUILD
echo "build date: $(date)" >> ${BUILDPATH}/fs/resflash/BUILD
cp ${BINDIR}/etc/resflash.conf ${BUILDPATH}/fs/etc
chown root:wheel ${BUILDPATH}/fs/etc/resflash.conf
echo '/resflash/resflash.save' >> ${BUILDPATH}/fs/etc/rc.shutdown
echo '/resflash/resflash.relink' >> ${BUILDPATH}/fs/etc/rc.shutdown

sed -i '/^rm.*fastboot$/a\
/resflash/rc.resflash\
# Re-read rc.conf and rc.conf.local from the new /etc\
_rc_parse_conf\
' ${BUILDPATH}/fs/etc/rc

sed -i '/^reorder_libs$/a\
umount /usr/share/relink\
' ${BUILDPATH}/fs/etc/rc

if [ ${MACHINE} == 'octeon' ]; then
  rm -f ${BUILDPATH}/fs/bsd
  ln ${BUILDPATH}/fs/bsd.d ${BUILDPATH}/fs/bsd
fi
chown root:wheel ${BUILDPATH}/fs/bsd*
chmod 600 ${BUILDPATH}/fs/bsd*

# Populate /dev

cwd=$(pwd)
cd ${BUILDPATH}/fs/dev
./MAKEDEV all
cd ${cwd}

# Configure fstab

duid=$(disklabel ${imgvnd}|grep duid|cut -d ' ' -f 2)
echo "${duid}.a /mbr ffs rw,noatime,nodev,noexec,noauto 1 2" >> \
${BUILDPATH}/fs/etc/fstab
if [ ${swapsizemb} -gt 0 ]; then
  echo "${duid}.b none swap sw" >> ${BUILDPATH}/fs/etc/fstab
fi
echo "${duid}.d / ffs ro,noatime 1 1" >> ${BUILDPATH}/fs/etc/fstab
echo "${duid}.f /cfg ffs rw,noatime,nodev,noexec,noauto 1 2" >> \
${BUILDPATH}/fs/etc/fstab
echo "${duid}.i /${DOSMNT} msdos rw,noatime,nodev,noexec,noauto 0 0" >> \
${BUILDPATH}/fs/etc/fstab
echo 'swap /tmp mfs rw,noatime,nodev,nosuid,-s32M 0 0' >> \
${BUILDPATH}/fs/etc/fstab

# Install random.seed and host.random

dd if=/dev/random of=${BUILDPATH}/fs/etc/random.seed bs=512 count=1 status=none
chmod 600 ${BUILDPATH}/fs/etc/random.seed
dd if=/dev/random of=${BUILDPATH}/fs/var/db/host.random bs=65536 count=1 \
status=none
chmod 600 ${BUILDPATH}/fs/var/db/host.random

# Set com0 ttys on arches that default to ttyC*, if directed

if [ -n "${com0sp+1}" ] && [ ${MACHINE} != 'octeon' ]; then
  sed -i -e "/^tty00/s/std\.9600/std\.${com0sp}/" \
      -e '/^tty00/s/unknown off/vt220 on secure/' \
      ${BUILDPATH}/fs/etc/ttys
fi

# Set root password in the form 'resflashYYYYMMDD'

sed -i "/^root/s|root::|root:$(echo resflash$(echo ${DATE}|cut -d _ -f 1)|\
encrypt -b 10):|" ${BUILDPATH}/fs/etc/master.passwd
pwd_mkdb -p -d ${BUILDPATH}/fs/etc master.passwd

# Work around clang hard links crossing mfs mounts

rm ${BUILDPATH}/fs/usr/libexec/cpp
ln -s /usr/bin/clang ${BUILDPATH}/fs/usr/libexec/cpp

# Relocate libLLVM.so to save space in /usr/lib

mkdir ${BUILDPATH}/fs/usr/libllvm
mv ${BUILDPATH}/fs/usr/lib/libLLVM.so.*.? ${BUILDPATH}/fs/usr/libllvm
ln -s /usr/libllvm/libLLVM.so.*.? ${BUILDPATH}/fs/usr/lib

# Perform chroot activities (fw_update, packages)

. ${BINDIR}/mkchroot.sh

# Unmount and free filesystem for copy, writing to a file if necessary

sync
umount ${BUILDPATH}/fs

if [ -n "${pdisk+1}" ]; then
  dd if=/dev/r${fspart} of=${FS} bs=1m >> ${BUILDPATH}/01.mkfs.03.dd.ptofs 2>&1
  ${ESCECHO} "d p\n\
  q\n\n"|disklabel -E ${pdisk} >> ${BUILDPATH}/01.mkfs.04.disklabel.fs 2>&1
  disklabel ${pdisk} >> ${BUILDPATH}/01.mkfs.05.disklabel.out 2>&1
else
  vnconfig -u ${fsvnd}
fi

# Write filesystem to image's d partition and calculate checksum

echo 'Writing filesystem to disk image and calculating filesystem checksum'
(tee /dev/fd/3 < ${FS}|dd of=/dev/r${imgvnd}d ibs=8k obs=1m >> \
${BUILDPATH}/01.mkfs.06.dd.fstoimg 2>&1;) 3>&1|cksum -a ${ALG} -h \
${FS}.cksum.new

echo -n "$(echo ${ALG}|tr '[:lower:]' '[:upper:]') (${FS}) = " > ${FS}.cksum
cat ${FS}.cksum.new >> ${FS}.cksum
rm ${FS}.cksum.new

