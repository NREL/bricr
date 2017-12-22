# usage: bundle exec ruby upload_seed_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/

require 'bricr'
require 'rbconfig'
require 'parallel'

config_path = ARGV[0]
require(config_path)

xml_files = Dir.glob(File.join(ARGV[1], '*.xml'))

ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
upload_seed_buildingsync_rb = File.join(File.dirname(__FILE__), "upload_seed_buildingsync.rb")

#max_points = Float::INFINITY
max_points = 10

uploaded = 0
failures = 0
Parallel.each(xml_files, in_threads: 8) do |xml_file|
#xml_files.each do |xml_file|

  if uploaded < max_points
    uploaded += 1

    command = ['bundle', 'exec', ruby_exe, upload_seed_buildingsync_rb, ARGV[0], xml_file, 'Not Started']

    puts "Running '#{command.join(' ')}'"
    
    result = BRICR.bricr_run_command(command)

    if result
      puts "'#{xml_file}' completed successfully"     
    else
      puts "'#{xml_file}' failed"
      failures += 1
    end
  end
  
end

puts "Attempted to uploaded #{uploaded} files"
puts "#{failures} failures"