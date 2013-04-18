# -*- encoding: utf-8 -*-
require File.expand_path('../lib/motion-map/version.rb', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'motion-map'
  gem.version       = MotionMap::VERSION
  gem.authors       = ['Fernand Galiana']
  gem.email         = ['fernand.galiana@gmail.com']
  gem.summary       = %{Port of the most excellent Map gem to RubyMotion}
  gem.description   = %{Ported Ara Howard's Map gem to RubyMotion}  
  gem.homepage      = 'https://github.com/derailed/motion-map'
  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^spec/})
  gem.require_paths = ['lib'] 
  
  gem.add_development_dependency 'rspec'
end