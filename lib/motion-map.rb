unless defined?(Motion::Project::Config)
  raise "motion-map must be required within a RubyMotion project Rakefile."
end

Motion::Project::App.setup do |app|
  Dir.glob(File.join(File.dirname(__FILE__), 'motion-map/*.rb')).each do |file|
    app.files.unshift(file)
  end
end