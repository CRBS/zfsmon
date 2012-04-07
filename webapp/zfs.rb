require 'sinatra'
require 'data_mapper'
require 'yaml'

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/zfsdata.db")

require "#{File.dirname(__FILE__)}/zfsmon_data_objects"
require "#{File.dirname(__FILE__)}/zfs_utils"

DataMapper.finalize.auto_upgrade!

def get_host_record( hostget )
    if hostget.is_int?
        @host = ZFSHost.get hostget.to_i
    else
        @host = ZFSHost.first :hostname => hostget
    end
    return @host
end

def get_pool_record( hostrec, pool )
    ZFSPool.first_or_create :host => hostrec, :name => pool
end

def host_not_found( request="" )
    status 404
    "The provided host ID or hostname " + request.to_s + " could not be found in the database."
end

def pool_not_found( request="" )
    status 404
    "The provided pool ID or name " + request.to_s + " could not be found in the database."
end

get '/' do
    erb :index
end


# Host-level operations
get '/:host/?' do
    @host = get_host_record params[:host]
    if @host
        "Hostname: #{@host.hostname}\nDescription: #{@host.hostdescription}\nLast Updated: #{@host.lastupdate.to_s}"
    else
        host_not_found params[:host]
    end
end

post '/:host/?' do
    puts params[:host]
    puts request.body.read
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
            "Succesfully created a new host record for " + params[:hostname]
        end
    else
        @host.update( :hostdescription => params[:hostdescription],
                      :lastupdate => Time.now )
        status 200
        "The host record for " + params[:hostname] + " was succesfully updated."
    end
end

get '/:host/pools/?' do
    @host = get_host_record params[:host]
    "Host: #{@host.hostname}\nPools: "
    @host.pools.each { |p| p.name }
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
    erb :poolview
end

post '/:host/pools/:pool/?' do
    @host = get_host_record params[:host]
    if not @host
        host_not_found params[:host]
    end

    @pool = get_pool_record @host, params[:pool]

    request.POST.each do |k, v|
        puts k + " -> " + v
        if not $ZFS_POOL_FIELDS.include? k
            puts "skipping #{k}"
            next
        else
            if $ZFS_POOL_SIZE_FIELDS.include? k
                v = v.to_i
            end
            
            if $ZFS_ENUM_FIELDS.include? k
                v = v.downcase
                puts "converted #{k} to #{v}"
            end
            if k == 'guid'
                v = v.to_s
            end
            if v == 'on'
                v = true
            elsif v == 'off'
                v = false
            end
            puts "setting #{k.to_s} to #{v.to_s}"
            @pool.attributes k.to_sym => v
        end
    end
    if @pool.dirty?
        puts "#{@pool.name} is dirty... saving"
        @pool.attributes :lastupdate => Time.now
        @pool.save
    else
        puts "not saving #{@pool.name}"
    end
    if not @pool.saved?
        @pool.errors.each {|e| puts e }
    end
end
            
            
        

