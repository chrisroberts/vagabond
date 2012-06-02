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
        res[item_info.state] ||= []
        res[item_info.state] << item
      end
      res
    end

    # Because I'm lazy
    def next_ip(base)
      parts = base.split('.')
      n_bit = parts.last.to_i + 1
      n_bit = 2 if n_bit > 254
      parts[parts.size - 1] = n_bit
      parts.join('.')
    end
  end
end
