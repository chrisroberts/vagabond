class LxcFileConfig

  attr_reader :network
  attr_reader :base

  class << self
    def generate_config(resource)
      config = []
      config << "lxc.utsname = #{resource.utsname}"
      if(resource.aa_profile)
        config << "lxc.aa_profile = #{resource.aa_profile}"
      end
      [resource.network].flatten.each do |net_hash|
        nhsh = Mash.new(net_hash)
        flags = nhsh.delete(:flags)
        %w(type link).each do |k|
          config << "lxc.network.#{k} = #{nhsh.delete(k)}" if nhsh[k]
        end
        nhsh.each_pair do |k,v|
          config << "lxc.network.#{k} = #{v}"
        end
        if(flags)
          config << "lxc.network.flags = #{flags}"
        end
      end
      if(resource.cap_drop)
        config << "lxc.cap.drop = #{Array(resource.cap_drop).join(' ')}"
      end
      %w(pts tty arch devttydir mount mount_entry rootfs rootfs_mount pivotdir).each do |k|
        config << "lxc.#{k.sub('_', '.')} = #{resource.send(k)}" if resource.send(k)
      end
      prefix = 'lxc.cgroup'
      resource.cgroup.each_pair do |key, value|
        if(value.is_a?(Array))
          value.each do |val|
            config << "#{prefix}.#{key} = #{val}"
          end
        else
          config << "#{prefix}.#{key} = #{value}"
        end
      end
      config.join("\n") + "\n"
    end

  end

  def initialize(path)
    raise 'LXC config file not found' unless File.exists?(path)
    @path = path
    @network = []
    @base = Mash.new
    parse!
  end

  private

  def parse!
    cur_net = nil
    File.readlines(@path).each do |line|
      if(line.start_with?('lxc.network'))
        parts = line.split('=')
        name = parts.first.split('.').last.strip
        if(name.to_sym == :type)
          @network << cur_net if cur_net
          cur_net = Mash.new
        end
        if(cur_net)
          cur_net[name] = parts.last.strip
        else
          raise "Expecting 'lxc.network.type' to start network config block. Found: 'lxc.network.#{name}'"
        end
      else
        parts = line.split('=')
        name = parts.first.sub('lxc.', '').strip
        if(@base[name])
          @base[name] = [@base[name], parts.last.strip].flatten
        else
          @base[name] = parts.last
        end
      end
    end
    @network << cur_net if cur_net
  end
end
