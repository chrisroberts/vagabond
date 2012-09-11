class Lxc
  class << self

    # TODO: Add configurable bits for this (paths and the like)

    def running?(name)
      info(name)[:state] == :running
    end

    def stopped?(name)
      info(name)[:state] == :stopped
    end
    
    def frozen?(name)
      info(name)[:state] == :frozen
    end

    def running
      full_list[:running]
    end

    def stopped
      full_list[:stopped]
    end

    def frozen
      full_list[:frozen]
    end

    def exists?(name)
      list.include?(name)
    end

    def list
      %x{lxc-ls}.split("\n").uniq
    end

    def info(name)
      res = {:state => nil, :pid => nil}
      info = %x{lxc-info -n #{name}}.split("\n")
      parts = info.first.split(' ')
      res[:state] = parts.last.downcase.to_sym
      parts = info.last.split(' ')
      res[:pid] = parts.last.to_i
      res
    end

    def full_list
      res = {}
      list.each do |item|
        item_info = info(item)
        res[item_info[:state]] ||= []
        res[item_info[:state]] << item
      end
      res
    end

    def container_ip(name, retries=0)
      retries.to_i.times do
        ip = leased_address(name) || lxc_stored_address(name)
        return ip if ip && connection_alive?(ip)
        Chef::Log.warn "LXC IP discovery: Failed to detect live IP"
        sleep(3)
      end
      nil
    end

    def connection_alive?(ip)
      %x{ping -c 1 -W 1 #{ip}}
      $?.exitstatus == 0
    end

    def lxc_stored_address(name)
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

    def leased_address(name)
      ip = nil
      lease_file = '/var/lib/misc/dnsmasq.leases'
      if(File.exists?(lease_file))
        leases = File.readlines(lease_file).map{|line| line.split(' ')}
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

    # TODO: The base path needs to be configurable at some point
    def container_path(name)
      "/var/lib/lxc/#{name}"
    end

    def container_config(name)
      File.join(container_path(name), 'config')
    end

    def start(name)
      run_command("lxc-start -n #{name} -d")
      run_command("lxc-wait -n #{name} -s RUNNING")
    end

    def stop(name)
      run_command("lxc-stop -n #{name}")
      run_command("lxc-wait -n #{name} -s STOPPED")
    end

    def freeze(name)
      run_command("lxc-freeze -n #{name}")
      run_command("lxc-wait -n #{name} -s FROZEN")
    end

    def unfreeze(name)
      run_command("lxc-unfreeze -n #{name}")
      run_command("lxc-wait -n #{name} -s RUNNING")
    end

    def shutdown(name)
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

    def container_command(name, cmd, retries=1)
      base = "ssh -o StrictHostKeyChecking=no -i /opt/hw-lxc-config/id_rsa #{Lxc.container_ip(name, 5)} "
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
end
