class Lxc
  class << self

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

    # NOTE: This sleep business needs to be removed once
    #   retries are working correctly 
    def container_ip(name, retries=0)
      ip_file = File.join(container_path(name), 'rootfs', 'tmp', '.my_ip')
      (retries.to_i + 1).times do
        if(File.exists?(ip_file))
          ip = File.read(ip_file).strip
          return ip unless ip.empty?
        end
        Chef::Log.info "LXC IP discovery: Waiting to see if container shows up"
        sleep(3)
      end
      raise "Container (#{name}) is currently not running!" unless Lxc.running?(name)
      nil
    end

    def container_path(name)
      "/var/lib/lxc/#{name}"
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

    def run_command(cmd)
      @cmd_proxy ||= Class.new.send(:include, Chef::Mixin::ShellOut).new
      @cmd_proxy.shell_out!(cmd)
    end

  end
end
