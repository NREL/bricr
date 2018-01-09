# usage: bundle exec ruby upload_seed_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml analysis_state

require 'bricr'

config_path = ARGV[0]
require(config_path)

xml_path = File.expand_path(ARGV[1])

analysis_state = ARGV[2]
analysis_states = ['Not Started', 'Started', 'Completed', 'Failed']
if !analysis_states.index(analysis_state)
  raise "analysis_state '#{analysis_state}' is not valid"
end

# get seed host, org, and cycle
seed = BRICR.get_seed()
org = BRICR.get_seed_org(seed)
cycle = BRICR.get_seed_cycle(seed)

# check if we already have the file in seed
bs = BRICR::BuildingSync.new(xml_path)
custom_id = bs.customId

if !custom_id
  raise "BuildingSync file at '#{xml_path}' does not have a Custom ID defined"
end

property_id = BRICR.get_property_id(seed, custom_id)

if property_id

  # property already exists in seed, do an update
  success, messages = seed.update_property_by_buildingfile(property_id, xml_path)
  if !success
    raise "Error updating file '#{xml_path}' with messages '#{messages}'"
  end

else

  # property does not exist in seed, do the upload
  success, messages = seed.upload_buildingsync(xml_path)
  if !success
    raise "Error uploading file '#{xml_path}' with messages '#{messages}'"
  end
  
  # DLM: Nick is this right
  property_id =  messages[:data][:property_view][:id]
  
  if !property_id
    raise "Did not receive property_id for custom_id #{custom_id}"
  end

end

# initialize analysis state 
# DLM: Nick this seems to fail if property 
success, messages = seed.update_analysis_state(property_id, analysis_state)
if !success
  raise "Error updating analysis state to '#{analysis_state}' for property id '#{property_id}' with messages '#{messages}'"
end