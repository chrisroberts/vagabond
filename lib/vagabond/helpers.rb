module Vagabond
  module Helpers
    private
    def sudo
      case @vagabondfile[:sudo]
      when TrueClass
        'sudo '
      when String
        "#{@vagabondfile[:sudo]} "
      end
    end

    def debug(s)
      ui.info "#{ui.color('DEBUG:', :red, :bold)} #{s}" if Config[:debug]
    end
    
    def generated_name(n=nil)
      n = name unless n
      if(@_gn.nil? || @_gn[n].nil?)
        @_gn ||= Mash.new
        s = Digest::MD5.new
        s << @vagabondfile.path
        @_gn[n] = "#{n}-#{s.hexdigest}"
      end
      @_gn[n]
    end
    
  end
end
