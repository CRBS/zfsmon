# ZMount is a class describing any mountable ZFS filesystem.
# It extends the AbstractZFS class.
import zfsmon.zfsmond.abstractzfs
import logging
class ZMount(zfsmon.zfsmond.abstractzfs.AbstractZFS):
    @staticmethod
    def property_parse(properties):
    """ Parses properties into ZMount property key-value pairs, using the
        default fields from `zfs list -H -o all`. Returns the parsed dict. """
        proplist = properties.split()
        r_props = dict()
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
                logging.error("\`zfs list -H -o all\` didn't return as many fields as" +
                              " expected. The fields [" + fields + "] will not be" +
                              " included in the output. Maybe the zfs executable " +
                              "was updated? Debug: " + str(e))

        return r_props
