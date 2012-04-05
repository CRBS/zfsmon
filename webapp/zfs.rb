require 'sinatra'
require 'data_mapper'
require 'yaml'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/zfsdata.db")

require "#{File.dirname(__FILE__)}/zfsmon_data_objects"
require "#{File.dirname(__FILE__)}/zfs_utils"

DataMapper.finalize.auto_upgrade!

def get_host_record( hostget )
    if hostget.is_int?
        @host = ZFSHost.get hostget.to_i
    else
        @host = ZFSHost.get :hostname => hostget
    end
    return @host
end
   

get '/' do
    erb :index
end


# Host-level operations
get '/:host' do
    @host = get_host_record( params[:host] )
    if @host
        erb :host
    else
        erb :hosterror
    end
end

post '/:host' do
    @host = get_host_record( params[:host] )
    if not @host
        z = ZFSHost.create( :hostname => params[:hostname],
                            :hostdescription => params[:hostdescription],
                            :lastupdate => Time.now )
        if not z.saved?
            status 503
            'DM was unable to create a new host record in the database.'
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
