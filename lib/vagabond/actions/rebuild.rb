#encoding: utf-8
module Vagabond
  module Actions
    module Rebuild
      def _rebuild
        name_required!
        ui.info "#{ui.color('Vagabond:', :bold)} Rebuilding #{ui.color(name, :blue)}"
        _destroy
        @lxc = Lxc.new(name)
        _destroy
        options[:force_solo] = true
        ui.info ui.color('  -> DESTROYED!', :red)
        internal_config.run_solo
        internal_config[mappings_key].delete(name)
        internal_config.save
        ui.info ui.color('  -> REBUILT!', :green)
      end
    end
  end
end
