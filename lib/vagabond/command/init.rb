#encoding: utf-8

require 'fileutils'
require 'vagabond'

module Vagabond
  class Command
    # Initialize host system
    class Init < Command

      # Set action as serial
      def initialize(*_)
        super
        @serial = true
      end

      # Default version of chef server to provision
      DEFAULT_CHEF_SERVER_VERSION = '11.1.1'

      # Initialize host system
      def run!
        begin
          vagabondfile
        rescue => e
          run_action 'Writing initial Vagabondfile' do
            write_vagabondfile
            nil
          end
        end
        run_action 'Install required cookbooks' do
          FileUtils.cp(
            File.join(File.dirname(File.dirname(__FILE__)), 'Cheffile'),
            File.join(vagabondfile[:global_cache], 'Cheffile')
          )
          if(File.exists?(cheflock = File.join(vagabondfile[:global_cache], 'Cheffile.lock')))
            File.delete(cheflock)
          end
          host_command('librarian-chef update', :cwd => vagabondfile[:global_cache])
          nil
        end
        run_action 'Provisioning host system' do
          dna = write_dna_json
          solo_config = write_solo_config
          provision_system!(solo_config, dna)
          registry.save!
          nil
        end

      end

      # Provision host system
      #
      # @return [TrueClass]
      def provision_system!(config, dna)
        host_command("#{Lxc.sudo}chef-solo -j #{dna} -c #{config}")
      end

      # Write chef solog configuration file
      #
      # @return [String] path
      def write_solo_config
        solo_config = File.join(vagabondfile[:global_cache], 'solo.rb')
        File.write(solo_config, "cookbook_path '#{cookbook_path}'")
        solo_config
      end

      # Write DNA JSON file for provisioning
      #
      # @return [String] path
      def write_dna_json
        config = Smash.new
        vagabondfile.fetch(:nodes, Smash.new).map(&:last).map{|i| i[:template]}.compact.each do |t|
          # TODO: add node read stuffs back so we can inspect attributes
          next if t.count('_') > 1
          config.set(:bases, t, :enabled, true)
        end
        vagabondfile.fetch(:templates, Smash.new).each do |t_name, t_opts|
          config.set(:bases, t_opts[:base], :enabled, true)
          if(t_opts[:memory] && !t_opts[:memory].is_a?(Hash))
            memory = t_opts.delete(:memory)
            t_opts[:memory] = Smash.new(:ram => memory.to_s)
          end
          template_name = "#{t_name}_#{vagabondfile.fid}"
          config.set(:customs, template_name, t_opts)
          local_registry.set(:templates, t_name, template_name)
        end
        if(vagabondfile.server? && !vagabondfile.get(:server, :zero))
          config.set(:server, :erchefs, [DEFAULT_CHEF_SERVER_VERSION])
        end
        config[:host_cookbook_store] = cookbook_path
        config.set(:container_key, :users, [ENV['USER']].compact)
        dna_path = File.join(
          vagabondfile[:global_cache],
          "#{vagabondfile.fid}-dna.json"
        )
        File.write(dna_path,
          MultiJson.dump(
            :run_list => [
              'recipe[vagabond]'
            ],
            :vagabond => config
          )
        )
        dna_path
      end

      # @return [String] global cookbook collection
      def cookbook_path
        File.join(vagabondfile[:global_cache], 'cookbooks')
      end

      # Write empty vagabond file to CWD
      #
      # @return [TrueClass]
      def write_vagabondfile
        File.open('Vagabondfile', 'w+') do |file|
          file.write <<-EOF
# -*- mode: ruby -*-
# -*- encoding: utf-8 -*-
Configuration.new do
  defaults do
  end
  definitions do
  end
  nodes do
    test_node do
      template 'ubuntu_1204'
    end
  end
  server do
    enabled true
  end
  clusters do
  end
  spec do
  end
  callbacks do
  end
end
EOF
        end
        true
      end

    end
  end
end
