require 'vagabond'
require 'chef'
require 'chef/knife'

module Vagabond
  class Command
    class Spec
      # Run specs on existing infrastructure
      class Infra < Spec

        # Run specs
        def run!
          run_action 'Configuring Chef via knife configuration' do
            Chef::Knife.new.configure_chef
            nil
          end
          if(arguments.empty?)
            search = "*:*"
          elsif(arguments.size == 1)
            search = arguments.first
          else
            ui.error "Only single argument is supported (search string)"
            raise Error::InvalidRequest.new('Only single argument is allowed for `spec infra`')
          end
          # TODO: update to process through paginated result
          nodes = Chef::Search::Query.new.search(:node, search).first
          ui.confirm "Apply specs to #{nodes.size} nodes"
          ui.info "Running specs on infrastructure matching: #{search.inspect}"
          nodes.each do |node|
            ui.info "Running specs on node #{ui.color(node.name, :bold)}"
            env = build_spec_environment(node)
            run_list_specs(node.run_list).each do |spec_path|
              slim_path = spec_path.sub(/#{Regexp.escape(vagabondfile.directory)}\/?/, '')
              ui.info "Running spec #{slim_path}"
              host_command("rspec #{spec_path}",
                :stream => true,
                :cwd => vagabondfile.directory,
                :environment => env
              )
              ui.info "Completed spec #{ui.color(slim_path, :green, :bold)}"
            end
            ui.info "Completed specs on node #{ui.color(node.name, :bold, :green)}"
          end
          ui.info "Infrastructure spec #{ui.color('complete', :green, :bold)}"
        end

        # Create environment hash for rspec command
        #
        # @param node [Chef::Node]
        # @return [Smash]
        def build_spec_environment(node)
          Smash.new.tap do |env|
            if(opts[:ssh_user])
              env['VAGABOND_SPEC_USER'] = opts[:ssh_user]
            end
            if(opts[:ssh_key])
              env['VAGABOND_SPEC_KEY'] = opts[:ssh_key]
            end
            if(opts[:ssh_attribute])
              env['VAGABOND_SPEC_HOST'] = opts[:ssh_attribute].split('.').inject(node) do |k, m|
                m.send(k) || break
              end
            else
              env['VAGABOND_SPEC_HOST'] = node.ipaddress
            end
          end
        end

      end
    end
  end
end
