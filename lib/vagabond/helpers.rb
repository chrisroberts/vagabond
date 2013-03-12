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
  end
end
