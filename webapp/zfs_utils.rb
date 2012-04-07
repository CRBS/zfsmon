# Extra methods for parsing and data transformation

class String
    def is_int?
        Integer(self, 10)
        rescue ArgumentError
            false
        else
            true
    end
end
$ZFS_ENUM_FIELDS = ['health', 'failmode', 'type', 'checksum', 'compress', 'snapdir',
                    'aclinherit', 'canmount', 'version', 'normalization', 'case',
                    'primarycache', 'secondarycache', 'logbias', 'dedup', 'sync',
                    'crypt', 'keysourceformat', 'keysourcelocation', 'keystatus']

$ZFS_MOUNT_FIELDS = ['name', 'type', 'creation', 'used', 'avail', 'refer', 'ratio',
                    'mounted', 'origin', 'quota', 'compress', 'atime', 'devices', 
                    'exec', 'setuid', 'rdonly', 'zoned', 'snapdir', 'aclinherit', 
                    'canmount', 'xattr', 'copies', 'version', 'utf8only', 
                    'normalization', 'case', 'vscan', 'nbmand', 'sharesmb', 
                    'refquota', 'refreserv', 'primarycache', 'secondarycache', 
                    'usedsnap', 'usedds', 'usedchild', 'usedrefreserv', 
                    'defer_destroy', 'userrefs', 'logbias', 'dedup', 'mlslabel', 
                    'sync', 'crypt', 'keysource', 'keystatus', 'rekeydate', 
                    'rstchown',  'org.opensolaris.caiman:install', 
                    'org.opensolaris.libbe:uuid']

$ZFS_MOUNT_SIZE_FIELDS = ['avail', 'quota', 'recsize', 'refer', 'refquota', 
                          'refreserv', 'reserv', 'used', 'usedchild', 'usedds', 
                          'usedrefreserv', 'usedsnap', 'volblock', 'volsize']
$ZFS_POOL_SIZE_FIELDS = ['size', 'free', 'alloc']
$ZFS_POOL_FIELDS = ['name', 'size', 'cap', 'altroot', 'health', 'guid', 
                      'version', 'bootfs', 'delegation', 'replace', 'cachefile', 
                      'failmode', 'listsnaps', 'expand', 'dedupditto', 'dedup', 
                      'free', 'alloc', 'rdonly']
