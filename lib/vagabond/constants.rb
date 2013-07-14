#encoding: utf-8
require 'chef/mash'

module Vagabond
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
