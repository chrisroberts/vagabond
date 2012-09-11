class Lxc
  attr_reader :name

  class << self
    # List running containers
    def running
      full_list[:running]
    end

    # List stopped containers
    def stopped
      full_list[:stopped]
    end

    # List frozen containers
    def frozen
      full_list[:frozen]
    end

    # name:: name of container
    # Returns if container exists
    def exists?(name)
      list.include?(name)
    end

    # List of containers
    def list
      %x{lxc-ls}.split("\n").uniq
    end

    # name:: Name of container
    # Returns information about given container
    def info(name)
      res = {:state => nil, :pid => nil}
      info = %x{lxc-info -n #{name}}.split("\n")
      parts = info.first.split(' ')
      res[:state] = parts.last.downcase.to_sym
      parts = info.last.split(' ')
      res[:pid] = parts.last.to_i
      res
    end

    # Return full container information list
    def full_list
      res = {}
      list.each do |item|
        item_info = info(item)
        res[item_info[:state]] ||= []
        res[item_info[:state]] << item
      end
      res
    end

    # ip:: IP address
    # Returns if IP address is alive
    def connection_alive?(ip)
      %x{ping -c 1 -W 1 #{ip}}
      $?.exitstatus == 0
    end
  end

  # name:: name of container
  # args:: Argument hash
  #   - :base_path -> path to container directory
  #   - :dnsmasq_lease_file -> path to lease file
  def initialize(name, args={})
    @name = name
    @base_path = args[:base_path] || '/var/lib/lxc'
    @lease_file = args[:dnsmasq_lease_file] || '/var/lib/misc/dnsmasq.leases'
  end

  # Returns if container exists
  def exists?
    self.class.exists?(name)
  end

  # Returns if container is running
  def running?
    self.class.info(name)[:state] == :running
  end

  # Returns if container is stopped
  def stopped?
    self.class.info(name)[:state] == :stopped
  end
 
  # Returns if container is frozen
  def frozen?
    self.class.info(name)[:state] == :frozen
  end

  # retries:: Number of discovery attempt (3 second sleep intervals)
  # Returns container IP
  def container_ip(retries=0)
    retries.to_i.times do
      ip = leased_address || lxc_stored_address
      return ip if ip && self.class.connection_alive?(ip)
      Chef::Log.warn "LXC IP discovery: Failed to detect live IP"
      sleep(3)
    end
    nil
  end

  # Container address via lxc config file
  def lxc_stored_address
    ip = File.readlines(container_config(name)).detect{|line|
      line.include?('ipv4')
    }.to_s.split('=').last.to_s.strip
    if(ip.to_s.empty?)
      nil
    else
      Chef::Log.info "LXC Discovery: Found container address via storage: #{ip}"
      ip
    end
  end

  # Container address via dnsmasq lease
  def leased_address
    ip = nil
    if(File.exists?(@lease_file))
      leases = File.readlines(@lease_file).map{|line| line.split(' ')}
      leases.each do |lease|
        if(lease.include?(name))
          ip = lease[2]
        end
      end
    end
    if(ip.to_s.empty?)
      nil
    else
      Chef::Log.info "LXC Discovery: Found container address via DHCP lease: #{ip}"
      ip
    end
  end

  # Full path to container
  def container_path
    File.join(@base_path, name)
  end
  alias_method :path, :container_path

  # Full path to container configuration file
  def container_config
    File.join(container_path, 'config')
  end
  alias_method :config, :container_config

  def container_rootfs
    File.join(container_path, 'rootfs')
  end
  alias_method :rootfs, :container_rootfs

  # Start the container
  def start
    run_command("lxc-start -n #{name} -d")
    run_command("lxc-wait -n #{name} -s RUNNING")
  end

  # Stop the container
  def stop
    run_command("lxc-stop -n #{name}")
    run_command("lxc-wait -n #{name} -s STOPPED")
  end
  
  # Freeze the container
  def freeze
    run_command("lxc-freeze -n #{name}")
    run_command("lxc-wait -n #{name} -s FROZEN")
  end

  # Unfreeze the container
  def unfreeze
    run_command("lxc-unfreeze -n #{name}")
    run_command("lxc-wait -n #{name} -s RUNNING")
  end

  # Shutdown the container
  def shutdown
    run_command("lxc-shutdown -n #{name}")
    run_command("lxc-wait -n #{name} -s STOPPED")
  end

  # Simple helper to shell out
  def run_command(cmd)
    cmd = Mixlib::ShellOut.new(cmd, 
      :logger => Chef::Log.logger, 
      :live_stream => Chef::Log.logger
    )
    cmd.run_command
    cmd.error!
  end

  # cmd:: Shell command string
  # retries:: Number of retry attempts (1 second sleep interval)
  # Runs command in container via ssh
  def container_command(cmd, retries=1)
    base = "ssh -o StrictHostKeyChecking=no -i /opt/hw-lxc-config/id_rsa #{container_ip(5)} "
    begin
      run_command("#{base} #{cmd}")
    rescue => e
      if(retries.to_i > 0)
        Chef::Log.info "Encountered error running container command (#{cmd}): #{e}"
        Chef::Log.info "Retrying command..."
        retries = retries.to_i - 1
        sleep(1)
        retry
      else
        raise e
      end
    end
  end

end
