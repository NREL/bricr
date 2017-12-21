# usage: bundle exec ruby run_seed_buildingsyncs.rb /path/to/config.rb 

require 'seed'
require 'rbconfig'
require 'parallel'
require 'open3'
require 'json'
require 'fileutils'
require 'rest-client'

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

max_results = 2000
search_results = seed.search('', 'Not Started', max_results)

# DLM: properties changed to results
results = search_results.results

if !File.exists?('./run')
  FileUtils.mkdir_p('./run/')
end

ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
run_buildingsync_rb = File.join(File.dirname(__FILE__), "run_buildingsync.rb")
  
num_sims = 0
failure = []
success = []
Parallel.each(results, in_threads: [BRICR::NUM_BUILDINGS_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |result|

  break if num_sims > BRICR::MAX_DATAPOINTS

  # find most recent building sync file for this property
  custom_id = result[:custom_id_1]
  
  # DLM: how can I get these files?
  #files = result[:state][:files].select {|file| file[:file_type] == 'BuildingSync'}.sort {|x,y| x[:modified] <=> y[:modified]}
  
  if files.empty?
    puts "No BuildingSync file available"
    next
  end
  
  # last file is most recent
  file = files[-1][:file]
  url = File.join(host, file)
  
  # DLM: post back analysis state queued
  # update_analysis_state(property_id, analysis_state)
  
  # if url is specified, send this URL to the BRICR job queue
  if defined?(BRICR::BRICR_SIM_URL) && BRICR::BRICR_SIM_URL
  
    RestClient.post( BRICR::BRICR_SIM_URL, JSON::fast_generate({:building_sync_url => url, :custom_id => custom_id}), {:buildingsyncurl => url, :customid => custom_id, :content_type => 'json', :accept => 'json'})
  
  else
    # download and run locally
    xml_file = File.join('./run', "#{custom_id}.xml")
    
    data = RestClient::Request.execute(:method => :get, :url => url, :timeout => 3600)
    File.open(xml_file, "wb") do |f|
      f.write(data)
    end
      
    # DLM: post back analysis state queued
    # update_analysis_state(property_id, analysis_state)
      
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
      
      # DLM: post back analysis state queued
      # update_analysis_state(property_id, analysis_state)
      # update_property_by_buildingfile(property_id, filename, analysis_state = nil)
      
      success << xml_file
    else
      puts "'#{xml_file}' failed"
      puts stdout_str
      puts stderr_str  
      
      # DLM: post back analysis state queued
      # update_analysis_state(property_id, analysis_state)
      
      failure << xml_file
    end
  end
  
  num_sims += 1
  
end

puts "ran #{num_sims} files"