#encoding: utf-8

require 'vagabond/constants'

module Vagabond
  module Helpers
    module Naming

      RAND_CHARS = ('a'..'z').map(&:to_s) + ('A'..'Z').map(&:to_s) + (0..9).map(&:to_s)
      GEN_NAME_LENGTH = 10

      private

      def random_name(n=nil)
        n = name unless n
        [n, SecureRandom.hex].compact.join('-')
      end
      
      def generated_name(n=nil)
        seed = vagabondfile.directory.chars.map(&:ord).inject(&:+)
        srand(seed)
        n = name unless n
        if(@_gn.nil? || @_gn[n].nil?)
          @_gn ||= Mash.new
          @_gn[n] = "#{n}-"
          GEN_NAME_LENGTH.times do
            @_gn[n] << RAND_CHARS[rand(RAND_CHARS.size)]
          end
        end
        @_gn[n]
      end
      
      def generate_hash
        Digest::MD5.hexdigest(@vagabondfile.path)
      end
      
    end
  end
end
