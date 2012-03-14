# ZPool is a class describing ZFS pools and their properties.
# It extends the AbstractZFS class.
import zfsmon.zfsmond.abstractzfs
import logging
class ZPool(zfsmon.zfsmond.AbstractZFS):
    # __init__ is inherited from ZMount(self, properties)
    # properties is the string output from `zpool list -o all -H`
    @staticmethod
    def property_parse(properties):
    """ Parses properties into ZPool propery key-value pairs, using the default
        fields from `zpool list -H -o all`. Returns the parsed dict. """
        log = logging.getLogger()
        proplist = properties.split()
        r_props = dict()
        ZPOOL_LIST_FIELDS = ['name', 'size', 'cap', 'altroot', 'health', 'guid', 
                             'version', 'bootfs', 'delegation', 'replace', 
                             'cachefile', 'failmode', 'listsnaps', 'expand', 
                             'dedupditto', 'dedup', 'free', 'alloc', 'rdonly']
        # Parse the value for each key and put the k-v pair into the dict
        for i in xrange(len(ZPOOL_LIST_FIELDS)):
            try:
                r_props[ZPOOL_LIST_FIELDS[i]] = proplist[i]
            except IndexError as e:
                fields = ", ".join(ZPOOL_LIST_FIELDS[i:])
                log.error("\`zpool list -H -o all\` didn't return as many " +
                             "fields as expected. The fields [" + fields + "] " +
                             "will not be included in the output. Maybe the zpool" +
                             " executable was updated? Debug: " + str(e))
        return r_props
