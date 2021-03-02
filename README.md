# resflash-v2

This project tries to take the basic-ideas of resflash (https://gitlab.com/bconway/resflash)
and OBSD-RO (http://thamessoftware.co.uk/openbsd_readonly.html) to make a simple usb-stick
that does the following tasks:

I - Have two exchangeable read-only partitions (/fs1 and /fs2 which mount at / upon boot)

II - Have one efi-type partition to make system bootable (/mbr)

III - Have one cfg-type partition to make simple configuration updates (/cfg)

IV - allow other known-disks (/fs3, etc) to be swapped in for mounting at / upon boot.

in theory this can/should be done as portable-shell scripting,
but we will use python since odds-are there will be some higher-order
programming involved and it will be handy to have a full-language available...

for now, i will base this upon the openbsd (https://www.openbsd.org/) v.6.8-stable
which currently has perl as v5.30.3 as its default language-of-choice...  sigh...
apparently python-2.7.18p0 comes standard under the name python2...
just to be safe-ish, i might want to run everything under pypy (https://www.pypy.org/)...

$ doas pkg_add pypy py-pip py-virtualenv

$ python2 --version

Python 2.7.18

$ pypy --version

Python 2.7.13 (?, Sep 30 2020, 23:12:46)
\[PyPy 7.3.1 with GCC OpenBSD Clang 10.0.1 \]

$ doas ln -sf /usr/local/bin/pip2.7 /usr/local/bin/pip   ...AND...
$ doas ln -sf /usr/local/bin/python2 /usr/local/bin/python

$ virtualenv --prompt=rf2_ resflash2-python2   ...AND/OR...
$ virtualenv --prompt=rf2p_ resflash2-pypy

$ . resflash2-python2/bin/activate   ...GETS...
rf2_$        (ready to do python work)

