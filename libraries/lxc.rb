require 'pathname'
require 'tmpdir'

class Lxc
  class CommandFailed < StandardError
  end

  # Pathname#join does not act like File#join when joining paths that
  # begin with '/', and that's dumb. So we'll make our own Pathname,
  # with a #join that uses File
  class Pathname < ::Pathname
    def join(*args)
      self.class.new(::File.join(self.to_path, *args))
    end
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
      ip = proc_detected_address || hw_detected_address || leased_address || lxc_stored_address
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
    if(container_config.readable?)
      hw = File.readlines(container_config).detect{|line|
        line.include?('hwaddr')
      }.to_s.split('=').last.to_s.downcase
      if(File.exists?(container_config) && !hw.empty?)
        running? # need to do a list!
        ip = File.readlines('/proc/net/arp').detect{|line|
          line.downcase.include?(hw)
        }.to_s.split(' ').first.to_s.strip
        if(ip.to_s.empty?)
          nil
        else
          Chef::Log.info "LXC Discovery: Found container address via HW addr: #{ip}"
          ip
        end
      end
    end
  end

  def proc_detected_address(base='/run/netns')
    if(pid != -1)
      Dir.mktmpdir do |t_dir|
        name = File.basename(t_dir)
        path = File.join(base, name)
        system("#{sudo}mkdir -p #{base}")
        system("#{sudo}ln -s /proc/#{pid}/ns/net #{path}")
        res = %x{#{sudo}ip netns exec #{name} ip -4 addr show scope global | grep inet}
        system("#{sudo}rm -f #{path}")
        ip = res.strip.split(' ')[1].to_s.sub(%r{/.*$}, '').strip
        ip.empty? ? nil : ip
      end
    end
  end

  def sudo
    self.class.sudo
  end
    
  # Full path to container
  def container_path
    Pathname.new(@base_path).join(name)
  end
  alias_method :path, :container_path

  # Full path to container configuration file
  def container_config
    container_path.join('config')
  end
  alias_method :config, :container_config

  def container_rootfs
    container_path.join('rootfs')
  end
  alias_method :rootfs, :container_rootfs

  def expand_path(path)
    container_rootfs.join(path)
  end

  def state
    self.class.info(name)[:state]
  end

  def pid
    self.class.info(name)[:pid]
  end

  # Start the container
  def start
    run_command("#{sudo}lxc-start -n #{name} -d")
    run_command("#{sudo}lxc-wait -n #{name} -s RUNNING", :allow_failure_retry => 2)
  end

  # Stop the container
  def stop
    run_command("#{sudo}lxc-stop -n #{name}", :allow_failure_retry => 3)
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
    run_command("#{sudo}lxc-wait -n #{name} -s STOPPED", :allow_failure => true, :timeout => 120)
    # This block is for fedora/centos/anyone else that does not like lxc-shutdown
    if(running?)
      container_command('shutdown -h now')
      run_command("#{sudo}lxc-wait -n #{name} -s STOPPED", :allow_failure => true)
      # If still running here, something is wrong
      if(running?)
        raise "Failed to shutdown container: #{name}"
      end
    end
  end

  def direct_container_command(command, args={})
    com = "#{sudo}ssh root@#{args[:ip] || container_ip} -i /opt/hw-lxc-config/id_rsa -oStrictHostKeyChecking=no '#{command}'"
    begin
      cmd = Mixlib::ShellOut.new(com,
        :live_stream => args[:live_stream],
        :timeout => args[:timeout] || 1200
      )
      cmd.run_command
      cmd.error!
      true
    rescue
      raise if args[:raise_on_failure]
      false
    end
  end
  alias_method :knife_container, :direct_container_command

  # Simple helper to shell out
  def run_command(cmd, args={})
    retries = args[:allow_failure_retry].to_i
    begin
      shlout = Mixlib::ShellOut.new(cmd, 
        :logger => Chef::Log.logger, 
        :live_stream => STDOUT,
        :timeout => args[:timeout] || 1200,
        :environment => {'HOME' => detect_home}
      )
      shlout.run_command
      shlout.error!
    rescue Mixlib::ShellOut::ShellCommandFailed, CommandFailed, Mixlib::ShellOut::CommandTimeout
      if(retries > 0)
        Chef::Log.warn "LXC run command failed: #{cmd}"
        Chef::Log.warn "Retrying command. #{args[:allow_failure_retry].to_i - retries} of #{args[:allow_failure_retry].to_i} retries remain"
        sleep(0.3)
        retries -= 1
        retry
      elsif(args[:allow_failure])
        true
      else
        raise
      end
    end
  end

  # Detect HOME environment variable. If not an acceptable
  # value, set to /root or /tmp
  def detect_home(set_if_missing=false)
    if(ENV['HOME'] && Pathname.new(ENV['HOME']).absolute?)
      ENV['HOME']
    else
      home = File.directory?('/root') && File.writable?('/root') ? '/root' : '/tmp'
      if(set_if_missing)
        ENV['HOME'] = home
      end
      home
    end
  end
  
  # cmd:: Shell command string
  # retries:: Number of retry attempts (1 second sleep interval)
  # Runs command in container via ssh
  def container_command(cmd, retries=1)
    begin
      detect_home(true)
      direct_container_command(cmd,
        :ip => container_ip(5),
        :live_stream => STDOUT,
        :raise_on_failure => true
      )
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
