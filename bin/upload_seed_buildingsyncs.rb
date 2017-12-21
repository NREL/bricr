# usage: bundle exec ruby upload_seed_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/

require 'seed'
require 'rbconfig'
require 'parallel'
require 'open3'

config_path = ARGV[0]
require(config_path)

xml_files = Dir.glob(File.join(ARGV[1], '*.xml'))

ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
upload_seed_buildingsync_rb = File.join(File.dirname(__FILE__), "upload_seed_buildingsync.rb")

#max_points = Float::INFINITY
max_points = 10

uploaded = 0
Parallel.each(xml_files, in_threads: 8) do |xml_file|
#xml_files.each do |xml_file|

  if uploaded < max_points
    uploaded += 1

    command = "bundle exec '#{ruby_exe}' '#{upload_seed_buildingsync_rb}' #{ARGV[0]} '#{xml_file}'"

    puts "Running '#{command}'"

    new_env = {}

    # blank out bundler and gem path modifications, will be re-setup by new call
    new_env["BUNDLER_ORIG_MANPATH"] = nil
    new_env["GEM_PATH"] = nil
    new_env["GEM_HOME"] = nil
    new_env["BUNDLER_ORIG_PATH"] = nil
    new_env["BUNDLER_VERSION"] = nil
    new_env["BUNDLE_BIN_PATH"] = nil
    new_env["BUNDLE_GEMFILE"] = nil
    new_env["RUBYLIB"] = nil
    new_env["RUBYOPT"] = nil

    stdout_str, stderr_str, status = Open3.capture3(new_env, command)

    if status.success?
      puts "'#{xml_file}' completed successfully"
      #puts stdout_str
      #puts stderr_str        
    else
      puts "'#{xml_file}' failed"
      puts stdout_str
      puts stderr_str
    end
  end
  
end

puts "uploaded #{uploaded} files"