#encoding: utf-8

require 'vagabond'

module Vagabond
  class Command
    # Create or destroy node cluster
    class Cluster < Command

      # Create or destroy node cluster
      def run!
        arguments.each do |name|
          if(cluster(name))
            if(options[:destroy])
              info "Destroying cluster #{ui.color(name, :red)}:"
              cluster(name).each do |n_name|
                run_action "Destroying cluster node #{ui.color(n_name, :red)}" do
                  node(n_name, :clusters).destroy!
                end
              end
            else
              info "Building cluster #{ui.color(name, :green)}:"
              Up.new(options.merge(:ui => ui), cluster(name)).execute!
            end
          else
            error "Cluster does not exist: #{name} (performing no tasks)"
          end
        end
      end
    end

  end
end
