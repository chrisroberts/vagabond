#encoding: utf-8
module Vagabond
  class VagabondError < StandardError
    class << self
      attr_accessor :exit_code
    end
    def exit_code
      self.class.exit_code
    end
  end

  class VagabondError
    %w(
        reserved_name invalid_name invalid_base_template
        invalid_action invalid_template kitchen_missing_yml
        kitchen_no_cookbook_args kitchen_too_many_args
        kitchen_invalid_platform missing_node_name cluster_invalid
        kitchen_test_failed host_provision_failed spec_failed
        node_provision_failed librarian_host_install_failed
        echef_base_missing node_not_running node_not_created
        invalid_request command_failed node_not_frozen not_implemented
    ).each_with_index do |klass_name, i|
      klass = klass_name.split('_').map(&:capitalize).join
      self.class_eval("class #{klass} < VagabondError; self.exit_code = #{i + 1}; end")
    end
  end
end
