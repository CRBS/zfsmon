require 'sinatra'
require 'data_mapper'
require 'yaml'

# DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/zfsdata.db")

require "#{File.dirname(__FILE__)}/zfsmon_data_objects"
require "#{File.dirname(__FILE__)}/zfs_utils"

DataMapper.finalize.auto_upgrade!

configure do
    enable :static
end

get '/' do
    @allhosts = ZFSHost.all :order => [ :hostname.asc ]
    @title = 'All Hosts'
    erb :allhosts
end


# Host-level operations
get '/:host/?' do
    @host = get_host_record params[:host]
    if @host
        @title = 'Host View'
        erb :hostview
    else
        host_not_found params[:host]
    end
end

post '/:host/?' do
    @host = get_host_record params[:host]
    if not @host
        z = ZFSHost.create( :hostname => params[:hostname],
                            :hostdescription => params[:hostdescription],
                            :lastupdate => Time.now )
        if not z.saved?
            status 503
            'DM was unable to create a new host record in the database.'
            z.errors.each do |e|
                puts e
            end
        else
            status 201
            "Successfully created a new host record for " + params[:hostname]
        end
    else
        @host.update( :hostdescription => params[:hostdescription],
                      :lastupdate => Time.now )
        status 200
        "The host record for " + params[:hostname] + " was successfully updated."
    end
end

get '/:host/pools/?' do
    @host = get_host_record params[:host]
    erb :host_poolsview
end

get '/:host/pools/:pool/?' do
    @host = get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @pool = get_pool_record @host, params[:pool]
    if not @pool
        status 404
        "The requested pool could not be found on " + params[:hostname] + "."
    end
    erb :pooldetail
end

post '/:host/pools/:pool/?' do
    @host = get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end

    @pool = get_pool_record @host, params[:pool]
    request.POST.each do |k, v|
        if not $ZFS_POOL_FIELDS.include? k
            next
        else
            if $ZFS_POOL_SIZE_FIELDS.include? k
                v = v.to_i
            end
            
            if $ZFS_ENUM_FIELDS.include? k
                v = v.downcase
            end
            
            if k == 'name'
                v.gsub! '/', '-'
            end

            # ZFS returns 'on' and 'off' for certain fields but DM expects
            # boolean values.
            if v == 'on'
                v = true
            elsif v == 'off'
                v = false
            end

            # Cap is a percentage for some reason
            if k == 'cap'
                v = v[0..-1].to_i
            end

            # Dedup is a float but ZFS puts an 'x' on the end
            if k == 'dedup'
                v = v[0..-1].to_f
            end
            @pool.attribute_set k.to_sym, v
        end
    end
    @pool.attribute_set :host, @host
    if @pool.dirty?
        @host.update :lastupdate => Time.now
        @pool.attributes :lastupdate => Time.now
        @pool.save
    end
end

get '/:host/mounts/?' do
    @host = get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    erb :host_fsview
end

get '/:host/mounts/:mount/?' do
    @host = get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @mount = get_fs_record @host, params[:mount]
    erb :fsdetail
end

post '/:host/mounts/:mount/?' do
    @host = get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    
    @mount = get_fs_record @host, params[:mount]
    
    request.POST.each do |k, v|
        if not $ZFS_MOUNT_FIELDS.include? k
            next
        else
            if $ZFS_MOUNT_SIZE_FIELDS.include? k
                v = v.to_i
            end
            
            if $ZFS_ENUM_FIELDS.include? k
                v = v.downcase
            end
            
            # ZFS returns 'on' and 'off' for certain fields but DM expects
            # boolean values. The unless block is to skip enums where 'on' or 'off' is a valid
            # identifier
            unless ['crypt', 'dedup', 'canmount', 'compress', 'checksum'].include? k
                if v == 'on'
                    v = true
                elsif v == 'off'
                    v = false
                end
            end
            
            # Some fields say that they are 'on' or 'off' in the docs but inexplicably
            # print a '-' instead of off
            if $ZFS_STUPID_BOOLEAN_FIELDS.include? k and v == '-'
                    v = false
            end
            
            if k == 'mounted'
                v = (v == 'yes') ? true : false
            end
            
            if k == 'name'
                v.gsub! '/', '-'
            end
            
            if ['canmount', 'snapdir', 'case', 'aclinherit', 'normalization'].include? k and v == '-'
                v = 'na'
            end
            
            # Fields that only apply to filesystems... leave nil if '-'
            if ['userrefs', 'version', 'rekeydate', 'volsize'].include? k and v == '-'
                next
            end
            
            # ratio is a float but ZFS puts an 'x' on the end
            if k == 'ratio'
                v = v[0..-1].to_f
            end
            @mount.attribute_set k.to_sym, v
        end
    end
    @mount.attribute_set :host, @host
    if @mount.dirty?
        @host.update :lastupdate => Time.now
        @mount.attributes :lastupdate => Time.now
        @mount.save
    end
end