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
import time
import hashlib
import ConfigParser as configparser
from urllib2 import quote


from zfsmond.zpool import ZPool
from zfsmond.zmount import ZMount
ZFSMON_SERVER = "http://" + "127.0.0.1:4567"
HOSTNAME = socket.gethostname()
def main():
    global ZFSMON_SERVER
    global HOSTNAME
    POOLFIELDS = 'all'
    DSFIELDS = 'all'

    # Open the log
    logging.basicConfig()
    ZFS_LOG = logging.getLogger("zfsmond")

   # Open config file
    config = configparser.SafeConfigParser()
    config_path = '/etc/zfsmond.conf'
    
    # Parse some command line args just to be nice
    zfsmon_server_cli_arg = None
    for arg in sys.argv[1:]:
        if '--with-config=' in arg:
            config_path = arg.rsplit('=')[1]
        elif '--help' in arg or '--usage' in arg:
            print "Usage: " + sys.argv[0] + " [--with-config=/path/to/cfg] [http://ZFSMON_SERVER_HOSTNAME]"
            return 0
            
        # Interpret anything else not prefixed with '--' as a hostname to use for the zfsmon server
        elif not '--' in arg:
            zfsmon_server_cli_arg = arg
        else:
            print "Usage: " + sys.argv[0] + " [--with-config=/path/to/cfg] [http://ZFSMON_SERVER_HOSTNAME]"
            return 1
            
    try:
        with open(config_path, 'r') as f:
            config.readfp(f)
    except IOError as e:
        ZFS_LOG.debug(str(e))
        ZFS_LOG.error("No configuration file was found at " + config_path + ". Using hard-coded defaults.")
        config = None

    # Parse config
    if config:
        if not config.has_section('Network'):
            ZFS_LOG.warning("No 'Network' section was found in the configuration file. Using hard-coded defaults.")
        else:
            if not config.has_option('Network', 'monitor_server'):
                ZFS_LOG.warning("The monitor_server option is missing in the configuration file.")
            else: 
                c = config.get('Network', 'monitor_server')
                if c != '': ZFSMON_SERVER = c
                # Strip the trailing slash if there is one
                if ZFSMON_SERVER[-1:] == '/':
                    ZFSMON_SERVER = ZFSMON_SERVER[:-1]
            if config.has_option('Network', 'hostname'):
                HOSTNAME = config.get('Network', 'hostname')
            if config.has_section('Parser'):
                if config.has_option('Parser', 'pool_fields'):
                    POOLFIELDS = config.get('Parser', 'pool_fields')
                if config.has_option('Parser', 'ds_fields'):
                    DSFIELDS = config.get('Parser', 'ds_fields')
            else:
                ZFS_LOG.error("Config file is missing the Parser section.")
                sys.exit(1)
    
    # Set server after parsing if it was passed in as a command line option
    if zfsmon_server_cli_arg: ZFSMON_SERVER = zfsmon_server_cli_arg
    
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
                           'The server replied with this: {0}'.format(r.text))
            sys.exit(2)
        else:
            ZFS_LOG.warning('Successfully added new host ' + HOSTNAME + ' on ' + ZFSMON_SERVER)
    
    # Poll for the updated information we want to send
    pools = get_pools()
    for pool in pools:
        # Clean up names to be URL-safe because this doesn't work in AbstractZFS' constructor
        # for some reason
        pool.properties['name'] = quote(pool.properties['name'].replace('/', '-'))
        # Create a unique ID for each by taking the SHA-1 hash of
        # the hostname + the name of the dataset + "pool"
        s = hashlib.sha1()
        s.update(HOSTNAME + pool.properties['name'] + "pool")
        pool.properties['dsuniqueid'] = s.hexdigest()
        
    datasets = get_datasets(DSFIELDS)
    for dataset in datasets:
        dataset.properties['name'] = quote(dataset.properties['name'].replace('/', '-'))
        dataset.name = dataset.properties['name']
        # Create a unique ID for each by taking the SHA-1 hash of 
        # the hostname + the name of the dataset + "ds"
        s = hashlib.sha1()
        s.update(HOSTNAME + dataset.properties['name'] + "ds")
        dataset.properties['dsuniqueid'] = s.hexdigest()
    
    snapshots = get_snapshots(DSFIELDS)
    for snap in snapshots:
        snap.properties['name'] = snap.properties['name'].replace('/', '-')
        snap.snapped_ds_name = snap.properties['name'].partition('@')[0]
        snap.properties['name'] = snap.properties['name'].partition('@')[2]
        snap.name = quote(snap.properties['name'])

        # Find the uniqueid for the ds this snap is from
        for ds in datasets:
            if ds.name == snap.snapped_ds_name:
                snap.properties['dsuniqueid'] = ds.properties['dsuniqueid']
                break
    # Do the updates once we're sure that this host exists
    try:
        if not post_update(pools, HOSTNAME, ZFSMON_SERVER):
            ZFS_LOG.warning("Not all pools could be updated.")
            return 1
        if not post_update(datasets, HOSTNAME, ZFSMON_SERVER):
            ZFS_LOG.warning("Not all datasets could be updated.")
            return 1
        if not post_update(snapshots, HOSTNAME, ZFSMON_SERVER):
            ZFS_LOG.warning("Not all snapshots could be updated.")
            return 0
    except TypeError as e:
        ZFS_LOG.error(str(e))
        ZFS_LOG.error("Update failed.")
        return 1
    return 0
            
