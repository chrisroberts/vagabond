require 'chef/mash'

module Vagabond
  BASE_TEMPLATES = File.readlines(
    File.join(File.dirname(__FILE__), 'cookbooks/vagabond/attributes/default.rb')
  ).map do |l|
    l.scan(%r{bases\]\[:([^\]]+)\]}).flatten.first
  end.compact.uniq

  COLORS = Mash.new(
    :success => :green,
    :create => :green,
    :setup => :blue,
    :error => :red,
    :failed => :red,
    :verified => :yellow,
    :converged => :magenta,
    :destroyed => :red,
    :kitchen => [:cyan, :bold]
  )
end
