# usage: bundle exec ruby run_seed_buildingsyncs.rb /path/to/config.rb 

require 'bricr'
require 'rbconfig'
require 'parallel'
require 'json'
require 'fileutils'
require 'rest-client'

config_path = ARGV[0]
require(config_path)

# get seed host, org, and cycle
seed = BRICR.get_seed()
org = BRICR.get_seed_org(seed)
cycle = BRICR.get_seed_cycle(seed)

max_results = 2000
search_results = seed.search('', 'Not Started', max_results)

# DLM: properties changed to results
results = search_results.results

if !File.exists?('./run')
  FileUtils.mkdir_p('./run/')
end

ruby_exe = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'])
run_buildingsync_rb = File.join(File.dirname(__FILE__), "run_buildingsync.rb")

num_sims = 0
failure = []
success = []
Parallel.each(results, in_threads: [BRICR::NUM_BUILDINGS_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |result|
#results.each do |result|

  break if num_sims > BRICR::MAX_DATAPOINTS

  # get ids
  property_id = result[:id]
  property_view_id = result[:property_view_id]
  custom_id = result[:custom_id_1]

  # find most recent building sync file for this property
  files = seed.list_buildingsync_files(property_id)

  # DLM: how can I get these files?
  #files = result[:state][:files].select {|file| file[:file_type] == 'BuildingSync'}.sort {|x,y| x[:modified] <=> y[:modified]}

  if files.empty?
    puts "No BuildingSync file available"
    next
  end

  # last file is most recent
  file = files[-1][:file]
  url = File.join(BRICR.get_seed_host, file)

  # DLM: post back analysis state Queued // DLM: does this exist?
  #seed.update_analysis_state(property_id, analysis_state)

  # if url is specified, send this URL to the BRICR job queue
  if defined?(BRICR::BRICR_SIM_URL) && BRICR::BRICR_SIM_URL

    RestClient.post(BRICR::BRICR_SIM_URL, JSON::fast_generate({:building_sync_url => url, :custom_id => custom_id}), {:buildingsyncurl => url, :customid => custom_id, :content_type => 'json', :accept => 'json'})

  else
    # download and run locally
    xml_file = File.join('./run', "#{custom_id}.xml")

    data = RestClient::Request.execute(:method => :get, :url => url, :timeout => 3600)
    File.open(xml_file, "wb") do |f|
      f.write(data)
    end

    # post back analysis state Started
    seed.update_analysis_state(property_id, 'Started')

    result_xml = nil
    begin
      result_xml = BRICR.run_buildingsync(xml_file)
      puts "'#{xml_file}' completed successfully, output at '#{result_xml}'"
    rescue
      puts "'#{xml_file}' failed"
      failure << xml_file
    end

    if result_xml
      # post back analysis state Completed
      seed.update_property_by_buildingfile(property_id, result_xml)
      seed.update_analysis_state(property_id, 'Completed')
    else
      # post back analysis state Failed
      seed.update_analysis_state(property_id, 'Failed')
    end

  end

  num_sims += 1

end

puts "Attempted to run #{num_sims} files"
puts "#{failure.size} failures"