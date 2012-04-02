# ZMount is a class describing any mountable ZFS filesystem.
# It extends the AbstractZFS class.
from zfsmon.zfsmond.abstractzfs import AbstractZFS
import logging
class ZMount(AbstractZFS):
    @staticmethod
    def property_parse(properties):
        """ Parses properties into ZMount property key-value pairs, using the
        default fields from `zfs list -H -o all`. Returns the parsed dict. """
        # Split about 8 spaces (used to separate columns in `zfs list`'s output)
        proplist = properties.split('\t')
        log = logging.getLogger()
        r_props = dict()
        # Note that the order of this array matters. `zfs -H` prints without headers,
        # so we will parse in this order the tab-separated info from zfs
        ZFS_LIST_FIELDS = ['name', 'type', 'creation', 'used', 'avail', 'refer', 
                        'ratio', 'mounted', 'origin', 'quota', 'reserv', 'volsize', 
                        'volblock', 'recsize', 'mountpoint', 'sharenfs', 'checksum',
                        'compress', 'atime', 'devices', 'exec', 'setuid', 'rdonly', 
                        'zoned', 'snapdir', 'aclinherit', 'canmount', 'xattr', 
                        'copies', 'version', 'utf8only', 'normalization', 'case', 
                        'vscan', 'nbmand', 'sharesmb', 'refquota', 'refreserv', 
                        'primarycache', 'secondarycache', 'usedsnap', 'usedds', 
                        'usedchild', 'usedrefreserv', 'defer_destroy', 'userrefs', 
                        'logbias', 'dedup', 'mlslabel', 'sync', 'crypt', 
                        'keysource', 'keystatus', 'rekeydate', 'rstchown', 
                        'org.opensolaris.caiman:install', 
                        'org.opensolaris.libbe:uuid']
        # Parse the value for each key and put the k-v pair into the dict
        for i in xrange(len(ZFS_LIST_FIELDS)):
            try:
                r_props[ZFS_LIST_FIELDS[i]] = proplist[i]
            except IndexError as e:
            # Handling this problem as an exception because it should almost never happen
                fields = ", ".join(ZFS_LIST_FIELDS[i:])
                log.error("\`zfs list -H -o all\` didn't return as many fields as" +
                              " expected. The fields [" + fields + "] will not be" +
                              " included in the output. Maybe the zfs executable " +
                              "was updated? Debug: " + str(e))

        # Parse the size fields into bytes before returning the dict
        ZFS_SIZE_FIELDS = ['avail', 'quota', 'recsize', 'refer', 'refquota', 'refreserv', 
                           'refreserv', 'reserv', 'used', 'usedchild', 'usedds', 'usedrefreserv', 
                           'usedsnap', 'volblock', 'volsize']
        for key in r_props.iterkeys():
            if key in ZFS_SIZE_FIELDS:
                r_props[key] = AbstractZFS.parse_size(r_props[key])
        return r_props
