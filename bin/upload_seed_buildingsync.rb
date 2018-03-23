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

  # force upload of BSXML's already in SEED
  if true
    
    # property already exists in seed, do an update
    success, messages = seed.update_property_by_buildingfile(property_id, xml_path)
    if !success
      raise "Error updating file '#{xml_path}' with messages '#{messages}'"
    end

    # have to manually update the analysis state now with a separate requets
    success, messages = seed.update_analysis_state(property_id, analysis_state)
    if !success
      raise "Error updating analysis state to '#{analysis_state}' for property id '#{property_id}' with messages '#{messages}'"
    end
    
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