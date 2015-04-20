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
  s.files = Dir['{lib,bin}/**/**/*'] + %w(vagabond.gemspec README.md CHANGELOG.md LICENSE)
  s.executables << 'vagabond'
  s.add_runtime_dependency 'bogo', '>= 0.1.8'
  s.add_runtime_dependency 'bogo-config', '>= 0.1.8'
  s.add_runtime_dependency 'bogo-ui', '>= 0.1.6'
  s.add_runtime_dependency 'bogo-cli', '>= 0.1.6'
  s.add_runtime_dependency 'batali'
  s.add_runtime_dependency 'serverspec'
  s.add_runtime_dependency 'elecksee', '>= 1.1.2'
  s.add_development_dependency 'test-kitchen'
end
