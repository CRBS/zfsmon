#!/usr/bin/env python

# A local script to parse output from ZFS monitoring programs and push
# it to a ZFSmon server.

import sys
import os
import subprocess
import logging
# import requests
import tempfile
from zfsmon.zfsmond.zpool import ZPool
from zfsmon.zfsmond.zmount import ZMount

def main():
    # Poll for the updated information we want to send
    pools = get_pools()
    mounts = get_mounts()
    print str(pools)
    print str(mounts)
    print "##### Pools #####"
    for pool in pools:
        for key in pool.properties.iterkeys():
            print key + " -> " + str(pool.properties[key])
    print "\n#### Mounts ####"
    for mount in mounts:
        print "\n\n----$ " + mount.name + " $----"
        for key in mount.properties.iterkeys():
            print key + " -> " + str(mount.properties[key])



def get_pools():
    """ Gets the active ZFS pools by calling `zpool list` and parsing the output. Returns a list of ZPool objects
        populated with the properties returned by zpool list -H -o all. """
    print "getting pools"
    try:
        with tempfile.TemporaryFile() as tf:
                # Call `zpool list` with -H to not pretty-print the output (no header)
                print "tf is defined as " + str(tf)
                subprocess.check_call(['zpool', 'list', '-H', '-o', 'all'], stdout=tf)
                tf.flush()
                tf.seek(0)
                poolinfostr = tf.read()
                print "poolinfostr: " + poolinfostr
    except subprocess.CalledProcessError as e:
        log = logging.getLogger()
        log.error("The call to `zpool list` failed. Info: " + str(e))
        print "zpool list failed"
        return []
    poolinfo = poolinfostr.splitlines()
    poolobjs = []
    for poolstr in poolinfo:
        poolobjs.append(ZPool(poolstr))
    return poolobjs

def get_mounts():
    """ Gets the active ZFS mounted filesystems by calling `zfs list` and parsing the output. """
    try:
        with tempfile.TemporaryFile() as tf:
                # Call `zfs list` with -H to suppress pretty-print and header row
                subprocess.check_call(['zfs', 'list', '-H', '-o', 'all'], stdout=tf)
                tf.flush()
                tf.seek(0)
                mountinfostr = tf.read()
    except subprocess.CalledProcessError as e:
        log = logging.getLogger()
        log.error("The call to `zfs list` failed. Info: " + str(e))
        return []
    mountinfo = mountinfostr.splitlines()
    mountobjs = []
    for mountstr in mountinfo:
        mountobjs.append(ZMount(mountstr))
    return mountobjs

if __name__ == "__main__":
    main()
