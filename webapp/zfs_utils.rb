# Extra methods for parsing and data transformation and hashes for other things
require 'action_view'
require 'active_support/all'
module ZUtil
    extend ActionView::Helpers::DateHelper
    # Need to move these hashes into a database or something at some point.
    ZPOOL_DESCRIPTIONS = { 'name'         =>  'The name of the ZFS pool',
                            'size'        =>  'The total size of the storage pool',
                            'cap'         =>  'Percentage of pool space used.',
                            'free'        =>  'The number of unallocated blocks',
                            'alloc'       =>  'The amount of storage space in the pool that has been physically allocated.',
                            'altroot'     =>  'Alternate root directory.  If set, this directory is prepended to ' +
                                              'any mount points within the pool.',
                            'health'      =>  'The current health of the pool.',
                            'guid'        =>  'The globally-unique identifier for this pool.',
                            'version'     =>  'The current on-disk version of the pool.',
                            'bootfs'      =>  'Identifies the default bootable dataset for the root pool.',
                            'delegation'  =>  'Controls whether a non-privileged user is granted access based on ' +
                                              'the dataset permissions defined on the dataset.',
                            'replace'     =>  'Controls automatic device replacement. If set to "off", device replacement ' + 
                                              'must be initiated by the administrator by using the "zpool  replace" command. ' +
                                              'If set  to "on", any new device found in the same physical location as a device ' +
                                              'that previously belonged to the pool is automatically formatted and replaced.',
                            'cachefile'   =>  'Controls the location of where the pool configuration is cached.',
                            'failmode'    =>  'Controls the system behavior in the event of catastrophic pool failure.',
                            'listsnaps'   =>  'Controls whether information about snapshots associated with this pool is ' +
                                              'output when "zfs list" is run without the -t option. The default value is "off".',
                            'expand'      =>  'Controls automatic pool expansion when the underlying LUN is grown. If set to on, ' +
                                              'the pool will be resized according to the size of the expanded device.',
                            'dedup'       =>  'The deduplication ratio specified for a pool, expressed as a multiplier.',
                            'dedupditto'  =>  'Sets a threshold for number of copies. If the reference count for a deduplicated ' +
                                              'block goes above this threshold, another ditto copy of the block is stored automatically.',
                            'rdonly'      =>  'Controls whether the pool can be modified.'
                        }

    ZDS_DESCRIPTIONS = {    'name'        =>  'The name of the dataset',
                            'dsuniqueid'  =>  'A unique ID for the dataset (the SHA-1 hash of the hostname + the name of the dataset)',
                            'type'        =>  'The type of dataset: filesystem, volume, or snapshot.',
                            'creation'    =>  'The time this dataset was created',
                            'volsize'     =>  'For volumes, specifies the logical size of the volume. Nil on non-volume datasets.',
                            'used'        =>  'The amount of space consumed by this dataset and all its descendants.',
                            'avail'       =>  'The amount of space available to the dataset and all its children, assuming that there is ' +
                                              'no other activity in the pool.',
                            'refer'       =>  'The amount of data that is accessible by this dataset, which may or may not be shared with ' +
                                              'other datasets in the pool.',
                            'ratio'       =>  'The compression ratio multiplier for this dataset.',
                            'mounted'     =>  'Is this filesystem currently mounted?',
                            'origin'      =>  'For cloned file systems or volumes,  the snapshot from which the clone was created. ' +
                                              '\'-\' if not a clone.',
                            'quota'       =>  'A hard limit on the amount of space used by this dataset and descendants.',
                            'reserv'      =>  'The minimum amount of space guaranteed to a dataset and its descendants.',
                            'volblock'    =>  'For volumes, specifies the block size of the volume.',
                            'recsize'     =>  'The suggested block size for files in  the  filesystem. \'-\' for non-filesystems.',
                            'mountpoint'  =>  'The mount point used for this file system',
                            'sharenfs'    =>  'Controls whether the file system is shared via NFS',
                            'checksum'    =>  'Controls the checksum used to verify data integrity.',
                            'compress'    =>  'Controls the compression algorithm used for this dataset.',
                            'atime'       =>  'Controls whether the access time for files is updated when they are read.',
                            'devices'     =>  'Controls whether device nodes can be opened on this filesystem',
                            'exec'        =>  'Controls whether processes can be executed from within this filesystem.',
                            'setuid'      =>  'Controls whether the set-UID bit is respected for this filesystem.',
                            'rdonly'      =>  'Controls whether this dataset can be modified.',
                            'zoned'       =>  'Controls whether the dataset is managed from a non-global zone',
                            'snapdir'     =>  'Controls whether the .zfs directory is hidden or visible',
                            'aclinherit'  =>  'Controls how ACL entries are inherited when files and directories are created. ' +
                                              'See man page for more info.',
                            'canmount'    =>  'Controls whether this filesystem can be mounted.',
                            'xattr'       =>  'Controls whether extended attributes are enabled.',
                            'copies'      =>  'Controls the number of copies of data stored for this dataset',
                            'version'     =>  'The on-disk version of this file system.',
                            'utf8only'    =>  'Indicates whether the file  system should reject file names that include characters ' +
                                              'that are not present in the UTF-8 character code set.',
                            'normalization'=> 'Indicates whether the file system should perform a unicode normalization of file ' +
                                              'names whenever two file names are compared, and which normalization algorithm should be used.',
                            'case'        =>  'Indicates whether the file name matching algorithm used by the file system should be ' +
                                              'case-sensitive, case-insensitive, or allow a combination of both styles',
                            'vscan'       =>  'Controls whether regular files should be scanned for viruses when a file is opened and closed.',
                            'nbmand'      =>  'Controls whether the file system should be mounted with nbmand (non-blocking mandatory locks).',
                            'sharesmb'    =>  'Controls whether the file system is shared by using the Solaris SMB service.',
                            'refquota'    =>  'Limits the amount of space a dataset can consume.',
                            'refreserv'   =>  'The minimum amount of space guaranteed to a dataset, not including its descendants.',
                            'primarycache'=>  'Controls what is cached in the primary cache (ARC).',
                            'secondarycache'=>'Controls what is cached in the secondary cache (L2ARC).',
                            'usedsnap'    =>  'The amount of space consumed by snapshots of this dataset.',
                            'usedds'      =>  'The amount of space used by this dataset itself, which would be freed if the ' +
                                              'dataset were destroyed',
                            'usedchild'   =>  'The amount of space used by children of this dataset, which would be freed if ' +
                                              'all the dataset\'s children were destroyed.',
                            'usedrefreserv'=> 'The amount of space used by a refreservation set on this dataset, which ' +
                                              'would be freed if the refreservation was removed.',
                            'defer_destroy'=> 'This property is on if the snapshot has been marked for deferred destroy',
                            'userrefs'    =>  'This property is set to the number of user holds on this snapshot.',
                            'logbias'     =>  'Provides a hint to ZFS about handling of synchronous requests in this dataset.',
                            'dedup'       =>  'Controls whether deduplication is in effect for a dataset.',
                            'mlslabel'    =>  'The mlslabel property is a sensitivity label that determines if a dataset can ' +
                                              'be mounted in a zone on a system with Trusted Extensions enabled.',
                            'sync'        =>  'Determines the degree to which file system transactions are synchronized.',
                            'crypt'       =>  'Defines the encryption algorithm and key length that is used for the encrypted ' +
                                              'dataset. The on value is equal to aes-128-ccm.',
                            'keysourceformat'=>'Defines the format of the key that wraps the dataset keys.',
                            'keysourcelocation'=>'Defines the location of the  key that wraps the dataset keys.',
                            'keystatus'   =>  'Identifies the encryption key status for the dataset. The availability ' +
                                              'of a dataset\'s key is indicated by showing the status of available or unavailable.',
                            'rekeydate'   =>  'The date of the last data encryption key change',
                            'rstchown'    =>  'Indicates whether the file system restricts users from giving away their files ' +
                                              'by means of chown(1) or the chown(2) system call'
                            }

    ZPOOL_HEALTH = {        'degraded'    =>  'One or more top-level vdevs are in the degraded state because one or more component ' +
                                              'devices are offline. Sufficient replicas exist to continue functioning.',
                            'faulted'     =>  'One or more top-level vdevs are in the faulted state because one or more component ' +
                                              'devices are offline. Insufficient replicas exist to continue functioning.',
                            'offline'     =>  'The device was explicitly taken offline by the "zpool offline" command.',
                            'online'      =>  'The device is online and functioning.',
                            'removed'     =>  'The device was physically removed while the system was running.',
                            'unavail'     =>  'The device could not be opened.'
                    }

    ZFS_ENUM_FIELDS = ['health', 'failmode', 'type', 'checksum', 'compress', 'snapdir',
                        'aclinherit', 'canmount', 'version', 'normalization', 'case',
                        'primarycache', 'secondarycache', 'logbias', 'dedup', 'sync',
                        'crypt', 'keysourceformat', 'keysourcelocation', 'keystatus']

    ZFS_STUPID_BOOLEAN_FIELDS = ['setuid', 'sharesmb', 'zoned', 'utf8only', 'xattr', 'atime',
                                  'mounted', 'exec', 'vscan', 'defer_destroy', 'nbmand',
                                  'devices', 'rstchown']

    ZFS_DATASET_SIZE_FIELDS = ['avail', 'quota', 'recsize', 'refer', 'refquota', 
                              'refreserv', 'reserv', 'used', 'usedchild', 'usedds', 
                              'usedrefreserv', 'usedsnap', 'volblock', 'volsize']

    ZFS_DATASET_FIELDS = ['name', 'type', 'creation', 'used', 'avail', 'refer', 'ratio',
                        'mounted', 'origin', 'quota', 'reserv', 'volblock', 'recsize',
                        'mountpoint', 'sharenfs', 'checksum', 'compress', 'atime', 'devices', 
                        'exec', 'setuid', 'rdonly', 'zoned', 'snapdir', 'aclinherit', 
                        'canmount', 'xattr', 'copies', 'version', 'utf8only', 
                        'normalization', 'case', 'vscan', 'nbmand', 'sharesmb', 
                        'refquota', 'refreserv', 'primarycache', 'secondarycache', 
                        'usedsnap', 'usedds', 'usedchild', 'usedrefreserv', 
                        'defer_destroy', 'userrefs', 'logbias', 'dedup', 'mlslabel', 
                        'sync', 'crypt', 'keysource', 'keystatus', 'rekeydate', 
                        'rstchown',  'org.opensolaris.caiman:install', 
                        'dsuniqueid']

    ZFS_POOL_SIZE_FIELDS = ['size', 'free', 'alloc']

    ZFS_POOL_FIELDS = ['name', 'size', 'cap', 'altroot', 'health', 'guid', 
                          'version', 'bootfs', 'delegation', 'replace', 'cachefile', 
                          'failmode', 'listsnaps', 'expand', 'dedupditto', 'dedup', 
                          'free', 'alloc', 'rdonly', 'dsuniqueid']

    def ZUtil.get_host_record( hostget )
        if hostget.is_int?
            @host = ZFSHost.get hostget.to_i
        else
            @host = ZFSHost.first :hostname => hostget
        end
        return @host
    end

    def ZUtil.get_pool_record( hostrec, pool )
        if hostrec
          hostrec.pools.first_or_create :host => hostrec, :name => pool
        else
          nil
        end
    end

    def ZUtil.get_ds_record( hostrec, filesystem )
        hostrec.datasets.first_or_create :host => hostrec, :name => filesystem
    end

    def ZUtil.get_vdev_hierarchy( root_vdev )
        v = {}
        v['name'] = root_vdev.name
        v['state'] = root_vdev.state
        v['errors'] = {}
        v['errors']['read'] = root_vdev.read_errors
        v['errors']['write'] = root_vdev.write_errors
        v['errors']['cksum'] = root_vdev.cksum_errors
        v['children'] = []
        if root_vdev.children && root_vdev.children.size > 0
            root_vdev.children.each do |c|
                v['children'] << ZUtil.get_vdev_hierarchy(c)
            end
        end
        return v
    end

    def ZUtil.generate_collapsible_vdev_tree( root, indent=1, parent_css_id='' )
        css_id = root.name + root.id.to_s
        header_size = parent_css_id == '' ? 'large' : 'medium'
        total_errors = root.read_errors + root.write_errors + root.cksum_errors
        data_content = <<-END
          <table>
            #{%[<tr><td><strong>State: </strong></td><td>#{root.state}</td></tr>] if root.state }
            <tr><td>&nbsp;</td><td>&nbsp;</td></tr>
            <tr>
              <td><strong>Errors: </strong></td>
              <td><table>
                    <tr><td>Read</td><td>#{root.read_errors}</td></tr>
                    <tr><td>Write</td><td>#{root.write_errors}</td></tr>
                    <tr><td>Checksum</td><td>#{root.cksum_errors}</td></tr>
                  </table>
              </td>
            </tr.
          </table>
        END

        html = <<-END
          <p>#{%[<strong style="font-size: ] + header_size + %[">] if root.children && root.children.size > 0}
            <span class="status_pop" id="pop-#{css_id}" title="Status of #{ if (root.name.length > 11) then (root.name[0..3] + root.name[-2..-1]) else root.name end}"
             data-content="#{data_content}">
              <a href="##{css_id}" data-toggle="collapse" data-target="##{css_id}" 
               data-parent="##{parent_css_id}"#{%[ style="color: red !important; font-weight: bold;"] if (total_errors >= 5 || (root.state && root.state.downcase != 'online'))}>
                #{root.name}
              </a>
            </span>
          #{'</strong>' if root.children.size > 0}</p>
        END
        if root.children && root.children.size > 0
          html << %[\n<div id="#{css_id}" class="collapse" style="margin-left: #{indent*15}px">]
            root.children.each do |c|
                next if c.id == root.id
                html << ZUtil.generate_collapsible_vdev_tree(c, indent, css_id)
            end
          return html << "\n</div>"
        else
          return html
        end
    end

    def ZUtil.get_desc( datatype, field )
        if datatype == :pool then
            r = ZPOOL_DESCRIPTIONS[field]
        elsif datatype == :ds then
            r = ZDS_DESCRIPTIONS[field]
        end
        if not r
            r = 'Description not found'
        end
        return r
    end

    def ZUtil.convert_human_bytes( size )
        return '' if not size
        suffixes = ['bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
        i = 0
        while size > 1000 do
            size = size / 1000.0
            i += 1
        end
        return "#{format('%.2f', size)} #{suffixes[i]}"
    end

    def ZUtil.build_bool_label( field, tf_names=nil)
        # tf_names is an optional hash to replace the words used for the boolean value
        # on/off by default, but some fields want yes/no, etc.
        tf_names ||= { true => 'on', false => 'off' }
        return '' if field == nil
        str = "<span class=\"label"
        if field then
            str << " label-info\">"
        else
            str << "\">"
        end
        str << tf_names[field] << "</span>"
        return str
    end

    def ZUtil.build_breadcrumb_string( elements )
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

    def ZUtil.get_status_for_host(host)
        host.pools.each do |p|
          return p.health if [:degraded, :faulted, :unavail].include? p.health
        end
        return :online
    end

    def ZUtil.get_background_color_for_status(status)
        case status
          when :degraded
            'background-color: #FFBD47'
          when :faulted
            'background-color: #FF8F50'
          when :unavail
            'background-color: #6F6F6F; color: #FFFFFF'
          else
            ''
        end
    end
end # module end

class String
    def is_int?
        Integer(self, 10)
        rescue ArgumentError
            false
        else
            true
    end
end

