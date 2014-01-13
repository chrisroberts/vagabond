require 'vagabond'

module Vagabond
  class Commander

    def process(payload)
      payload = Mash.new(payload)
      klass = classify(payload[:command])
      instance = klass.new(payload[:options])
      instance.run_action(payload[:action], payload[:arguments])
      if(Ui.ui.is_a?(Ui::Daemon))
        Ui.ui.output
      end
    end

  end
end
