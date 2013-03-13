module Vagabond
  module Actions
    module Rebuild
      def rebuild
        ui.info "#{ui.color('Vagabond:', :bold)} Rebuilding #{ui.color(name, :blue)}"
        destroy
        @lxc = Lxc.new(name)
        destroy
        Config[:force_solo] = true
        ui.info ui.color('  -> DESTROYED!', :red)
        internal_config.run_solo
        internal_config[:mappings].delete(name)
        internal_config.save
        ui.info ui.color('  -> REBUILT!', :green)
      end
    end
  end
end
