require 'sinatra'
require 'data_mapper'
require 'yaml'
require 'json'

require "#{File.dirname(__FILE__)}/zfsmon_data_objects"
require "#{File.dirname(__FILE__)}/zfs_utils"
require "#{File.dirname(__FILE__)}/zfs_ssh"

configure do
    enable :static
end
$WD = File.dirname(__FILE__)
if $WD == '.' then $WD = Dir.pwd end

# DataMapper::Logger.new(STDOUT, :debug) if (settings.environment != :production)
DataMapper.setup(:default, "sqlite3://#{File.join($WD, 'zfsdata.db')}")
DataMapper.finalize.auto_upgrade!

helpers ZUtil
helpers do
   def make_vdevs(vdev, parent_pool = nil, parent_vdev = nil)
      v = Vdev.new
      v.name = vdev['name']
      v.state = vdev['state']
      if vdev['errors']
        v.read_errors = vdev['errors']['read']
        v.write_errors = vdev['errors']['write']
        v.cksum_errors = vdev['errors']['cksum']
      end
      v.parent_pool = parent_pool
      if not v.save!
        status 500
        raise "Unable to save the vdev hierarchy for #{parent_pool}"
      end
      v.parent_vdev = parent_vdev
      if vdev['children'] && vdev['children'].size > 0
        vdev['children'].each do |c|
          id = make_vdevs(c, parent_pool, v)
          child = Vdev.get(id)
          v.children << child
        end
      end
      if not v.save!
        status 500
        raise "Unable to save the vdev hierarchy for #{parent_pool}"
      else
        return v.id
      end
    end

    def host_not_found( request="" )
        status 404
        "The provided host ID or hostname " + request.to_s + " could not be found in the database."
    end
    
    def pool_not_found( request="" )
        status 404
        "The provided pool ID or name " + request.to_s + " could not be found in the database."
    end
    
    def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="ZFS Monitor v0.2")
          throw :halt, [401, "Not authorized\n"]
        end
    end

    def authorized?
        authorized = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'auth.yml')))
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
        valid = @auth.provided? && @auth.basic? && @auth.credentials && authorized.include?(@auth.credentials[0])
        valid && authorized[@auth.credentials[0]] == @auth.credentials[1]
    end
end

get '/' do
    if params[:show] == 'errored' then
      @allhosts = ZFSHost.errored + ZFSHost.stale
      @show = :errored
    elsif params[:show] == 'healthy' then
      @allhosts = (ZFSHost.all :order => [ :hostname.asc ]) - ZFSHost.errored
      @show = :healthy
    else
      @allhosts = ZFSHost.all :order => [ :hostname.asc ]
      @show = :all
    end
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

put '/:host' do
    protected!
    @host = ZUtil.get_host_record params[:host]
    if not @host
      host_not_found params[:host]
    end
    if params[:ssh_user] && params[:ssh_key]
      @host.update :ssh_user => params[:ssh_user], :ssh_key => params[:ssh_key]
      redirect "/#{params[:host]}"
    elsif params[:userdescription]
      params[:userdescription] = nil if params[:userdescription] == ''
      @host.update :userdescription => params[:userdescription]
      redirect "/#{params[:host]}"
    else
      "There was a problem updating #{params[:host]}."
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
                STDERR.puts e
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
        "The requested pool could not be found on " + params[:host] + "."
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
                v = v.to_i
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
        STDERR.puts "------- error saving #{@pool.name} -------"
        @pool.errors.each do |e|
            STDERR.puts e.to_s
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

