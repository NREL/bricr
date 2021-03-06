########################################################################################################################
#  BRICR, Copyright (c) 2017, Alliance for Sustainable Energy, LLC and The Regents of the University of California, through Lawrence 
#  Berkeley National Laboratory (subject to receipt of any required approvals from the U.S. Dept. of Energy). All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions 
#  are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in 
#  the documentation and/or other materials provided with the distribution.
#
#  (3) The name of the copyright holder(s), any contributors, the United States Government, the United States Department of Energy, or 
#  any of their employees may not be used to endorse or promote products derived from this software without specific prior written 
#  permission from the respective party.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
#  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
#  THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR 
#  EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
#  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
#  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
########################################################################################################################

require 'bricr'
require 'rbconfig'
require 'parallel'
require 'json'
require 'fileutils'
require 'rest-client'

if !File.exists?(ARGV[0])
  puts 'usage: bundle exec ruby run_seed_buildingsyncs.rb /path/to/config.rb'
  exit(1)
end

config_path = ARGV[0]
require(config_path)

# get seed host, org, and cycle
seed = BRICR.get_seed()
org = BRICR.get_seed_org(seed)
cycle = BRICR.get_seed_cycle(seed)

profile = BRICR.get_seed_search_profile(seed)
if profile.nil?
  raise "Please create a SEED column list settings profile named 'BRICR-Search' with 'Custom 1' selected"
end

search_results = seed.filter(profile.id, 10000)
if search_results.properties.nil? || search_results.properties.empty?
  return 
end

analysis_state_key = nil
custom_id_key = nil
search_results.properties[0].each_key do |key|
  if /analysis_state/.match(key) && !/analysis_state_message/.match(key)
    analysis_state_key = key
  elsif /custom_id_1_/.match(key)
    custom_id_key = key
  end
end

if analysis_state_key.nil?
  raise "analysis_state_key is nil"
elsif custom_id_key.nil?
  raise "custom_id_key is nil"
end

properties = []
search_results.properties.each do |property|
  #puts property
  if property[analysis_state_key] == 'Not Started'
    properties << property
  end
end

properties = properties.select{|property| property[analysis_state_key] == 'Not Started'} # DLM: temp work around 

#desired_ids = ['35', '2292', '1416', '5953']
#properties = properties.select{|property| desired_ids.include?(property[custom_id_key])} # DLM: extra filter to prioritize 

if properties.size > BRICR::MAX_DATAPOINTS
  slice_offset = 0 # set to non-zero if you want to avoid stepping on another process
  properties = properties.slice(slice_offset, BRICR::MAX_DATAPOINTS)
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
  property_id = property[:id]
  custom_id = property[custom_id_key]

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