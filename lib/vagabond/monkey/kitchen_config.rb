#encoding: utf-8
require 'kitchen/config'

module Vagabond
  module MonkeyPatch
    module KitchenConfig
      def clusters
        unless(@clusters)
          @clusters = Hash[
            *(
              Array(data[:clusters]).map{ |name, suite_names|
                [name, suite_names]
              }.flatten(1)
            )
          ]
          @clusters = Mash.new(@clusters)
        end
        @clusters
      end
    end
  end
end

Kitchen::Config.send(:include, Vagabond::MonkeyPatch::KitchenConfig)
