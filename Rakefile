require 'bundler'
Bundler.setup

require 'rspec/core/rake_task'

# Always create spec reports
require 'ci/reporter/rake/rspec'

# Gem tasks
require 'bundler/gem_tasks'

RSpec::Core::RakeTask.new('spec:unit') do |spec|
  spec.rspec_opts = %w[--format progress --format CI::Reporter::RSpec]
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task 'spec:unit' => 'ci:setup:rspec'
task 'spec:unit' => 'init_config'
task default: 'spec:unit'

require 'rubocop/rake_task'
desc 'Run RuboCop on the lib directory'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ['--no-color', '--out=rubocop-results.xml']
  task.formatters = ['RuboCop::Formatter::CheckstyleFormatter']
  task.requires = ['rubocop/formatter/checkstyle_formatter']
  # don't abort rake on failure
  task.fail_on_error = false
end

desc 'Update copyright on files'
task :update_copyright do
  require 'fileutils'
  
  basepath = File.dirname(__FILE__)
  
  ruby_copyright = "########################################################################################################################\n"
  File.open(basepath + "/LICENSE.md") do |f|
    while (line = f.gets)
      if line.strip.empty?
        ruby_copyright += "#" + line
      else
        ruby_copyright += "#  " + line
      end
    end
  end
  ruby_copyright += "########################################################################################################################\n\n"
  
  # files that are part of BRICR
  paths = [basepath + "/bin/**/*.rb",
           basepath + "/lib/**/*.rb",
           basepath + "/*.rb"]
           
  paths.each do |path|
    # glob for rb
    files = Dir.glob(path)
    files.each do |file|
      next if File.basename(file) == 'config.rb'
      
      # start with copyright
      text = ruby_copyright

      # read file
      File.open(file, "r") do |f|
        # read until end of current copyright
        while (line = f.gets)
          if not /^#/.match(line)
            if not line.chomp.empty?
              text += line
            end
            break
          end
        end

        # now keep rest of file
        while (line = f.gets)
          text += line
        end
      end

      # write file
      File.open(file, "w") do |f|
        f << text
      end
  
    end
  end

  puts ruby_copyright
end


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