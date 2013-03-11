class Lxc
  class CommandFailed < StandardError
  end
  
  attr_reader :name

  class << self

    attr_accessor :use_sudo

    def sudo
      case use_sudo
      when TrueClass
        'sudo '
      when String
        "#{use_sudo} "
      end
    end
        
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
      %x{#{sudo}lxc-ls}.split("\n").uniq
    end

    # name:: Name of container
    # Returns information about given container
    def info(name)
      res = {:state => nil, :pid => nil}
      info = %x{#{sudo}lxc-info -n #{name}}.split("\n")
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
  def container_ip(retries=0, raise_on_fail=false)
    (retries.to_i + 1).times do
      ip = hw_detected_address || leased_address || lxc_stored_address
      return ip if ip && self.class.connection_alive?(ip)
      Chef::Log.warn "LXC IP discovery: Failed to detect live IP"
      sleep(3) if retries > 0
    end
    raise "Failed to detect live IP address for container: #{name}" if raise_on_fail
  end

  # Container address via lxc config file
  def lxc_stored_address
    if(File.exists?(container_config))
      ip = File.readlines(container_config).detect{|line|
        line.include?('ipv4')
      }.to_s.split('=').last.to_s.strip
      if(ip.to_s.empty?)
        nil
      else
        Chef::Log.info "LXC Discovery: Found container address via storage: #{ip}"
        ip
      end
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

  def hw_detected_address
    if(File.exists?(container_config))
      hw = File.readlines(container_config).detect{|line|
        line.include?('hwaddr')
      }.to_s.split('=').last.to_s.strip
      running? # need to do a list!
      ip = File.readlines('/proc/net/arp').detect{|line|
        line.include?(hw)
      }.to_s.split(' ').first.to_s.strip
      if(ip.to_s.empty?)
        nil
      else
        Chef::Log.info "LXC Discovery: Found container address via HW addr: #{ip}"
        ip
      end
    end
  end
  
  def sudo
    self.class.sudo
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

  def expand_path(path)
    File.join(container_rootfs, path)
  end

  # Start the container
  def start
    run_command("#{sudo}lxc-start -n #{name} -d")
    run_command("#{sudo}lxc-wait -n #{name} -s RUNNING", :allow_failure_retry => 2)
  end

  # Stop the container
  def stop
    run_command("#{sudo}lxc-stop -n #{name}")
    run_command("#{sudo}lxc-wait -n #{name} -s STOPPED", :allow_failure_retry => 2)
  end
  
  # Freeze the container
  def freeze
    run_command("#{sudo}lxc-freeze -n #{name}")
    run_command("#{sudo}lxc-wait -n #{name} -s FROZEN", :allow_failure_retry => 2)
  end

  # Unfreeze the container
  def unfreeze
    run_command("#{sudo}lxc-unfreeze -n #{name}")
    run_command("#{sudo}lxc-wait -n #{name} -s RUNNING", :allow_failure_retry => 2)
  end

  # Shutdown the container
  def shutdown
    run_command("#{sudo}lxc-shutdown -n #{name}")
    run_command("#{sudo}lxc-wait -n #{name} -s STOPPED", :allow_failure_retry => 2)
  end

  def knife_container(cmd, ip)
    require 'chef/knife/ssh'
    Chef::Knife::Ssh.load_deps
    k = Chef::Knife::Ssh.new([
      ip, '-m', '-i', '/opt/hw-lxc-config/id_rsa', '--no-host-key-verify', cmd
    ])
    e = nil
    begin
      e = k.run
    rescue SystemExit => e
    end
    raise CommandFailed.new(cmd) if e.nil? || e != 0
  end

  # Simple helper to shell out
  def run_command(cmd, args={})
    retries = args[:allow_failure_retry].to_i
    begin
      shlout = Mixlib::ShellOut.new(cmd, 
        :logger => Chef::Log.logger, 
        :live_stream => STDOUT
      )
      shlout.run_command
      shlout.error!
    rescue Mixlib::ShellOut::ShellCommandFailed, CommandFailed
      if(args[:allow_failure])
        true
      elsif(retries > 0)
        Chef::Log.warn "LXC run command failed: #{cmd}"
        Chef::Log.warn "Retrying command. #{args[:allow_failure_retry].to_i - retries} of #{args[:allow_failure_retry].to_i} retries remain"
        retries -= 1
        retry
      else
        raise
      end
    end
  end

  # cmd:: Shell command string
  # retries:: Number of retry attempts (1 second sleep interval)
  # Runs command in container via ssh
  def container_command(cmd, retries=1)
    begin
      knife_container(cmd, container_ip(5))
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
