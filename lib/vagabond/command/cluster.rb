#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Cluster

      def cluster(name)
        if(vagabondfile[:clusters][name])
          cluster = vagabondfile[:clusters][name]
        end
        unless(cluster)
          raise VagabondErrors::InvalidName.new("Cluster name provided does not exist: #{name}")
        else
          ui.info "#{ui.color('Vagabond:', :bold)} Building cluster - #{ui.color(name, :green)}"
          if(vagabondfile.server?)
            # send commander request
          end
          results = cluster.map do |node_name|
            ui.info "Building #{n} for cluster!"
            result = run_action(:up, node_name)
            if(options[:delay].to_i > 0 && node_name != cluster.last)
              ui.warn "Delay requested between node processing. Sleeping for #{options[:delay].to_i} seconds."
              sleep(options[:delay].to_i)
            end
            {:name => node_name, :result => result}
          end
          if(options[:parallel])
            ui.info "Waiting for parallel completes!"
            wait_for_completion
            results = tasks.values.flatten.map do |task_result|
              {:name => task_result[:name], task_result[:result]}
            end
          end
          failed = results.detect{|res| res == false}
          result_ouput = "\nCluster build #{name}:"
          if(failed)
            ui.error "#{result_output} #{ui.color('FAILED', :red, :bold)}"
          else
            ui.info "#{result_output} #{ui.color('SUCCESS', :green, :bold)}"
          end
          results.each do |result|
            if(result[:result])
              ui.info "  -> #{result[:name]}: #{ui.color('SUCCESS', :green, :bold)}"
            else
              ui.error " -> #{result[:name]}: #{ui.color('FAILED', :red, :bold)}"
            end
          end
        end
      end

    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Cluster)
