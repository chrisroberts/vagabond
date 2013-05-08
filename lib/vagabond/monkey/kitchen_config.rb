require 'kitchen/config'

module Vagabond
  module MonkeyPatch
    module KitchenConfig
      def clusters
        @clusters Mash.new[
          *(
            Array(data[:clusters]).map{ |name|
              [name, suites.detect{ |suite| suite.name == name }]
            }.flatten
          )
        ]
    end
  end
end

Kitchen::Config.send(:include, Vagabond::MonkeyPatch::KitchenConfig)
