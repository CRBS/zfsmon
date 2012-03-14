class AbstractZFS(object):
""" An abstract class to represent an object containing data output from 
    any ZFS listing/monitoring program. They should at the least contain
    a self.properties dictionary with key-value pairs for each property
    in the `? list -o all` output, where ? can be zfs or zpool. self.name
    should also be defined in a constructor. Subclasses should override
    the property_parse(properties) method to parse the properties string
    sensibly for its type."""

    def __init__(self, properties):
        self.properties = property_parse(properties)
        self.name = self.properties['name']
        self.properties['size'] = parse_size(self.properties['size'])
        self.size = self.properties['size']

    def __str__(self):
        return self.name + " " + str(self.properties)

    @staticmethod
    def property_parse(properties):
        pass

    @staticmethod
    def parse_size(size):
    """ Parses the size value as output from zfs or zpool into a number of bytes."""
        MULTIPLIERS = {'K': 10**3, 'M': 10**6, 'G': 10**9, 'T': 10**12, 'P': 10**15}
        try:
            sint = int(size)
            return sint
        except ValueError:
            size = size.strip()
            for m in MULTIPLIERS.iterkeys():
                if m in size:
                   return int( float(size[:len(size)-1]) * MULTIPLIERS[m] )
        raise ValueError("Could not parse " + size + " as a size in bytes.")


