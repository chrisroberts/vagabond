#encoding: utf-8
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'vagabond/version'

Gem::Specification.new do |s|
  s.name = 'vagabond'
  s.version = Vagabond::VERSION.version
  s.summary = 'Node building and testing tooling'
  s.author = 'Chris Roberts'
  s.email = 'code@chrisroberts.org'
  s.homepage = 'http://github.com/chrisroberts/vagabond'
  s.description = 'LXC driven node generation and testing tooling'
  s.require_path = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.files = Dir['**/*']
  s.executables = ['vagabond']
  s.add_dependency 'chef'
  s.add_dependency 'librarian-chef'
  s.add_dependency 'test-kitchen', '>= 1.0.0.alpha'
  s.add_dependency 'thor'
  s.add_dependency 'uuidtools'
  s.add_dependency 'elecksee', '>= 1.0.10'
  s.add_dependency 'serverspec', '>= 0.6.3'
  s.add_dependency 'attribute_struct'
  s.add_dependency 'knife-bootstrapsync'
end
