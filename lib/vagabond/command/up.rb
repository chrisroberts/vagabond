#encoding: utf-8

require 'vagabond/actions'

module Vagabond
  module Actions
    module Up

      def do_up(name)
        node = load_node(name)
        run_action(:create, name)
        run_action(:provision, name)
      end

      def up(name)
        if(options[:parallel])
          task_holder = Mash.new
          dup_opts = options.dup
          options[:parallel] = false
          ephemeral = self.class.new(options)
          tasks[:up] << task_holder.update(
            :name => name,
            :thread => Thread.new{
              sleep(0.01)
              task_holder[:result] = ephemeral.do_up(name)
            }
          )
        else
          do_up(name)
        end
      end

    end
  end
end

Vagabond::Actions.register(Vagabond::Actions::Up)