def post_update(zfsobjs, hostname=HOSTNAME, server=ZFSMON_SERVER):
    """ POSTs the updated properties for a ZFS object to the webservice.
        zfsobjs is a list of AbstractZFS objects
        hostname is the hostname of this computer
        server is the zfs monitor server's hostname """
    ZFS_LOG = logging.getLogger("zfsmond.http")
    updated = dict()
    snapshots = False
    for obj in zfsobjs:
        # Check if this is a pool or a dataset, and POST to the appropriate resource
        if isinstance(obj, ZPool):
            rescollection = "pools"
        elif isinstance(obj, ZMount):
            if obj.properties['type'] == 'snapshot':
                snapshots = True
                post_snapshot(obj, hostname, server)
                continue
            else:
                rescollection = "datasets"
        else: raise TypeError("Can't post a non-AbstractZFS object to the web service.")
        postreq = requests.post( server + "/" + hostname + "/" + rescollection + "/" + obj.name,
                                 data=obj.properties )
        if postreq.status_code / 100 != 2:
            ZFS_LOG.error(('An HTTP {statuscode} error was encountered when updating the {resource} ' +
                          '{hname}/{resname} on {serv}.').format( statuscode=str(postreq.status_code),
                                                                   resource=rescollection[:-1],
                                                                   hname=hostname,
                                                                   resname=obj.name,
                                                                   serv=server ))
        else:
            updated[obj.name] = postreq.status_code
    if len(updated) > 0:
        for res in updated.iterkeys():
            if updated[res] == 201:
                ZFS_LOG.info('Successfully created new pool {0}/{1} on {2}.'.format( HOSTNAME, res, ZFSMON_SERVER ))
            else:
                ZFS_LOG.info('Successfully updated {0}/{1} on {2}.'.format( HOSTNAME, res, ZFSMON_SERVER ))
        return True
    if snapshots: return True
    return False

def post_snapshot(snap, hostname, server):
    ZFS_LOG = logging.getLogger("zfsmond.http")
    dataset = snap.snapped_ds_name
    postreq = requests.post( server + '/' + hostname + '/datasets/' + dataset + '/snapshots/' + snap.name, 
                             data=snap.properties )
    if postreq.status_code / 100 != 2:
        ZFS_LOG.error(('An HTTP {statuscode} error was encountered when updating the snapshot ' +
                        '{hname}/{ds}/{snap} on {serv}.').format( statuscode=str(postreq.status_code),
                                                                hname=hostname,
                                                                ds=dataset,
                                                                snap=snap.properties['name'],
                                                                serv=server ))
        return False
    elif postreq.status_code == 201:
        ZFS_LOG.info('Successfully created new snapshot record {0}/{1}/{2} on {3}.'.format( HOSTNAME, dataset, 
                                                                                            snap.properties['name'], 
                                                                                            ZFSMON_SERVER ))
    else:
        ZFS_LOG.info('Successfully updated {0}/{1}/{2} on {3}.'.format( HOSTNAME, dataset, 
                                                                        snap.properties['name'], 
                                                                        ZFSMON_SERVER ))
    return True
    
def get_pools():
    """ Gets the active ZFS pools by calling `zpool list` and parsing the output. Returns a list of ZPool objects
        populated with the properties returned by zpool list -H -o all. """
    try:
        with tempfile.TemporaryFile() as tf:
                # Call `zpool list` with -H to not pretty-print the output (no header)
                subprocess.check_call(['zpool', 'list', '-H', '-o', 'all'], stdout=tf)
                tf.flush()
                tf.seek(0)
                poolinfostr = tf.read()
    except subprocess.CalledProcessError as e:
        log = logging.getLogger("zfsmond")
        log.error("The call to `zpool list` failed. Info: " + str(e))
        return []
    poolinfo = poolinfostr.splitlines()
    poolobjs = []
    for poolstr in poolinfo:
        poolobjs.append(ZPool(poolstr))
    return poolobjs

def get_datasets(FIELDS='all'):
    """ Gets the active ZFS mounted filesystems by calling `zfs list` and parsing the output. """
    try:
        with tempfile.TemporaryFile() as tf:
                # Call `zfs list` with -H to suppress pretty-print and header row
                subprocess.check_call(['zfs', 'list', '-H', '-o', FIELDS], stdout=tf)
                tf.flush()
                tf.seek(0)
                dsinfostr = tf.read()
    except subprocess.CalledProcessError as e:
        log = logging.getLogger("zfsmond")
        log.error("The call to `zfs list` failed. Info: " + str(e))
        return []
    dsinfo = dsinfostr.splitlines()
    dsobjs = []
    for dsstr in dsinfo:
        dsobjs.append(ZMount(dsstr))
    return dsobjs

def get_snapshots(FIELDS='all'):
    """ Gets the snapshot history for each filesystem. """
    try:
        with tempfile.TemporaryFile() as tf:
                subprocess.check_call(['zfs', 'list', '-t', 'snapshot', '-o', FIELDS, '-H'], stdout=tf)
                tf.flush()
                tf.seek(0)
                snapinfostr = tf.read()
    except subprocess.CalledProcessError as e:
        log = logging.getLogger("zfsmond")
        log.error("The call to `zfs list -t snapshot` failed. Info: " + str(e))
        return []
    snapinfo = snapinfostr.splitlines()
    snapobjs = []
    for snapstr in snapinfo:
        snapobjs.append(ZMount(snapstr, True))
    return snapobjs

if __name__ == "__main__":
    main()
