require 'sinatra'
require 'data_mapper'
require 'yaml'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/zfsdata.db")
require "#{File.dirname(__FILE__)}/zfsmon_data_objects"

DataMapper.finalize.auto_upgrade!


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
    @rec = get_host_record( params[:host] )
    # Update existing record
    if @rec
        @data = request['yaml']
        @data = YAML::load @data
        @data.each_pair { |key, value|
            sym = key.to_sym
            @rec.attributes = { sym => value }
        }
        if not @rec.save
            erb :hosterror
        else
            redirect '/' + params[:host]
        end
    # Create new record
    else
        @data = request['yaml']
        @data = YAML::load @data
        
        
    end
end
