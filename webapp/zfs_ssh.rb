require 'net/ssh'

class ZSSH
  def initialize(host, options={})
    raise ArgumentError if not host.respond_to? 'hostname'
    begin
      @session = self.class.create_session(host)
    rescue Timeout::Error
      raise "Could not connect to #{host.hostname} because the connection timed out."
    rescue Errno::EHOSTUNREACH
      raise "Could not connect to #{host.hostname} because the host is unreachable."
    rescue Errno::ECONNREFUSED
      raise "Could not connect to #{host.hostname} because the connection was refused."
    rescue Net::SSH::AuthenticationFailed
      raise "Authentication for #{host.hostname} as #{host.ssh_user} failed."
    end
  end

  def request_update
    return false if not @session
    @session.exec! "/usr/bin/updater.py"
    true
  end

  def create_snapshot(dataset, options={})
    options[:name] ||= Time.now.strftime "%Y%m%d-%H%M%S"
    options[:name] = options[:name].gsub(/[^0-9A-Za-z\-]/i, '')[0..25]
    snapcmd = "/usr/bin/sudo /usr/sbin/zfs snapshot #{dataset.name.sub(/-/, '/')}@#{options[:name]}" 
    snapoutput = @session.exec! snapcmd do |ch, stream, data|
      if stream == :stderr
        raise StandardError.new(data)
      end
    end
  end
  
  def close
    @session.close
    @session.closed?
  end

  def self.create_session(host)
    Net::SSH.start(host.hostname, host.ssh_user, :key_data => [host.ssh_key])
  end
end
