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
        create_node = false
        if(lxc.exists?)
          if(lxc.running?)
            ui.error "Node already exists and is running: #{name}"
          else
            ui.info "#{ui.color('Vagabond:', :bold)} Starting node: #{ui.color(name, :green)}"
            lxc.start
            ui.info ui.color('  -> STARTED', :green)
          end
        else
          create_node = true
        end
        if(options[:parallel])
          @threads[:up] ||= []
          @threads[:up] << Thread.new do
            _create
            do_provision if options[:auto_provision]
          end
        else
          _create
          do_provision if options[:auto_provision]
        end
      end

    end
  end
end
