#!/usr/bin/env ruby
require 'daemons'

pwd = Dir.pwd
Daemons.run_proc('zfs.rb', { :dir_mode => :normal, :dir => "#{pwd}/pids" }) do
    Dir.chdir pwd
    exec "ruby zfs.rb -p 4567 -e production"
end