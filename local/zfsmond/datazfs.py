from urllib2 import quote
import logging
class DataZFS(object):
    def __init__(self, properties, fields=None, type=None):
        self.properties = self.property_parse(properties, fields)
        self.type = type
        self.name = self.properties['name']

    def __str__(self):
        return self.type + ": " + self.name + " -> " + str(self.properties)

    @staticmethod
    def property_parse(properties, header=None):
        """ Parses properties from zpool or zfs list commands from the optional
        provided header and returns the parsed dict. """
        # Parse the header and use that as the keys if provided
        if header:
            header = header.lower().split()
        else:
            header =   ['name', 'type', 'creation', 'used', 'avail', 'refer', 
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
                        'org.opensolaris.caiman:install']
        properties = properties.split('\t')
        log = logging.getLogger('zfsmond')
        prop_hash = dict()
        for i, key in enumerate(header):
            if i > len(properties):
                log.error("Not as many fields were returned from zfs/zpool as expected.")
                break
            prop_hash[key] = properties[i]
        
        ZFS_SIZE_FIELDS = ['avail', 'quota', 'recsize', 'refer', 'refquota', 'refreserv', 
                           'reserv', 'used', 'usedchild', 'usedds', 'usedrefreserv', 
                           'usedsnap', 'volblock', 'volsize', 'size', 'free', 'alloc']
        nullkeys = []
        for key in prop_hash.iterkeys():
            if key in ZFS_SIZE_FIELDS:
                try:
                    prop_hash[key] = DataZFS.parse_size(prop_hash[key])
                except ValueError as e:
                    log.warning("{0} -> {1} could not be ".format(key, prop_hash[key]) +
                                "parsed as a size in bytes.")
            if prop_hash[key] == '-':
                nullkeys.append(key)
        for key in nullkeys:
            del prop_hash[key]
        return prop_hash

    @staticmethod
    def parse_size(size):
        """ Parses the size value as output from zfs or zpool into a number of bytes.
        Checks if the size is '-' or 'none' and returns zero if it is."""
        MULTIPLIERS = {'K': 10**3, 'M': 10**6, 'G': 10**9, 'T': 10**12, 'P': 10**15}
        if size in ['-', 'none']: return 0
        try:
            sint = int(size)
            return sint
        except ValueError:
            size = size.strip()
            for m in MULTIPLIERS.iterkeys():
                if m in size or m.lower() in size:
                   # Since any size will be of the form '5.2T', strip the last
                   # character, parse as a float, then multiply by a multiplier
                   # and cast as an int to get the size in bytes
                   return int( float(size[:-1]) * MULTIPLIERS[m] )
        raise ValueError("Could not parse " + size + " as a size in bytes.")

