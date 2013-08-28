#encoding: utf-8
require 'vagabond/constants'

module Vagabond
  module Helpers
    module Callbacks

      def callbacks(key)
        if(vagabondfile[:callbacks][key])
          if(options[:callbacks])
            ui.info "  Running #{ui.color(key, :bold)} callbacks..."
            if(options[:cluster])
              cluster_name = name
              names = vagabondfile[:clusters][name] if vagabondfile[:clusters]
            else
              names = [name]
            end
            names.compact.each do |n|
              @name = n
              callbacks = Array(vagabondfile.callbacks_for(name)[key]).compact.flatten
              callbacks.each do |command|
                Array(command.scan(/\$\{(\w+)\}/).first).each do |repl|
                  command = command.gsub("${#{repl}}", self.send(repl.downcase))
                end
                ui.info "    Running: #{command}"
                opts = {:timeout => 30}
                opts.merge(vagabondfile[:callbacks][:options] || {})
                cmd = Mixlib::ShellOut.new(command,
                  opts.merge(:live_stream => options[:debug])
                )
                cmd.run_command
                if(cmd.status.success?)
                  ui.info ui.color('      -> SUCCESS', :green)
                else
                  ui.info ui.color("      -> FAILED - (#{cmd.stderr.strip.gsub("\n", ' ')})", :red)
                end
              end
            end
            @name = cluster_name if cluster_name
            ui.info ui.color('  -> COMPLETE', :green)
          end
        end

      end
    end
  end
end
