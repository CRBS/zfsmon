import hashlib
import socket
import json
from urllib2 import quote

class StatusLine(json.JSONEncoder):
    def __init__(self, name='', children=None):
        self.name = name
        if children:
            self.children = children
        else:
            self.children = []

    def __str__(self):
        return self.name

class SLEncoder(json.JSONEncoder):
    def default(self, obj):
        if not isinstance(obj, StatusLine):
            return JSONEncoder.default(self, obj)
        else:
            return obj.__dict__

class PoolStatus(object):
    def __init__(self, status):
        # status should be a string with the output 
        # of `zpool status` split by pool
        self.properties = self.parse(status)
        self.name = self.properties['pool']

    def to_json(self):
        return json.dumps(self.properties, cls=status.SLEncoder)

    def to_yaml(self):
        pass

    @staticmethod
    def parse(status_str):
        """ Parses the output for one pool from zpool status and returns a 
            dict containing that information."""
        status = dict()
        for line in status_str.splitlines():
            if line == '': continue
            property, delim, value = line.partition(':')
            property = property.strip()
            if property == 'pool':
                if not 'pool' in status:
                    status['pool'] = value.strip()
                else:
                    raise ValueError("Multiple pools encountered when parsing PoolStatus")
            if property == 'config':
                status['config'] = []
                continue
            elif line.startswith('\t') and 'config' in status:
                status['config'].append(line[1:])
                continue
            else:
                status[property] = value.strip()
        sha = hashlib.sha1()
        sha.update(socket.gethostname() + quote(status['pool'].replace('/', '-')) + "pool")
        status['pool_id'] = sha.hexdigest()
        status['config'] = PoolStatus.parse_pool_config(status['config'])
        return status

    @staticmethod
    def parse_pool_config(config):
        """ Parses the vdev configuration from zpool status into its hierarchy as a list of StatusLines. """
        # Don't bother parsing if the first line isn't the header we expect
        if not config[0].split() == ['NAME', 'STATE', 'READ', 'WRITE', 'CKSUM']: return None
        config = config[1:]
        devices = []
        stack = []
        i_level = 0
        for line in config:
            indent = PoolStatus.indentation(line)
            fields = line.split()
            sl = StatusLine(name=fields[0])

            # If the line has all the fields we're expecting,
            # parse them into a dict
            if len(fields) == 5:
                sl.state = fields[1]
                sl.errors = {}
                sl.errors['read'] = int(fields[2])
                sl.errors['write'] = int(fields[3])
                sl.errors['cksum'] = int(fields[4])

            # If the indent is 0, it's a root node
            if indent == 0:
                devices.append(sl)
                stack = []
                stack.append(sl)
                i_level = 0
                continue

            # This line is a child of the previous (indent)
            if indent > i_level:
                stack[-1].children.append(sl)
                stack.append(sl)
                i_level = indent

            # This line is a sibling of the previous
            elif indent == i_level:
                stack.pop()
                stack[-1].children.append(sl)
                stack.append(sl)

            # This line is not related to the previous (dedent)
            elif indent < i_level:
                while indent <= i_level:
                    stack.pop()
                    i_level -= 1
                stack[-1].children.append(sl)
                stack.append(sl)
        # end loop
        return devices

    @staticmethod
    def indentation(string, SPACES=2):
        """ Returns the indentation of a string, using SPACES as the tabstop (default 2). """
        i = 0
        for char in string:
            if char == ' ':
                i += 1
            else:
                return i / SPACES
        return i / SPACES
