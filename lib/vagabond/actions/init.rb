#encoding: utf-8

require 'fileutils'
require 'vagabond/actions'

module Vagabond
  module Actions
    module Init

      def init
        ui.info "#{ui.color('Vagabond:', :bold)}: Installing base Vagabondfile"
        install_vagabond_file
        ui.info '  -> Provisioning machine'
        local_provision
        ui.info "  #{ui.color('-> SUCCESS')}"
      end

      def install_vagabond_file
        if(File.exists?(vagabondfile.path))
          ui.confirm('Overwrite existing Vagabondfile', true)
          ui.info 'Overwriting existing Vagabondfile'
        end
        FileUtils.cp(
          File.join(File.dirname(__FILE__), '..', '..', '..', 'examples', 'Vagabondfile'),
          vagabondfile.path
        )
      end

    end
  end
end
