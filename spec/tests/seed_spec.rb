require_relative './../spec_helper'

require 'fileutils'
require 'parallel'
require 'seed'

describe 'BRICR' do
  it 'should upload and download building sync for one cycle' do
    # Get the unique building ID. For now this is taken from the Premises Identifier custom id field.
    UBID = 'e6a5de56-8234-4b4f-ba10-6af0ae612fd1'.freeze

    seed = Seed::API.new('http://localhost:8000')

    # upload to SEED as record
    ## Create or get the organization
    org = seed.get_or_create_organization('BRICR Test Organization')

    ## Create or get the cycle
    cycle_name = 'BRICR Test Cycle - 2011'

    # TODO: look into the time zone of these requests. The times are getting converted and don't look right in the SEED UI
    cycle_start = DateTime.parse('2010-01-01 00:00:00Z')
    cycle_end = DateTime.parse('2010-12-31 23:00:00Z')
    cycle = seed.create_cycle(cycle_name, cycle_start, cycle_end)

    xml_path = File.expand_path('../files/phase0/building_151.xml', File.dirname(__FILE__))
    file = seed.upload_buildingsync(xml_path)

    # get building sync that we just uploaded, download and compare to uploaded one
    expect(file[:status]).to eq 'success'
    expect(file[:data][:property_state][:custom_id_1]).to eq UBID

    # pretend to run energy simulation, now we have building_151_results.xml
    puts 'running simulation'
    sleep(1)

    # upload results for record, this is not really a new revision of the building, just adding results
    xml_path = File.join(File.dirname(__FILE__), '../files/phase0/building_151_results.xml')

    # search for the building again using the GUID/UBID
    results = seed.search(UBID)
    puts results.properties

    # get the first building
    property_id = results.properties.first[:id]
    puts property_id




    # post the results to the existing property
    # seed.update_property()

  end
end