post '/:host/datasets/:ds/snapshot' do
    protected!
    @host = ZUtil.get_host_record params[:host]
    if not @host
      host_not_found params[:host]
    end
    @ds = ZUtil.get_ds_record @host, params[:ds]
    begin
      ssh = ZSSH.new @host
      name = params[:snapshot_name].empty? ? nil : params[:snapshot_name]
      ssh.create_snapshot @ds, :name => name
      ssh.request_update
      ssh.close
      redirect "/#{@host.hostname}/datasets/#{@ds.name}"
    rescue ZSSHException => e
      %(<p>Unable to create a snapshot of #{@ds.name} on #{@host.hostname}.<br />#{e.message}<br /><a href="/#{@host.hostname}">Click here</a> to return.</p>)
    end
end

post '/:host/datasets/:ds/snapshots/:snap/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @ds = ZUtil.get_ds_record @host, params[:ds]
    sleep 0.5 if not @ds.saved?

    @snap = @ds.snapshots.first_or_create :dataset => @ds, :name => params[:snap]
    request.POST.each do |k, v|
        if not ZUtil::ZFS_DATASET_FIELDS.include? k
            next
        end
        
        # Just skip these fields. They are not well-defined for snapshots and cause problems.
        if ['copies', 'utf8only', 'case', 'vscan', 'primarycache', 'userrefs', 'logbias', 'crypt', 'rekeydate', 'atime', 'zoned', 'sharesmb'].include? k
            next
        end
        
        if ZUtil::ZFS_DATASET_SIZE_FIELDS.include? k
            v = v.to_i
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
        if ZUtil::ZFS_STUPID_BOOLEAN_FIELDS.include? k && v == '-'
                v = false
        end
        
        if k == 'mounted'
            v = (v == 'yes') ? true : false
        end
        
        if k == 'name'
            v.gsub! '/', '-'
        end

        if k == 'normalization' && !v
            v = :none
        end
        
        if k == 'checksum' && v == 'on'
            v = 'auto'
        end
        
        if ['canmount', 'snapdir', 'case', 'aclinherit', 'normalization'].include? k && v == '-'
            v = 'na'
        end
        
        # Fields that only apply to filesystems... leave nil if '-'
        if ['defer_destroy', 'userrefs', 'version', 'rekeydate', 'volsize', 
            'checksum', 'compress', 'rdonly', 'copies', 'logbias', 'dedup', 'sync'].include? k && v == '-'
            next
        end
        
        # ratio is a float but ZFS puts an 'x' on the end
        if k == 'ratio'
            v = v[0..-1].to_f
        end
        @snap.attribute_set k.to_sym, v
    end
    if @snap.dirty?
    @host.update :lastupdate => Time.now
    @snap.attributes :lastupdate => Time.now
    @snap.save
    end
    if not @snap.saved? then
        STDERR.puts "------- error saving #{@snap.name} -------"
        @snap.errors.each do |e|
            STDERR.puts e.to_s
        end
    end
end

get '/:host/pools/:pool/status.yml' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @pool = ZUtil.get_pool_record @host, params[:pool]
    str = ''
    @pool.vdevs.each do |v|
      str << ZUtil.get_vdev_hierarchy(v) << "\n"
    end
    return str
end

post '/:host/pools/:pool/status/?' do
    @host = ZUtil.get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end
    @pool = ZUtil.get_pool_record @host, params[:pool]
    status = JSON.load(request.body)
    @pool.state = status['state']
    @pool.z_errors = status['errors']
    @pool.scan = status['scan']

    # ditch the existing vdev records
    @pool.vdevs.each {|v| v.destroy!}
    status['config'].each do |v|
      begin
        child = Vdev.get(make_vdevs(v, @pool))
        @pool.vdevs << child if child
      rescue Exception => e
        status 500
        STDERR.puts e.inspect
        return "There was a problem creating the vdev hierarchy for #{@pool.name}."
      end
    end
    if not @pool.save
      STDERR.puts "--- errors saving #{@pool.name}"
      STDERR.puts "--- #{@pool.errors.inspect}"
      status 500
      return "There was a problem saving #{@pool.name}."
    else
      status 200
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
            if ZUtil::ZFS_STUPID_BOOLEAN_FIELDS.include? k && v == '-'
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
            if ['userrefs', 'version', 'rekeydate', 'volsize', 'defer_destroy'].include? k and v == '-'
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
        STDERR.puts "------- error saving #{@ds.name} -------"
        @ds.errors.each do |e|
            STDERR.puts e.to_s
        end
    end
end
    
# DELETE methods 
delete '/:host/?' do
    protected!
    host = ZUtil.get_host_record params[:host]
    if not host
        host_not_found params[:host]
    end
    
    host.pools.destroy
    host.datasets.destroy
    host.destroy

    if host.destroyed?
        redirect '/'
    else    
        status 503
        str = 'An error was encountered attempting to delete ' + params[:host]
        str << "\n" 
        host.errors.each do |e|
            str << e + "\n"
        end     
        str     
    end
end
