require 'data_mapper'

class ZFSHost
    include DataMapper::Resource

    property :id,               Serial
    property :hostname,         String, :required => true, :unique => true
    property :hostdescription,  Text
    has n,  :pools
    has n,  :mounts
end

class ZFSPool
    include DataMapper::Resource

    property :id,               Serial
    belongs_to :zfshost

    # The name of the ZFS pool
    property :name,             String, :required => true

    # Each pool must specify its capacity, free space, and allocated space in bytes
    property :size,             Integer, :required => true, :min => 0, :default => 0
    property :cap,              Integer, :required => true, :min => 0, :default => 0
    property :free,             Integer, :required => true, :min => 0, :default => 0

    # Alternate root directory.  If  set,  this  directory  is
    # prepended  to any mount points within the pool.
    property :altroot,          String, :default => '-'
    
    # Health can be 'online', 'degraded', or 'faulted'. See zpool man page for details.
    property :health,           Enum[ :online, :degraded, :faulted], :required => true

    # Unique identifier for this pool
    property :guid,             String, :required => true, :unique => true
    
    # The current on-disk version of the  pool.
    property :version,          Integer :required => true, :default => 0

    # Identifies the default bootable dataset for the root pool.
    property :bootfs,           String

    # Controls whether a non-privileged user is granted access 
    # based on the dataset permissions defined on the dataset.
    property :delegation,       Boolean, :required => true
    
    # Controls automatic device replacement. If set to  "off", 
    # device  replacement must be initiated by the administrator 
    # by using the "zpool  replace"  command.  If  set  to "on",  
    # any  new device, found in the same physical location as a 
    # device that previously belonged to  the  pool, is  
    # automatically  formatted  and  replaced.
    property :replace,          Boolean, :required => true

    # Controls the location of where the pool configuration is cached.
    property :cachefile,        String, :default => '-'

    # Controls the system behavior in the event of catastrophic pool failure.
    property :failmode,         Enum[ :wait, :continue, :panic ], :required => true

    # Controls whether information about snapshots  associated with  this 
    # pool is output when "zfs list" is run without the -t option. The default value is "off".
    property :listsnaps,        Boolean, :default => false

    # Controls automatic pool expansion  when  the  underlying LUN  is  grown.
    # If set to on, the pool will be resized according to the size of the  expanded  device.
    property :expand,           Boolean

    # Sets a threshold for number of copies. If the reference count for a deduplicated 
    # block goes above this threshold, another ditto copy of the block is stored automatically. 
    # The default value is 0.
    property :dedupditto,       Integer, :default => 0

    # The deduplication ratio specified for a pool,  expressed as  a  multiplier.  
    # This  value is expressed as a single decimal number. For example, a dedupratio 
    # value of  1.76 indicates that 1.76 units of data were stored but only 1 unit of 
    # disk space was actually consumed.
    property :dedup,            Float, :required => true, :default => 1.0

    # Controls whether the pool can be modified.
    property :rdonly,           Boolean, :required => true

end
