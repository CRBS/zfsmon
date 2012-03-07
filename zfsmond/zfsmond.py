#!/usr/bin/env python

# A local script to parse output from ZFS monitoring programs and push
# it to a ZFSmon server.

import sys
import os
import subprocess
import logging
from zfsmon.zfsmond.zpool import ZPool
from zfsmon.zfsmond.zmount import ZMount

def main():
    pass


def get_pools():
    """ Gets the active ZFS pools by calling `zpool list` and parsing the output. Returns a list of ZPool objects
        populated with the properties returned by zpool list -H -o all. """
    try:
        # Call `zpool list` with -H to not pretty-print the output (no header)
        poolinfostr = subprocess.check_output(['zpool', 'list', '-H', '-o', 'all'])
    except subprocess.CalledProcessError as e:
        logging.error("The call to `zpool list` failed. Info: " + str(e))
        return []
    poolinfo = poolinfostr.splitlines()
    poolobjs = []
    for poolstr in poolinfo:
        poolobjs.append(ZPool(poolstr))
    return poolobjs

def get_mounts():
    """ Gets the active ZFS mounted filesystems by calling `zfs list` and parsing the output. """
    try:
        # Call `zfs list` with -H to suppress pretty-print and header row
        mountinfostr = subprocess.check_output(['zfs', 'list', '-H', '-o', 'all'])
    except subprocess.CalledProcessError as e:
        logging.error("The call to `zfs list` failed. Info: " + str(e))
        return []
    mountinfo = mountinfostr.splitlines()
    mountobjs = []
    for mountstr in mountinfo:
        mountobjs.append(ZMount(mountstr))
    return mountobjs

if __name__ == "__main__":
    main()
