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
programming involved and it will be handy to have a full-language available.

for now, i will base this upon the openbsd (https://www.openbsd.org/) v.6.8-stable
which currently has perl as v5.30.3 as its default language-of-choice...  sigh...
# pkg_add python
the two current options are v.3.7.10 or v.3.8.6p1
okay, whatever happened to python2 ???  apparently politics and dumb-luck for obsd6.8
(https://www.unitedbsd.com/d/298-a-sad-day-for-bsd-and-python/30)
# pkg_info -a -Q python | grep 2
apparently there is still some 2.7 stuff floating around, particularly for pypy
# locate python | grep \/bin\/
ok - apparently regular python2 is "just THERE" under v.2.7.18p0...
# python2 --version
Python 2.7.18    (...DOH...)
# pkg_add pypy
added pypy-7.3.1 just fine (if needed)...

according to pypy.org, the supported pythons are (2.7.13 and 3.6.9) - cool...


