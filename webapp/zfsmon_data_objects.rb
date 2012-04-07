require 'data_mapper'

class ZFSHost
    include DataMapper::Resource

    property :id,               Serial
    property :hostname,         String, :required => true, :unique => true
    property :hostdescription,  Text
    property :lastupdate,       DateTime
    has n, :pools,              :model => 'ZFSPool'
    has n, :mounts,             :model => 'ZFSMount'

end

class ZFSPool
    include DataMapper::Resource

    property :id,               Serial
    property :lastupdate,       DateTime
    belongs_to :host,           :model => 'ZFSHost'

    # The name of the ZFS pool
    property :name,             String, :required => true

    # Each pool must specify its capacity, free space, and allocated space in bytes
    property :size,             Integer, :required => true, :min => 0, :max => 9223372036854775808, :default => 0
    property :cap,              Decimal, :required => true, :min => 0.0, :max => 1.0, :default => 1.0
    property :free,             Integer, :required => true, :min => 0, :max => 9223372036854775808, :default => 0

    # Alternate root directory.  If  set,  this  directory  is
    # prepended  to any mount points within the pool.
    property :altroot,          String, :default => '-'
    
    # Health can be 'online', 'degraded', or 'faulted'. See zpool man page for details.
    property :health,           Enum[ :online, :degraded, :faulted], :required => true

    # Unique identifier for this pool
    property :guid,             String, :required => true, :unique => true
    
    # The current on-disk version of the  pool.
    property :version,          Integer, :required => true, :default => 0

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

