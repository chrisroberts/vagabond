module Vagabond
  class Commander

    attr_reader :registry

    def initialize(registry, vagabond)
      @registry = registry
    end

    def receive(payload)
      target, action, options, args = registry.parse(payload)
      klass = classify(target).new(options)
      klass.run_action(action, *args)
      if(Ui.ui.is_a?(Ui::Daemon))
        Ui.ui.output
      end
    end

  end
end
