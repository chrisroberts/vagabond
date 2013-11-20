#encoding: utf-8
require 'vagabond/helpers/server'
require 'vagabond/vagabond'

module Vagabond
  class Spec < Vagabond

    include Vagabond::Helpers::Server

    def install_actions
    end

    def spec_cluster(name)
      server_init!
      if(options[:in_real_life])
        result = vagabondfile[:clusters][name].map do |node_name|
          spec_node(node_name)
        end
      else
        vagabond = Vagabond.new(options)
        vagabond.run_action(:cluster, name)

        result = run_specs(name)

        vagabond = Vagabond.new(options)
        vagabond.run_action(:destroy, name, :cluster => true)
      end
      puts result
    end

    def spec_node(name)
      server_init!
      destructive_action do
        vagabond = Vagabond.new(options)
        vagabond.run_action(:up, name)
      end
      result = apply_specs(name)
      destructive_action do
        vagabond = Vagabond.new(option)
        vagabond.run_action(:destroy, name)
      end
      puts result
    end

    def test(cookbook)
      ui.error 'Not currently implemented as standalone!'
      raise VagabondErrors::NotImplemented.new('Spec#test')
    end

    def init
      ui.info "Initializing spec configuration..."
      make_spec_directory
      populate_spec_directory
      ui.info "  -> #{ui.color('COMPLETE!', :green)}"
    end

    protected

    def destructive_action
      if(options[:in_real_life])
        debug 'Ignoring request to execute block due to live infrastructure target'
      else
        yield
      end
    end

    def make_spec_directory
      %w(role recipe).each do |leaf|
        FileUtils.mkdir_p(File.join(spec_directory, leaf))
      end
    end

    def spec_directory
      File.join(vagabondfile.directory, 'spec')
    end

    def populate_spec_directory
      write_default_file('spec_helper.rb')
    end

    def write_default_file(file)
      write = true
      if(File.exists?(path = File.join(spec_directory, file)))
        answer = ''
        until(%w(y n).include?(answer))
          answer = ui.ask_question("Overwrite existing #{file} ", :default => 'y').downcase
        end
        write = answer == 'y'
      end
      if(write)
        File.open(path, 'w') do |file|
          file.write self.class.const_get("CONTENT_DEFAULT_#{File.basename(path).upcase.sub(%r{\..*$}, '')}")
        end
        ui.info "New file has been written: #{file}"
      else
        ui.warn "Skipping file: #{file}"
      end
    end

    def run_specs(name)
      nodes = vagabondfile[:clusters][name]
      spec_config = vagabondfile[:spec][:clusters][name]    # TODO: validate both of these
      number_of_provisions = spec_config[:provision][:times] || 1
      number_of_provisions - 1
      # NOTE: We start at 1 since the orginal cluster build counts as
      # one provision
      count = 1
      number_of_provisions.to_i.times do
        if(spec_config[:provision][:spec].include?(:every) || spec_config[:provision][:spec].include?("after_#{count}".to_sym))
          nodes.each do |node_name|
            spec_node(node_name)
          end
        end
        if(commands = spec_config[:after][count])
          process_after(commands, nodes)
        end
        if(commands = spec_config[:after][:every])
          process_after(commands, nodes)
        end
        count += 1
      end
    end

    def process_after(after, nodes)
      if(after[:pause])
        ui.info ui.color("  Pause run... (#{after[:pause]} seconds)")
        sleep(after[:pause].to_f)
      end
      if(after[:run])
        run_coms = []
        if(after[:run].is_a?(String))
          run_coms << [after[:run], nodes]
        else
          if(after[:run][:on])
            after[:run][:on].each do |dest, com|
              run_coms << [com, dest]
            end
          end
          # NOTE: This is just for where `:on` key is missed or people
          # just want to be lazy
          after[:run].each_pair do |dest, com|
            run_coms << [com, dest]
          end
        end
        run_coms.each do |command, node_or_nodes|
          [node_or_nodes].flatten.compact.each do |node_name|
            node = load_node(node_name)
            debug "Running command (#{command}) on node: #{node_name}"
            node.run_command(command, :live_stream => ui.live_stream)
          end
        end
      end
    end

    def get_run_list_specs(node)
      node.config[:run_list].map do |item|
        runlist_item = Chef::RunList::RunListItem.new(item)
        directory = File.join(
          vagabondfile.directory,
          'spec', runlist_item.type, runlist_item.name.sub('::', '/')
        )
        if(runlist_item.recipe? && !runlist_item.name.include?('::'))
          directory = File.join(directory, 'default')
        end
        Dir.glob(File.join(directory, '*.rb')).map(&:to_s)
      end.flatten
    end

    def get_custom_specs(node)
      Array(node.config[:custom_specs]).map do |custom|
        directory = File.join(vagabondfile.directory, 'spec/custom', *custom.split('::'))
        Dir.glob(File.join(directory, '*.rb')).map(&:to_s)
      end.flatten
    end

    def apply_specs(node)
      spec_files = []
      spec_files += get_run_list_specs(node)
      spec_files += get_custom_specs(node)
      nodes_for(node).each do |node|
        if(options[:real_life_connect])
          address = Vagabond::Nests.retreive(node, *options[:real_life_connect].split('.'))
        else
          address = node.address
        end
        spec_files.each do |path|
          ui.info "\n#{ui.color('**', :green, :bold)}  Running spec: #{path.sub("#{vagabondfile.directory}/", '')}"
          cmd = build_command("rspec #{path}",
            :live_stream => ui.live_stream,
            :shellout => {
              :env => {
                'VAGABOND_TEST_HOST' => address
              }
            }
          )
          cmd.run_command
          cmd.error!
        end
      end
    end

    def nodes_for(node)
      if(options[:in_real_life])
        run_list = node.config[:run_list].map do |item|
          runlist_item = Chef::RunList::RunListItem.new(item)
          if(runlist_item.role?)
            "roles:#{runlist_item.name}"
          else
            "recipes:#{runlist_item.name}"
          end
        end
        query = run_list.dup
        if(options[:environment])
          query.push("chef_environment:#{options[:environment]}")
        end
        search(:node, query.join(' AND ')).map do |node|
          node
        end
      else
        node
      end
    end

    CONTENT_DEFAULT_SPEC_HELPER = <<-EOF
require 'serverspec'
require 'pathname'
require 'net/ssh'

include Serverspec::Helper::Ssh

RSpec.configure do |c|
  c.before do
    host = ENV['VAGABOND_TEST_HOST']
    if(c.host != host)
      c.ssh.close if c.ssh
      c.host = host
      options = Net::SSH::Config.for(c.host)
      c.ssh = Net::SSH.start(c.host, 'root', options.update(:keys => ['#{Settings[:ssh_key]}']))
    end
  end
end
EOF

  end
end