class ZFSMount
    include DataMapper::Resource

    property :id,               Serial
    property :lastupdate,       DateTime
    belongs_to :host,           :model => 'ZFSHost'

    # The name of the mount
    property :name,             String, :required => true
    
    # The type of dataset: filesystem, volume, or snapshot.
    property :type,             Enum[ :filesystem, :volume, :snapshot ], :required => true

    # The time this dataset was created
    property :creation,         DateTime, :required => true

    # For volumes, specifies the logical size of the volume.
    property :volsize,          Integer, :required => true, :min => 0

    # The amount of space consumed by this dataset and all its descendants.
    property :used,             Integer, :required => true, :min => 0

    # The amount of space available to the dataset and all its 
    # children, assuming that there is no other activity in the pool.
    property :avail,            Integer, :required => true, :min => 0

    # The amount of data that is accessible by this dataset, 
    # which may or may not be shared with other datasets in the pool.
    property :refer,            Integer, :required => true, :min => 0

    # The  compression  ratio  multiplier  for   this   dataset
    property :ratio,            Float, :default => 1.0

    # Is this filesystem currently mounted? Note that zfs list prints '-' for
    # mounts that are not filesystems
    property :mounted,          Boolean, :required => true, :default => false

    # For cloned file systems or volumes,  the  snapshot  from
    # which  the  clone was created. '-' if not a clone.
    property :origin,           String, :default => '-'

    # A hard limit on the amount of space used by this dataset and descendants.
    # ZFS prints '-' if not defined, so leave nil ifndef.
    property :quota,            Integer, :required => false

    # The minimum amount of space guaranteed to a dataset  and its descendants.
    property :reserv,           Integer, :required => false

    # For volumes, specifies the block size of the volume. zfs returns '-' for non-volumes.
    property :volblock,         Integer, :required => false

    # The suggested block size for files in  the  filesystem. '-' for non-filesystems.
    property :recsize,          Integer, :required => false, :min => 0

    # The mount point used for this file system
    property :mountpoint,       String, :required => true, :default => 'none'

    # Controls whether the file system is shared via NFS
    property :sharenfs,         Boolean

    # Controls the checksum used to verify data integrity.
    property :checksum,         Enum[ :auto, :fletcher2, :fletcher4, :sha256, :sha256mac, :off ], :required => true, :default => :auto

    # Controls the compression algorithm used for this dataset.
    property :compress,         Enum[ :lzjb, :gzip, :zle, :off ], :required => true, :default => :off

    # Controls whether the access time for  files  is  updated when they are read.
    property :atime,            Boolean, :default => true

    # Controls whether device nodes can be opened on this filesystem
    property :devices,          Boolean

    # Controls whether processes can be executed from within this fs.
    property :exec,             Boolean

    # Controls whether the set-UID bit is  respected for this fs.
    property :setuid,           Boolean

    # Controls whether  this  dataset  can  be  modified.
    property :rdonly,           Boolean

    #  Controls whether the dataset is managed from a non-global zone
    property :zoned,            Boolean

    # Controls whether the .zfs directory is hidden or visible
    property :snapdir,          Enum[ :hidden, :visible ], :required => true

    # Controls how ACL entries are inherited  when  files  and
    # directories are created. See man page for more info.
    property :aclinherit,       Enum[ :discard, :noallow, :restricted, :passthrough, :passthroughx ], :required => true

    # Controls whether this filesystem can be mounted.
    property :canmount,         Enum[ :on, :off, :noauto ]

    # Controls whether extended  attributes  are  enabled
    property :xattr,            Boolean

    # Controls the number of copies of data  stored  for  this dataset
    property :copies,           Integer, :min => 1, :max => 3, :required => true, :default => 1

    # The on-disk  version  of  this  file  system
    property :version,          Enum[ :one, :two, :current ]

    # Indicates whether the file  system  should  reject  file names  
    # that  include  characters that are not present in the UTF-8 character code set.
    property :utf8only,         Boolean

    # Indicates whether  the  file  system  should  perform  a unicode  normalization  of  file names whenever 
    # two file names are compared, and  which  normalization  algorithm should be used.
    property :normalization,    Enum[ :none, :formC, :formD, :formKC, :formKD]

    # Indicates whether the file name matching algorithm  used by  the  file  system  
    # should  be  case-sensitive, case-insensitive, or allow a combination of  both  styles
    property :case,             Enum[ :sensitive, :insensitive, :mixed ]

    # Controls whether regular files  should  be  scanned  for viruses when a file is opened and closed.
    property :vscan,            Boolean

    # Controls whether the file system should be mounted  with nbmand  (Non Blocking mandatory locks).
    property :nbmand,           Boolean

    # Controls whether the file system is shared by using  the Solaris SMB service
    property :sharesmb,         Boolean

    # Limits the amount of space a dataset can  consume.
    property :refquota,         Integer, :min => 0

    # The minimum amount of space guaranteed to a dataset, not including  its descendants.
    property :refreserv,        Integer, :min => 0

    # Controls what is cached in the primary cache  (ARC).
    property :primarycache,     Enum[ :all, :none, :metadata ]

    # Controls what is cached in the secondary cache  (L2ARC).
    property :secondarycache,   Enum[ :all, :none, :metadata ]

    # The amount  of  space  consumed  by  snapshots  of  this dataset.
    property :usedsnap,         Integer, :min => 0, :required => true

    # The amount of space used by this dataset  itself,  which would  be  freed  if  the  dataset were destroyed
    property :usedds,           Integer, :min => 0, :required => true

    # The amount of space used by children  of  this  dataset, which  
    # would be freed if all the dataset's children were destroyed.
    property :usedchild,        Integer, :min => 0, :required => true

    # The amount of space used by a refreservation set on this dataset,  
    # which would be freed if the refreservation was removed.
    property :usedrefreserv,    Integer, :min => 0, :required => true

    # This property is on if the snapshot has been marked  for deferred  destroy
    property :defer_destroy,    Boolean

    # This property is set to the number of user holds on this snapshot.
    property :userrefs,         Integer, :min => 0

    # Provides a hint to ZFS  about  handling  of  synchronous requests  in  this dataset.
    property :logbias,          Enum[ :latency, :throughput ], :required => true

    # Controls  whether  deduplication  is  in  effect  for  a dataset.
    property :dedup,            Enum[ :on, :off, :verify, :sha256 ], :required => true

    # The mlslabel property is a sensitivity label that determines if 
    # a dataset can be mounted in a zone on a system with Trusted Extensions enabled.
    property :mlslabel,         String

    # Determines the degree to which file system  transactions are  synchronized.
    property :sync,             Enum[ :standard, :always, :disabled ]

    # Defines the encryption algorithm and key length that  is
    # used for the encrypted dataset. The on value is equal to aes-128-ccm.
    property :crypt,            Enum[ :off, :aes_128_ccm, :aes_129_ccm, :aes_256_ccm, :aes_128_gcm, :aes_192_gcm, :aes_256_gcm ]

    # Defines the format and location of the  key  that  wraps the  dataset  keys.
    property :keysourceformat,        Enum[ :none, :raw, :hex, :passphrase ]
    property :keysourcelocation,      Enum[ :none, :prompt, :file ]

    # Identifies the encryption key status  for  the  dataset. The  
    # availability  of  a  dataset's  key is indicated by showing 
    # the status  of  available  or  unavailable.
    property :keystatus,        Enum[ :none, :unavailable, :available ]

    # The date of the last data encryption key change
    property :rekeydate,        DateTime

    # Indicates whether the file system restricts  users  from giving  
    # away  their  files  by  means of chown(1) or the chown(2) system call
    property :rstchown,         Boolean

    # Unknown
    property :caimaninstall,    String
    property :libbeuuid,        String

end



