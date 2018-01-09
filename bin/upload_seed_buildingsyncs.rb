# usage: bundle exec ruby upload_seed_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/

require 'bricr'
require 'rbconfig'
require 'parallel'

config_path = ARGV[0]
require(config_path)

xml_files = Dir.glob(File.join(ARGV[1], '*.xml'))

ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
upload_seed_buildingsync_rb = File.join(File.dirname(__FILE__), "upload_seed_buildingsync.rb")

if xml_files.size > BRICR::MAX_DATAPOINTS
  xml_files = xml_files.slice(0, BRICR::MAX_DATAPOINTS)
end

uploaded = 0
failures = 0
Parallel.each(xml_files, in_threads: [BRICR::NUM_BUILDINGS_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |xml_file|
#xml_files.each do |xml_file|

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

puts "Attempted to upload #{uploaded} files"
puts "#{failures} failures"