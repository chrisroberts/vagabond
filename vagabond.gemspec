$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'vagabond/version'

Gem::Specification.new do |s|
  s.name = 'vagabond'
  s.version = Vagabond::VERSION.version
  s.summary = 'Vagabond creator'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://github.com/chrisroberts/vagabond'
  s.description = 'Vagabonds, lazing about'
  s.require_path = 'lib'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.md']  
  s.files = Dir['**/*']
  s.executables = ['vagabond']
  s.add_dependency 'chef'
  s.add_dependency 'librarian'
  s.add_dependency 'test-kitchen', '1.0.0.alpha.0'
end
