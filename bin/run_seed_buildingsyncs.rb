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

max_results = 10000 # DLM: temporary workaround to search all results
#search_results = seed.search('', 'Not Started', max_results) # DLM: Nick I don't think this is working
search_results = seed.search('', '', max_results)

properties = search_results.properties

properties = properties.select{|property| property[:analysis_state] == 0} # DLM: temp work around 

if properties.size > BRICR::MAX_DATAPOINTS
  properties = properties.slice(0, BRICR::MAX_DATAPOINTS)
end

if !File.exists?('./run')
  FileUtils.mkdir_p('./run/')
end

ruby_exe = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'])
run_buildingsync_rb = File.join(File.dirname(__FILE__), "run_buildingsync.rb")

num_sims = 0
failure = []
success = []
Parallel.each(properties, in_threads: [BRICR::NUM_BUILDINGS_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |property|
#properties.each do |property|

  # get ids
  property_id = property[:property_view_id]
  custom_id = property[:custom_id_1]

  # find most recent building sync file for this property
  files = seed.list_buildingsync_files(property_id)

  if files.empty?
    puts "No BuildingSync file available for property_id '#{property_id}', custom_id '#{custom_id}'"
    next
  end

  # last file is most recent
  file = files[-1][:file]
  url = File.join(BRICR.get_seed_host, file)

  # post back analysis state Queued 
  seed.update_analysis_state(property_id, 'Queued')

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