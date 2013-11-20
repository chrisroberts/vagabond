#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Destroy

      def destroy_cluster(name)
        if(vagabondfile[:clusters][name])
          cluster = vagabondfile[:clusters][name]
        end
        unless(cluster)
          raise VagabondErrors::InvalidName.new("Cluster name provided does not exist: #{name}")
        else
          ui.info "#{ui.color('Vagabond:', :bold)} Destroying cluster - #{ui.color(name, :red)}"
          options[:cluster] = false
          cluster.each do |node_name|
            run_action(:destroy, node_name)
          end
          options[:cluster] = true
        end
      end

      def destroy(name, *names)
        if(options[:cluster])
          destroy_cluster(name)
        else
          all = [name, names].flatten.compact.uniq
          all.each do |name|
            node = load_node(name)
            ui.info "#{ui.color('Vagabond:', :bold)} Destroying node: #{ui.color(name, :red)}"
            if(node.exists?)
              node.destroy
              ui.info ui.color('  -> DESTROYED', :red)
            else
              ui.error "Node not created: #{name}"
            end
          end
        end
      end


      def running?
      end

      def freeze
      end

      def thaw
      end
    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Destroy)
