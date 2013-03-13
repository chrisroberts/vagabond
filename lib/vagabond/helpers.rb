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
    
  end
end
