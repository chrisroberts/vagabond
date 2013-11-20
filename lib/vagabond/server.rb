#encoding: utf-8
require 'vagabond/vagabond'
require 'digest/md5'

module Vagabond

  class Server < Vagabond

    def run_action(action, name=nil, name_args=[], options={})
      args = [name, name_args].flatten(1).compact
      super(action, 'server', args, options)
    end

    def auto_upload(*args)
      ui.info 'Auto uploading all assets to local Chef server...'
      upload_roles
      upload_databags
      upload_environments
      upload_cookbooks
      ui.info ui.color('  -> All assets uploaded!', :green)
    end

    def upload_roles(*args)
      am_uploading('roles') do
        if(File.directory?(File.join(vagabondfile.directory, 'roles')))
          %w(rb json js).each do |ext|
            next if Dir.glob(File.join(vagabondfile.directory, "roles", "*.#{ext}")).size == 0
            cmd = knife_command("role from file #{File.join(vagabondfile.directory, "roles/*.#{ext}")}")
            cmd.run_command
            cmd.error!
          end
        end
      end
    end

    def upload_databags(*args)
      am_uploading('data bags') do
        if(File.directory?(File.join(vagabondfile.directory, 'data_bags')))
          Dir.glob(File.join(vagabondfile.directory, "data_bags/*")).each do |b|
            next if %w(. ..).include?(b) || !File.directory?(b)
            coms = [
              "data bag create #{File.basename(b)}",
              "data bag from file #{File.basename(b)} --all"
            ].each do |com|
              cmd = knife_command(com)
              cmd.run_command
              cmd.error!
            end
          end
        end
      end
    end

    def upload_environments(*args)
      am_uploading('environments') do
        if(File.directory?(File.join(vagabondfile.directory, 'environments')))
          %w(rb json js).each do |ext|
            next if Dir.glob(File.join(vagabondfile.directory, "environments", "*.#{ext}")).size == 0
            cmd = knife_command("environment from file #{File.join(vagabondfile.directory, "environments/*.#{ext}")}")
            cmd.run_command
            cmd.error!
          end
        end
      end
    end

    def upload_cookbooks(*args)
      am_uploading('cookbooks') do
        if(vagabondfile[:server][:librarian])
          librarian_upload
        elsif(vagabondfile[:server][:berkshelf])
          berks_upload
        else
          if(File.exists?(File.join(vagabondfile.directory, 'Cheffile')))
            librarian_upload
          elsif(File.exists?(File.join(vagabondfile.directory, 'Berksfile')))
            berks_upload
          else
            raw_upload
          end
        end
      end
    end

    private

    def server_validate!(*args)
      true
    end

    def am_uploading(thing)
      ui.info "#{ui.color('Local chef server:', :bold)} Uploading #{ui.color(thing, :green)}"
      yield
      ui.info ui.color("  -> UPLOADED #{thing.upcase}", :green)
    end

    def server_base
      if(vagabondfile[:local_chef_server][:zero] || options[:force_zero])
        base = 'vb-zero-server'
      else
        version = vagabondfile[:local_chef_server][:version]
        unless(version)
          # TODO: Bad magic. Make configurable!
          matches = Dir.new('/var/lib/lxc').find_all{|i| i.match(/^vb-server-\d+_\d+_\d+$/)}
          matches.map!{|i| i.sub('vb-server-', '').gsub('_', '.')}
          version = matches.sort{|x,y| Gem::Version.new(x) <=> Gem::Version.new(y)}.last
        end
        base = "vb-server-#{version.gsub('.', '_')}"
        unless(Lxc.new(base).exists?)
          raise VagabondError::ErchefBaseMissing.new("Required base container is missing: #{base}")
        end
      end
      base
    end

    def do_provision(node, opts={})
      server_opts = opts.dup
      server_opts[:extras] = [
        "--sync-directory \"#{internal_config.cookbook_path}:/var/chef-host/cookbooks\""
      ]
      # ensure we have a clean directory to sync to
      node.direct_command('rm -rf /var/chef-host/cookbooks')
      if(vagabondfile[:server][:zero])
        ui.info ui.color('  -> Bootstrapping chef-zero...', :cyan)
        super(node,
          server_opts.merge(
            :custom_template => File.expand_path(File.join(File.dirname(__FILE__), 'bootstraps/server-zero.erb'))
          )
        )
        knife_config :server_url => "http://#{node.address}"
      else
        ui.info ui.color('  -> Bootstrapping erchef...', :cyan)
        super(node,
          server_opts.merge(
            :custom_template => File.expand_path(File.join(File.dirname(__FILE__), 'bootstraps/server.erb'))
          )
        )
        knife_config :server_url => "https://#{node.address}"
      end
      if(vagabondfile[:server][:auto_upload])
        run_action(:auto_upload)
      end
    end

    def berks_upload
      ui.info 'Cookbooks being uploaded via berks'
      if(vagabondfile[:server][:berkshelf].is_a?(Hash))
        berks_opts = vagabondfile[:server][:berkshelf][:options]
        berks_path = vagabondfile[:server][:berkshelf][:path]
      end
      berk_uploader = Uploader::Berkshelf.new(
        vagabondfile, vagabondfile.build_private_store, options.merge(
          :ui => ui,
          :berksfile => File.join(vagabondfile.directory, berks_path || 'Berksfile'),
          :chef_server_url => options[:knife_opts].to_s.split(' ').last,
          :berks_opts => berks_opts
        )
      )
      berk_uploader.upload
    end

    def librarian_upload
      ui.info 'Cookbooks being uploaded with librarian'
      librarian_uploader = Uploader::Librarian.new(
        vagabondfile, vagabondfile.build_private_store, options.merge(
          :ui => ui,
          :cheffile => File.join(vagabondfile.directory, 'Cheffile')
        )
      )
      librarian_uploader.upload
    end

    def raw_upload
      ui.info 'Cookbooks being uploaded via knife'
      knife_uploader = Uploader::Knife.new(vagabondfile, vagabondfile.directory, options.merge(:ui => ui))
      knife_uploader.upload
    end

  end
end
