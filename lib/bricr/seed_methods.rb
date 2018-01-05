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

  def self.get_property_id(seed, custom_id)
    property_id = nil
    
    # DLM: search doesn't seem to be working with custom_id
    #search_results = seed.search(custom_id, nil)
    search_results = seed.search(nil, nil)
    
    # DLM: search_results.properties doesn't exist, now it is results?

    # DLM: manually search for now
    property_id = nil
    search_results.results.each do |result|
      if result[:custom_id_1] == custom_id
        property_id = result[:id]
        break
      end
    end
    
    return property_id
  end
  

end