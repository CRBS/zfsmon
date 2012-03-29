require 'sinatra'
require 'data_mapper'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/zfsdata.db")
require 'zfsmon_data_objects'

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

get '/' do
    erb :index
end


# Host-level operations

get '/:host' do
    if params[:host].is_int?
        @host = ZFSHost.get params[:host]
    else
        @host = ZFSHost.get :hostname => params[:host]
    
    if @host
        erb :host
    else
        erb :hostnotfound
end

post '/:host' do
    
