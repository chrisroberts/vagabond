require 'chef/mash'

module Vagabond
  BASE_TEMPLATES = File.readlines(
    File.join(File.dirname(__FILE__), 'cookbooks/vagabond/attributes/default.rb')
  ).map do |l|
    l.scan(%r{bases\]\[:([^\]]+)\]}).flatten.first
  end.compact.uniq

  EXIT_CODE = Mash.new(
    :success => 0,
    :reserved_name => 1,
    :invalid_name => 2,
    :invalid_base_template => 3,
    :invalid_action => 4,
    :invalid_template => 5,
    :kitchen_missing_yml => 6,
    :kitchen_no_cookbook_arg => 7,
    :kitchen_too_many_args => 8
  )
end
