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