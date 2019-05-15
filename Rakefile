require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# Load in the rake tasks from the base extension gem
require "openstudio/extension/rake_task"
require "bricr/extension"
rake_task = OpenStudio::Extension::RakeTask.new
rake_task.set_extension_class(BRICR::Extension)

task :default => :spec

desc 'Init config'
task :init_config do
  require 'fileutils'
  require 'json'
  
  basepath = File.dirname(__FILE__)
  if !File.exists?(File.join(basepath, 'config.rb'))
    
    config_text = ''
    File.open(File.join(basepath, 'config.rb.in'), "r") do |f|
      config_text = f.read
    end
  
    seed_json = {}
    if File.exists?(File.join(basepath, 'seed.json'))
      File.open(File.join(basepath, 'seed.json'), "r") do |f|
        seed_json = JSON::parse(f.read, symbolize_names: true)
      end
      
      config_text.gsub!('YOUR_SEED_HOST', 'http://localhost') # don't use contents of file
      config_text.gsub!('YOUR_SEED_USERNAME', seed_json[:username]) 
      config_text.gsub!('YOUR_SEED_API_KEY', seed_json[:api_key]) 
    end
    
    File.open(File.join(basepath, 'config.rb'), "w") do |f|
      f.puts config_text
    end
    
  end

end