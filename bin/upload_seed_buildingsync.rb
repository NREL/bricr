# usage: bundle exec ruby upload_seed_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml

require 'seed'

config_path = ARGV[0]
require(config_path)

host = ENV["BRICR_SEED_HOST"] || 'http://localhost:8000'
seed = Seed::API.new(host)

# upload to SEED as record
## Create or get the organization
org = seed.get_or_create_organization('BRICR Test Organization')

## Create or get the cycle
cycle_name = 'BRICR Test Cycle - 2011'

# TODO: look into the time zone of these requests. The times are getting converted and don't look right in the SEED UI
cycle_start = DateTime.parse('2010-01-01 00:00:00Z')
cycle_end = DateTime.parse('2010-12-31 23:00:00Z')
cycle = seed.create_cycle(cycle_name, cycle_start, cycle_end)

xml_path = File.expand_path(ARGV[1])

# check if we already have the file in seed
bs = BRICR::BuildingSync.new(xml_path)
custom_id = bs.customId

if !custom_id
  puts "BuildingSync file at '#{xml_path}' does not have a Custom ID defined"
  exit 1
end

search_results = seed.search(custom_id, nil)
# DLM: this will now append buildingsync to the property if it already exists
#if search_results.properties.size >= 1
#  puts "SEED instance already has Property with Custom Id '#{custom_id}'"
#  exit 1
#end

# do the upload
success, messages = seed.upload_buildingsync(xml_path)
if !success
  puts "Error uploading file '#{xml_path}' with messages #{messages}"
  exit 1
end

property_id = messages[:data][:property_view][:property]

puts "yay! property_id is #{property_id}"

# initialize analysis state 
success, messages = seed.update_analysis_state(property_id, 'Started')
if !success
  puts "Error uploading file '#{xml_path}' with messages #{messages}"
  exit 1
end

puts "yeehaw"

new_xml_path = xml_path = File.expand_path("#{File.dirname(ARGV[1])}/#{File.basename(ARGV[1], '.xml')}_updates.xml")
success, messages = seed.update_property_by_buildingfile(property_id, new_xml_path, 'Fun Time')

if !success
  puts "Error uploading file '#{new_xml_path}' with messages #{messages}"
end

puts "thank you much"