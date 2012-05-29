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

helpers ZUtil

helpers do
    def host_not_found( request="" )
        status 404
        "The provided host ID or hostname " + request.to_s + " could not be found in the database."
    end
    def pool_not_found( request="" )
        status 404
        "The provided pool ID or name " + request.to_s + " could not be found in the database."
    end
end
get '/' do
    @allhosts = ZFSHost.all :order => [ :hostname.asc ]
    @title = 'All Hosts'
    erb :allhosts
end


# Host-level operations
get '/:host/?' do
    @host = ZUtil.get_host_record params[:host]
    if @host
        @title = 'Host View'
        erb :hostview
    else
        host_not_found params[:host]
    end
end

post '/:host/?' do
    @host = ZUtil.get_host_record params[:host]
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
    @host = ZUtil.get_host_record params[:host]
    @title = "All pools on #{@host.hostname}"
    erb :host_poolsview
end

get '/:host/pools/:pool/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @pool = ZUtil.get_pool_record @host, params[:pool]
    if not @pool
        status 404
        "The requested pool could not be found on " + params[:hostname] + "."
    end
    @title = "Details for #{@pool.name}"
    erb :pooldetail
end

post '/:host/pools/:pool/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end

    @pool = ZUtil.get_pool_record @host, params[:pool]
    request.POST.each do |k, v|
        if not ZUtil::ZFS_POOL_FIELDS.include? k
            next
        else
            if ZUtil::ZFS_POOL_SIZE_FIELDS.include? k
                if v == '-' then
                    v = 0
                else
                    v = v.to_i
                end
            end
            
            if ZUtil::ZFS_ENUM_FIELDS.include? k
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
            if v == '-' and not ZUtil::ZFS_POOL_SIZE_FIELDS.include? k
                next
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
    if not @pool.saved? then
        puts "------- error saving #{@pool.name} -------"
        @pool.errors.each do |e|
            puts e.to_s
        end
    end
end

get '/:host/datasets/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @title = "All datasets on #{@host.hostname}"
    erb :host_dsview
end

get '/:host/datasets/:ds/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @ds = ZUtil.get_ds_record @host, params[:ds]
    @title = "Details for #{@ds.name}"
    erb :dsdetail
end

get '/:host/datasets/:ds/snapshots/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @ds = ZUtil.get_ds_record @host, params[:ds]
    @snaps = @ds.snapshots
    @title = "All snapshots of #{@ds.name} on #{@host.hostname}"
    redirect '/'
end

post '/:host/datasets/:ds/snapshots/:snap/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @ds = ZUtil.get_ds_record @host, params[:ds]
    @snap = @ds.snapshots.first_or_create :dataset => @ds, :name => params[:snap]
    # puts "For #{params[:snap]}"
    request.POST.each do |k, v|
        # puts "before key: #{k} = #{v}"
        if not ZUtil::ZFS_DATASET_FIELDS.include? k
            next
        end
        if ZUtil::ZFS_DATASET_SIZE_FIELDS.include? k
            v = v.to_i
        end
        next if not k.respond_to? 'to_sym'
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
        if ZUtil::ZFS_STUPID_BOOLEAN_FIELDS.include? k and v == '-'
                v = false
        end
        
        if k == 'mounted'
            v = (v == 'yes') ? true : false
        end
        
        if k == 'name'
            v.gsub! '/', '-'
        end

        if k == 'normalization' and not v
            v = :none
        end
        
        if k == 'checksum' and v == 'on'
            v = 'auto'
        end
        
        if ['canmount', 'snapdir', 'case', 'aclinherit', 'normalization'].include? k and v == '-'
            v = 'na'
        end
        
        # Fields that only apply to filesystems... leave nil if '-'
        if ['userrefs', 'version', 'rekeydate', 'volsize', 
            'checksum', 'compress', 'rdonly', 'copies', 'logbias', 'dedup', 'sync'].include? k and v == '-'
            next
        end
        
        # ratio is a float but ZFS puts an 'x' on the end
        if k == 'ratio'
            v = v[0..-1].to_f
        end
        # puts "key: #{k} = #{v}"
        @snap.attribute_set k.to_sym, v
    end
    if @snap.dirty?
    @host.update :lastupdate => Time.now
    @snap.attributes :lastupdate => Time.now
    @snap.save
    end
    if not @snap.saved? then
        puts "------- error saving #{@snap.name} -------"
        @snap.errors.each do |e|
            puts e.to_s
        end
    end
end

post '/:host/datasets/:ds/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    
    @ds = ZUtil.get_ds_record @host, params[:ds]
    
    request.POST.each do |k, v|
        if not ZUtil::ZFS_DATASET_FIELDS.include? k
            next
        else
            if ZUtil::ZFS_DATASET_SIZE_FIELDS.include? k
                v = v.to_i
            end
            
            if ZUtil::ZFS_ENUM_FIELDS.include? k
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
            if ZUtil::ZFS_STUPID_BOOLEAN_FIELDS.include? k and v == '-'
                    v = false
            end
            
            if k == 'mounted'
                v = (v == 'yes') ? true : false
            end
            
            if k == 'name'
                v.gsub! '/', '-'
            end
            
            if k == 'checksum' and v == 'on'
                v = 'auto'
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
            @ds.attribute_set k.to_sym, v
        end
    end
    @ds.attribute_set :host, @host
    if @ds.dirty?
        @host.update :lastupdate => Time.now
        @ds.attributes :lastupdate => Time.now
        @ds.save
    end
    if not @ds.saved? then
        puts "------- error saving #{@ds.name} -------"
        @ds.errors.each do |e|
            puts e.to_s
        end
    end
end
