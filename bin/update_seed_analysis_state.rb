# usage: bundle exec ruby update_seed_analysis_state.rb /path/to/config.rb /path/to/buildingsync.xml analysis_state

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

if !property_id
  raise "Could not find existing property_id for custom_id #{custom_id}"
end

# set analysis state 
success, messages = seed.update_analysis_state(property_id, analysis_state)
if !success
  raise "Error updating analysis state to '#{analysis_state}' for property id '#{property_id}' with messages '#{messages}'"
end
