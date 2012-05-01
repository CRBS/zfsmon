# Extra methods for parsing and data transformation and hashes for other things

$ZPOOL_DESCRIPTIONS = { 'name' =>     'The name of the ZFS pool',
                        'size' =>     'The total size of the storage pool',
                        'cap' =>      'Percentage of pool space used.',
                        'free' =>     'The number of unallocated blocks',
                        'alloc' =>    'The amount of storage space in the pool that has been physically allocated.',
                        'altroot' =>  'Alternate root directory.  If set, this directory is prepended to ' +
                                    'any mount points within the pool.',
                        'health' =>   'The current health of the pool.',
                        'guid' =>     'The globally-unique identifier for this pool.',
                        'version' =>  'The current on-disk version of the pool.',
                        'bootfs' =>   'Identifies the default bootable dataset for the root pool.',
                        'delegation' => 'Controls whether a non-privileged user is granted access based on ' +
                                    'the dataset permissions defined on the dataset.',
                        'replace' =>  'Controls automatic device replacement. If set to "off", device replacement ' + 
                                    'must be initiated by the administrator by using the "zpool  replace" command. ' +
                                    'If set  to "on", any new device found in the same physical location as a device ' +
                                    'that previously belonged to the pool is automatically formatted and replaced.',
                        'cachefile' => 'Controls the location of where the pool configuration is cached.',
                        'failmode' => 'Controls the system behavior in the event of catastrophic pool failure.',
                        'listsnaps' => 'Controls whether information about snapshots associated with this pool is ' +
                                    'output when "zfs list" is run without the -t option. The default value is "off".',
                        'expand' =>   'Controls automatic pool expansion when the underlying LUN is grown. If set to on, ' +
                                    'the pool will be resized according to the size of the expanded device.',
                        'dedup' => 'The deduplication ratio specified for a pool, expressed as a multiplier.',
                        'dedupditto' => 'Sets a threshold for number of copies. If the reference count for a deduplicated ' +
                                        'block goes above this threshold, another ditto copy of the block is stored automatically.',
                        'rdonly' =>   'Controls whether the pool can be modified.'
                    }
                    
$ZPOOL_HEALTH = {   'degraded' =>   'One or more top-level vdevs are in the degraded state because one or more component ' +
                                    'devices are offline. Sufficient replicas exist to continue functioning.',
                    'faulted' =>    'One or more top-level vdevs are in the faulted state because one or more component ' +
                                    'devices are offline. Insufficient replicas exist to continue functioning.',
                    'offline' =>    'The device was explicitly taken offline by the "zpool offline" command.',
                    'online' =>     'The device is online and functioning.',
                    'removed' =>    'The device was physically removed while the system was running.',
                    'unavail' =>    'The device could not be opened.'
                }
                        
$ZFS_ENUM_FIELDS = ['health', 'failmode', 'type', 'checksum', 'compress', 'snapdir',
                    'aclinherit', 'canmount', 'version', 'normalization', 'case',
                    'primarycache', 'secondarycache', 'logbias', 'dedup', 'sync',
                    'crypt', 'keysourceformat', 'keysourcelocation', 'keystatus']
                    
$ZFS_STUPID_BOOLEAN_FIELDS = ['setuid', 'sharesmb', 'zoned', 'utf8only', 'xattr', 'atime',
                              'mounted', 'exec', 'vscan', 'defer_destroy', 'nbmand',
                              'devices', 'rstchown']

$ZFS_MOUNT_SIZE_FIELDS = ['avail', 'quota', 'recsize', 'refer', 'refquota', 
                          'refreserv', 'reserv', 'used', 'usedchild', 'usedds', 
                          'usedrefreserv', 'usedsnap', 'volblock', 'volsize']
                          
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
                          
$ZFS_POOL_SIZE_FIELDS = ['size', 'free', 'alloc']

$ZFS_POOL_FIELDS = ['name', 'size', 'cap', 'altroot', 'health', 'guid', 
                      'version', 'bootfs', 'delegation', 'replace', 'cachefile', 
                      'failmode', 'listsnaps', 'expand', 'dedupditto', 'dedup', 
                      'free', 'alloc', 'rdonly']

class String
    def is_int?
        Integer(self, 10)
        rescue ArgumentError
            false
        else
            true
    end
end

def get_host_record( hostget )
    if hostget.is_int?
        @host = ZFSHost.get hostget.to_i
    else
        @host = ZFSHost.first :hostname => hostget
    end
    return @host
end

def get_pool_record( hostrec, pool )
    hostrec.pools.first_or_create :host => hostrec, :name => pool
end

def get_fs_record( hostrec, filesystem )
    hostrec.mounts.first_or_create :host => hostrec, :name => filesystem
end

def get_desc( datatype, field )
    if datatype == :pool then
        r = $ZPOOL_DESCRIPTIONS[field]
    elsif datatype == :fs then
        r = $ZFS_DESCRIPTIONS[field]
    end
    unless r
        r = 'Description not found'
    end
    return r
end
    
def host_not_found( request="" )
    status 404
    "The provided host ID or hostname " + request.to_s + " could not be found in the database."
end

def pool_not_found( request="" )
    status 404
    "The provided pool ID or name " + request.to_s + " could not be found in the database."
end

def build_breadcrumb_string( elements )
    return "<a href=\"/#{elements[0]}\">#{elements[0]}</a>" if elements.size == 1
    uripaths = Array.new
    
    # Build the relative URIs for each breadcrumb
    elements.each_with_index do |element, i|
        if i == 0 then uripaths[0] = "/#{element}" 
        else uripaths[i] = uripaths[i-1] + "/#{element}"
        end
    end
    
    # Then concatenate them into a string
    tags = ""
    uripaths.each_with_index do |path, i|
        tags << "<a href=\"#{path}\">#{elements[i]}</a>"
        tags << ' / ' unless i == (uripaths.size - 1)
    end
    return tags
end
        
    
    

