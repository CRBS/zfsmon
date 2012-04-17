from urllib2 import quote
class AbstractZFS(object):
    """ An abstract class to represent an object containing data output from 
    any ZFS listing/monitoring program. They should at the least contain
    a self.properties dictionary with key-value pairs for each property
    in the `? list -o all` output, where ? can be zfs or zpool. self.name
    should also be defined in a constructor. Subclasses should override
    the property_parse(properties) method to parse the properties string
    sensibly for its type.
    
    properties is a dictionary of properties parsed from `zfs` or `zpool`

    name is a unique name for the mount or pool, and has forward slashes
    escaped to hyphens so that it can be used as part of a URL. """

    def __init__(self, properties):
        self.properties = self.property_parse(properties)
        self.properties['name'] = self.properties['name'].replace('/', '-')
        self.name = quote( self.properties['name'] )

    def __str__(self):
        return self.name + " " + str(self.properties)

    @staticmethod
    def property_parse(properties):
        pass

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

