require 'net/ssh'

class ZSSHException < Exception
end

class ZSSH
  def initialize(host, options={})
    raise ArgumentError if not host.respond_to? 'hostname'
    raise ZSSHException, "No SSH username or key data for #{host.hostname}." if not (host.ssh_user || host.ssh_key)
    begin
      @session = self.class.create_session(host)
    rescue Timeout::Error
      raise ZSSHException, "Could not connect to #{host.hostname} because the connection timed out."
    rescue Errno::EHOSTUNREACH
      raise ZSSHException, "Could not connect to #{host.hostname} because the host is unreachable."
    rescue Errno::ECONNREFUSED
      raise ZSSHException, "Could not connect to #{host.hostname} because the connection was refused."
    rescue Net::SSH::AuthenticationFailed
      raise ZSSHException, "Authentication for #{host.hostname} as #{host.ssh_user} failed."
    end
  end

  def request_update
    @session.exec! "/usr/bin/updater.py"
  end

  def create_snapshot(dataset, options={})
    options[:name] ||= Time.now.strftime "%Y%m%d-%H%M%S"
    options[:name] = options[:name].gsub(/[^0-9A-Za-z\-]/, '')[0..25]
    snapcmd = "/usr/bin/sudo /usr/sbin/zfs snapshot #{dataset.name.sub(/-/, '/')}@#{options[:name]}" 
    snapoutput = @session.exec! snapcmd do |ch, stream, data|
      if stream == :stderr
        raise StandardError.new(data)
      end
    end
    request_update
  end
  
  def close
    @session.close
    @session.closed?
  end

  def self.create_session(host)
    Net::SSH.start(host.hostname, host.ssh_user, :key_data => [host.ssh_key])
  end
end
