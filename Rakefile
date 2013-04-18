$:.unshift('/Library/RubyMotion/lib')
require 'motion/project'
require './lib/motion-map'

require 'bundler'
Bundler::GemHelper.install_tasks

Motion::Project::App.setup do |app|
  app.name = 'MapTest'
  
  app.development do
    app.codesign_certificate  = ENV['dev_bs_certificate']
    app.provisioning_profile  = ENV['dev_bs_profile']
  end
end