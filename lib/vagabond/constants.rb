#encoding: utf-8
require 'vagabond'

module Vagabond
  COLORS = Smash.new(
    :success => :green,
    :create => :green,
    :setup => :blue,
    :error => :red,
    :failed => :red,
    :verified => :yellow,
    :converged => :magenta,
    :destroy => :red,
    :kitchen => [:cyan, :bold]
  )
end
