require 'vagabond/vagabond'
require 'mixlib/cli'
require 'digest/md5'

module Vagabond
  
  class Server < Vagabond
        
    def initialize(me, actions)
      @name = me
      @base_template = 'ubuntu_1204' # TODO: Make this dynamic
      @action = actions.shift
      setup_ui
      load_configurations
    end
    
    def create
      if(lxc.exists?)
        ui.warn 'Server container already exists'
        if(lxc.frozen?)
          ui.fatal 'Server container is currently frozen!'
        elsif(lxc.stopped?)
          lxc.start
          ui.info 'Server container has been started'
        else
          ui.info 'Server container is currently running'
        end
      else
        ui.info 'Creating Chef server container...'
        do_create
      end
    end

    def destroy
      if(lxc.exists?)
        ui.info 'Destroying Chef server container...'
        do_destroy
      else
        ui.fatal 'No Chef server exists within this environment'
      end
    end

    def do_create
      cmd = Mixlib::ShellOut.new("#{Config[:sudo]}lxc-clone -n #{generated_name} -o #{@base_template}")
      cmd.run_command
      cmd.error!
      @lxc = Lxc.new(generated_name)
      @internal_config[:mappings][name] = generated_name
      @internal_config.save
      ui.info "Chef Server container created!"
      lxc.start
      ui.info "Bootstrapping erchef..."
      tem_file = File.expand_path(File.join(File.dirname(__FILE__), 'bootstraps/server.erb'))
      com = "#{Config[:sudo]}knife bootstrap #{lxc.container_ip(10, true)} --template-file #{tem_file} -i /opt/hw-lxc-config/id_rsa"
      cmd = Mixlib::ShellOut.new(com, :live_stream => STDOUT, :timeout => 1200)
      cmd.run_command
      cmd.error!
      ui.info 'Chef Server has been created!'
      auto_upload if vagabondfile[:local_chef_server][:auto_upload]
    end

    def auto_upload
      ui.info 'Auto uploading all assets to local Chef server...'
      upload_roles
      upload_databags
      upload_environments
      upload_cookbooks
      ui.info 'All assets uploaded to local Chef server!'
    end

    def upload_roles
      ui.info "Uploading roles to local Chef server..."
      com = "knife role from file #{File.join(base_dir, 'roles/*')} #{Config[:knife_opts]}"
      cmd = Mixlib::ShellOut.new(com)
      cmd.run_command
      cmd.error!
      ui.info "Roles uploaded to local Chef server!"
    end

    def upload_databags
      ui.info "Uploading data bags to local Chef server..."
      Dir.glob(File.join(base_dir, "data_bags/*")).each do |b|
        next if %w(. ..).include?(b)
        coms = [
          "knife data bag create #{File.basename(b)} #{Config[:knife_opts]}",
          "knife data bag from file #{File.basename(b)} #{Config[:knife_opts]} --all"
        ].each do |com|
          cmd = Mixlib::ShellOut.new(com)
          cmd.run_command
          cmd.error!
        end
      end
      ui.info "Data bags uploaded to local Chef server!"
    end

    def upload_environments
      ui.info "Uploading environments to local Chef server..."
      com = "knife environment from file #{File.join(base_dir, 'environments/*')} #{Config[:knife_opts]}"
      cmd = Mixlib::ShellOut.new(com)
      cmd.run_command
      cmd.error!
      ui.info "Environments uploaded to local Chef server!"
    end

    def upload_cookbooks
      ui.info "Uploading cookbooks to local Chef server..."
      if(vagabondfile[:local_chef_server][:berkshelf])
        berks_upload
      else
        raw_upload
      end
    end

    def berks_upload
      write_berks_config
      com = "berks upload -c #{File.join(vagabond_dir, 'berks.json')}"
      cmd = Mixlib::ShellOut.new(com)
      cmd.run_command
      cmd.error!
      ui.info "Berks cookbook upload complete!"
    end

    def raw_upload
      com = "knife cookbook upload#{Config[:knife_opts]} --all"
      cmd = Mixlib::ShellOut.new(com)
      cmd.run_command
      cmd.error!
      ui.info "Cookbook upload complete!"
    end

    def write_berks_config
      path = File.join(vagabond_dir, 'berks.json')
      if(File.exists?(path))
        cur = Mash.new(JSON.load(File.read(path)))
      else
        cur = Mash.new
      end
      url = "https://#{lxc.container_ip(10, true)}"
      if(cur[:chef].nil? || cur[:chef][:chef_server_url] != url)
        cur[:chef] = Mash.new(:chef_server_url => url)
        cur[:ssl] = Mash.new(:verify => false)
        File.open(path, 'w') do |file|
          file.write(JSON.dump(cur))
        end
      end
    end
    
    def generated_name
      unless(@_gn)
        s = Digest::MD5.new
        s << vagabondfile.path
        @_gn = "server-#{s.hexdigest}"
      end
      @_gn
    end

  end
end
