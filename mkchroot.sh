#!/bin/sh

# Perform chroot activities on the mounted primary filesystem
# Copyright Brian Conway <bconway@rcesoftware.com>, see resflash-PERMISSION for details

# Set up a temporary /tmp

mount -t mfs -o noatime,nodev,noexec,-s256M swap ${BUILDPATH}/fs/tmp
cp -fp /etc/resolv.conf ${BUILDPATH}/fs/etc

# Run fw_update in requested mode: all, intel-firmware, or skip

if [ ${CROSSARCH} -eq 0 ]; then
  case ${fwupdate} in
    ALL) echo 'Running fw_update -a'
         chroot ${BUILDPATH}/fs fw_update -a >> \
         ${BUILDPATH}/02.mkchroot.00.fw_update 2>&1;;
    INTEL) echo 'Running fw_update intel-firmware'
           chroot ${BUILDPATH}/fs fw_update intel-firmware >> \
           ${BUILDPATH}/02.mkchroot.00.fw_update 2>&1;;
  esac
else
  echo '*** WARNING: fw_update not supported in cross-arch builds, skipping.' \
  '***'
fi

# Preload ld.so.hints for potential package installation

if [ -n "${pkgdir+1}" ] || [ -n "${pkglist+1}" ]; then
  if [ -d ${BUILDPATH}/fs/usr/X11R6/lib ]; then
    chroot ${BUILDPATH}/fs ldconfig /usr/X11R6/lib /usr/local/lib
  else
    chroot ${BUILDPATH}/fs ldconfig /usr/local/lib
  fi
fi

# Install packages from pkgdir if directed, must run before pkglist to support
# compiled dependencies

if [ -n "${pkgdir+1}" ]; then
  echo "Installing packages: ${pkgdir}"
  mkdir -p ${BUILDPATH}/fs/tmp/pkg
  cp ${pkgdir}/*.tgz ${BUILDPATH}/fs/tmp/pkg

  if ! chroot ${BUILDPATH}/fs sh -c "env PKG_PATH=${pkgpath} pkg_add -I -v -D \
  unsigned /tmp/pkg/*.tgz" >> ${BUILDPATH}/02.mkchroot.01.pkg_add.pkg_dir \
  2>&1; then
    echo "*** WARNING: Package installation failed, check" \
    "${BUILDPATH}/02.mkchroot.01.pkg_add.pkg_dir for binary compatibility. ***"
  fi
fi

# Install packages from pkgpath/pkglist if directed

if [ -n "${pkglist+1}" ]; then
  echo "Installing packages: ${pkgpath}"

  if ! chroot ${BUILDPATH}/fs sh -c "env PKG_PATH=${pkgpath} pkg_add -I -v \
  $(echo ${pkglist}|tr , ' ')" >> ${BUILDPATH}/02.mkchroot.03.pkg_add.pkg_list \
  2>&1; then
    echo "*** WARNING: Package installation failed, check" \
    "${BUILDPATH}/02.mkchroot.03.pkg_add.pkg_list for connectivity and" \
    "version compatibility. ***"
  fi
fi

# Clean up

rm ${BUILDPATH}/fs/etc/resolv.conf
umount ${BUILDPATH}/fs/tmp

