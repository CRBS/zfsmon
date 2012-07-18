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
from datazfs import DataZFS

ZFSMON_SERVER = "http://" + "127.0.0.1:4567"
HOSTNAME = socket.gethostname()
PROXIES = {}

def main(args):
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
    cliargs = parse_cli_args(args)
    if 'config' in cliargs:
        config_path = cliargs['config'] or config_path
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
            if config.has_option('Network', 'http_proxy'):
                PROXIES['http'] = config.get('Network', 'http_proxy')
            if config.has_option('Network', 'https_proxy'):
                PROXIES['https'] = config.get('Network', 'https_proxy')
    
    # Set server after parsing if it was passed in as a command line option
    if cliargs['server']: ZFSMON_SERVER = zfsmon_server_cli_arg
    
    # Check if this host has been added yet
    # The line below checks if we got a 2xx HTTP status code
    if (requests.get( ZFSMON_SERVER + "/" + HOSTNAME, proxies=PROXIES ).status_code / 100) != 2:
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
        
        r = requests.post( ZFSMON_SERVER + "/" + HOSTNAME, data=hostdata, proxies=PROXIES )
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
        if obj.type == 'pool':
            rescollection = "pools"
        elif obj.type == 'snapshot':
                snapshots = True
                post_snapshot(obj, hostname, server)
                continue
        elif obj.type == 'dataset':
                rescollection = "datasets"
        else: raise TypeError("Can't post a non-AbstractZFS object to the web service.")
        postreq = requests.post( server + "/" + hostname + "/" + rescollection + "/" + obj.name,
                                 data=obj.properties, proxies=PROXIES )
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
                             data=snap.properties, proxies=PROXIES )
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
    poolinfostr = fork_and_get_output("zpool list -H -o all".split())
    header = get_zpool_header()
    poolinfo = poolinfostr.splitlines()
    poolobjs = []
    for poolstr in poolinfo:
        poolobjs.append(DataZFS(poolstr, header, 'pool'))
    return poolobjs

def get_datasets(FIELDS='all'):
    """ Gets the active ZFS mounted filesystems by calling `zfs list` and parsing the output. """
    dsinfostr = fork_and_get_output("zfs list -H -o {0}".format(FIELDS).split())
    header = get_zfs_ds_header()
    dsinfo = dsinfostr.splitlines()
    dsobjs = []
    for dsstr in dsinfo:
        dsobjs.append(DataZFS(dsstr, header, 'dataset'))
    return dsobjs

def get_snapshots(FIELDS='all'):
    """ Gets the snapshot history for each filesystem. """
    snapinfostr = fork_and_get_output("zfs list -t snapshot -H -o {0}".format(FIELDS).split())
    header = get_zfs_snap_header()
    snapinfo = snapinfostr.splitlines()
    snapobjs = []
    for snapstr in snapinfo:
        snapobjs.append(DataZFS(snapstr, header, 'snapshot'))
    return snapobjs

def get_zpool_header():
    out = fork_and_get_output("zpool list -o all".split())
    return out.splitlines()[0].strip()

def get_zfs_ds_header():
    out = fork_and_get_output("zfs list -o all".split())
    return out.splitlines()[0].strip()

def get_zfs_snap_header():
    out = fork_and_get_output("zfs list -t snapshot -o all".split())
    return out.splitlines()[0].strip()
    
def fork_and_get_output(cmd):
    try:
        with tempfile.TemporaryFile() as tf:
            subprocess.check_call(cmd, stdout=tf)
            tf.flush()
            tf.seek(0)
            out = tf.read()
    except subprocess.CalledProcessError as e:
        log = logging.getLogger('zfsmond')
        log.error('The call to `{0}` failed. Info: {1}'.format(" ".join(cmd), str(e)))
        return None
    return out

def parse_cli_args(args):
    zfsmon_server_cli_arg = None
    config_path = None
    for arg in args[1:]:
        if '--with-config=' in arg:
            config_path = arg.rsplit('=')[1]
        elif '--help' in arg or '--usage' in arg:
            print "Usage: " + args[0] + " [--with-config=/path/to/cfg] [http://ZFSMON_SERVER_HOSTNAME]"
            sys.exit(0)
            
        # Interpret anything else not prefixed with '--' as a hostname to use for the zfsmon server
        elif not '--' in arg:
            zfsmon_server_cli_arg = arg
        else:
            print "Usage: " + args[0] + " [--with-config=/path/to/cfg] [http://ZFSMON_SERVER_HOSTNAME]"
            sys.exit(1) 
    return { 'server': zfsmon_server_cli_arg, 'config': config_path }

if __name__ == "__main__":
    main(sys.argv)
