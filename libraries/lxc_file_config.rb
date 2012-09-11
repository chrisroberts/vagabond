class LxcFileConfig

  attr_reader :network
  attr_reader :base

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
          raise "ACK! -> #{name}"
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
