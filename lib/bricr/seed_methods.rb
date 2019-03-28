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

require 'seed'

module BRICR

  def self.get_seed_host
    host = ENV["BRICR_SEED_HOST"] || 'http://localhost:8000'
    return host
  end
  
  def self.get_seed
    seed = Seed::API.new(self.get_seed_host)
    return seed
  end
    
  def self.get_seed_org(seed)
    org = seed.get_or_create_organization('BRICR Test Organization')
    return org
  end

  def self.get_seed_cycle(seed)
    cycle_name = 'BRICR Test Cycle - 2011'

    # TODO: look into the time zone of these requests. The times are getting converted and don't look right in the SEED UI
    cycle_start = DateTime.parse('2010-01-01 00:00:00Z')
    cycle_end = DateTime.parse('2010-12-31 23:00:00Z')
    cycle = seed.create_cycle(cycle_name, cycle_start, cycle_end)
    return cycle
  end
  
  def self.get_seed_search_profile(seed)
    profile_name = 'BRICR-Search'

    profile = nil
    profiles = seed.profiles()
    return profile if profiles.nil?
    
    profiles.each do |p|
      profile = p if p.name == profile_name
    end
    return profile
  end

  def self.get_property_id(seed, org, cycle, custom_id)
  
    profile = self.get_seed_search_profile(seed)
    if profile.nil?
      raise "Please create a SEED column list settings profile named 'BRICR-Search' with 'Custom 1' selected"
    end
    
    search_results = seed.filter(profile.id, 10000)
    if search_results.properties.nil? || search_results.properties.empty?
      return 
    end
    
    key_name = nil
    search_results.properties[0].each_key do |key|
      if /custom_id_1/.match(key)
        key_name = key
        break
      end
    end
  
    property_ids = []
    search_results.properties.each do |property|
      if property[key_name] == custom_id
        property_ids << property[:id]
      end
    end
    property_ids.uniq!
    
    property_id = nil
    if property_ids.size == 1
      property_id = property_ids[0]
    elsif property_ids.size > 1
      puts "Multiple property_id's '#{property_ids.join(',')}' associated with custom_id '#{custom_id}', returning first"
      property_id = property_ids[0]
    end
    
    return property_id
  end
  

end