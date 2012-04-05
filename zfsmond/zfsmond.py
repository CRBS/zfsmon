#!/usr/bin/env python

# A local script to parse output from ZFS monitoring programs and push
# it to a ZFSmon server.

import sys
import os
import subprocess
import logging
import requests
import tempfile
import socket
from zfsmon.zfsmond.zpool import ZPool
from zfsmon.zfsmond.zmount import ZMount
ZFSMON_SERVER = "http://" + "devilray.crbs.ucsd.edu"
HOSTNAME = socket.gethostname()

def main():
    # Poll for the updated information we want to send
    pools = get_pools()
    mounts = get_mounts()
    
    # Open the log
    logging.basicConfig()
    ZFS_LOG = logging.getLogger("zfsmond")

    # Check if this host has been added yet
    # The line below checks if we got a 2xx HTTP status code
    if (requests.get( ZFSMON_SERVER + "/" + HOSTNAME ).status_code / 100) != 2:
        hostdata = dict()
        try:
            with tempfile.TemporaryFile() as tf:
                subprocess.check_call(['uname', '-a'], stdout=tf)
                tf.flush()
                tf.seek(0)
                hostdata['hostname'] = HOSTNAME
                hostdata['hostdescription'] = tf.read()
        except subprocess.CalledProcessError as e:
            ZFS_LOG.error("uname called failed: " + str(e))
        
        r = requests.post( ZFSMON_SERVER + "/" + HOSTNAME,
                          data=hostdata )
        if r.status_code / 100 != 2:
            ZFS_LOG.error('An HTTP {0} error was encountered when creating a new host on {1}. '.format(str(r.status_code), ZFSMON_SERVER) + 
                           'The server replied with this: {0}'.format(r.response.text))
        else:
            ZFS_LOG.info('Successfully added new host ' + HOSTNAME ' on ' + ZFSMON_SERVER)
    
    # Once we're sure that this host exists, update its pools and mounts
    updatedpools = dict()
    for pool in pools:
        postreq = requests.post( ZFSMON_SERVER + "/" + HOSTNAME + "/" + pool.name,
                                 data=pool.properties )
        if postreq.status_code / 100 != 2:
            ZFS_LOG.error('An HTTP {statuscode} error was encountered when updating the pool ' +
                          '{hostname}/{poolname} on {server}.'.format( statuscode=str(postreq.status_code),
                                                                      hostname=HOSTNAME,
                                                                      poolname=pool.name,
                                                                      server=ZFSMON_SERVER ))
        else:
            updatedpools[pool.name] = postreq.status_code
    if len(updatedpools) > 0:
        for p in updatedpools.iterkeys():
            if updatedpools[p] == 201:
                ZFS_LOG.info('Successfully created new pool {0}/{1} on {2}.'.format( HOSTNAME, p, ZFSMON_SERVER ))
            else:
                ZFS_LOG.info('Successfully updated {0}/{1} on {2}.'.format( HOSTNAME, p, ZFSMON_SERVER ))
    

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
        log = logging.getLogger("zfsmond")
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
        log = logging.getLogger("zfsmond")
        log.error("The call to `zfs list` failed. Info: " + str(e))
        return []
    mountinfo = mountinfostr.splitlines()
    mountobjs = []
    for mountstr in mountinfo:
        mountobjs.append(ZMount(mountstr))
    return mountobjs

if __name__ == "__main__":
    main()
