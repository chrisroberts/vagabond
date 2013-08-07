#encoding: utf-8
module Vagabond
  module Actions
    module Up
      class << self
        def included(klass)
          klass.class_eval do
            class << self
              def _up_options
                [[:auto_provision, :type => :boolean, :default => true]]
              end
            end
          end
        end
      end

      def _up
        name_required!
        if(lxc.exists?)
          if(lxc.running?)
            ui.warn "Node already exists and is running: #{name}"
          else
            ui.info "#{ui.color('Vagabond:', :bold)} Starting node: #{ui.color(name, :green)}"
            lxc.start
            ui.info ui.color('  -> STARTED', :green)
          end
        end
        if(options[:parallel])
          # TODO: Need strategy for chains
          @threads[:up] ||= []
          t_holder = Mash.new
          @threads[:up] << t_holder.update(
            :thread => Thread.new{
              sleep(0.01)
              _create
              begin
                do_provision if options[:auto_provision]
                t_holder[:result] = true
              rescue => e
                t_holder[:result] = false
              end
            }
          )
        else
          if(!lxc.exists?)
            add_link(:create)
          elsif(!lxc.running?)
            add_link(:start)
          elsif(options[:auto_provision])
            add_link(:provision)
          end
        end
      end

    end
  end
end
