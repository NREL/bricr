# usage: bundle exec ruby upload_seed_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/

require 'seed'
require 'rbconfig'
require 'parallel'
require 'open3'
require 'fileutils'
require 'net/http'

config_path = ARGV[0]
require(config_path)

host = ENV["BRICR_SEED_HOST"] || 'http://localhost:8000' 
seed = Seed::API.new(host)

## Create or get the organization
org = seed.get_or_create_organization('BRICR Test Organization')

## Create or get the cycle
cycle_name = 'BRICR Test Cycle - 2011'

# TODO: look into the time zone of these requests. The times are getting converted and don't look right in the SEED UI
cycle_start = DateTime.parse('2010-01-01 00:00:00Z')
cycle_end = DateTime.parse('2010-12-31 23:00:00Z')
cycle = seed.create_cycle(cycle_name, cycle_start, cycle_end)

search_results = seed.search('', 'Not Started')
properties = search_results.properties

if !File.exists?('./run')
  FileUtils.mkdir_p('./run/')
end

ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
run_buildingsync_rb = File.join(File.dirname(__FILE__), "run_buildingsync.rb")
  
failure = []
success = []
Parallel.each(properties, in_threads: 8) do |property|
#properties.each do |property|

  custom_id = property[:state][:custom_id_1]
  files = property[:state][:files].select {|file| file[:file_type] == 'BuildingSync'}.sort {|x,y| x[:modified] <=> y[:modified]}
  
  if files.empty?
    puts "No BuildingSync file available"
    next
  end
  
  # last file is most recent
  file = files[-1][:file]
  url = File.join(host, file)
  
  # TODO: send this URL to the BRICR job queue
  
  # DLM: for now download and run
  xml_file = File.join('./run', "#{custom_id}.xml")
  Net::HTTP.start(host.gsub('http://','').gsub('https://','')) do |http|
    resp = http.get(file)
    File.open(xml_file, "wb") do |f|
      f.write(resp.body)
    end
  end
  
  command = "bundle exec '#{ruby_exe}' '#{run_buildingsync_rb}' #{ARGV[0]} '#{xml_file}'"
    
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
    
    success << xml_file
  else
    puts "'#{xml_file}' failed"
    puts stdout_str
    puts stderr_str  
    
    failure << xml_file
  end

end