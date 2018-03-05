require_relative './../spec_helper'

require 'fileutils'
require 'parallel'
require 'seed'
require 'pp'

describe 'BRICR' do
  it 'should upload and download building sync for one cycle' do
    # Get the unique building ID. For now this is taken from the Premises Identifier custom id field.
    UBID = 'e6a5de56-8234-4b4f-ba10-6af0ae612fd1'.freeze

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

    xml_path = File.expand_path('../files/phase0/151.xml', File.dirname(__FILE__))
    status, response = seed.upload_buildingsync(xml_path)

    puts response unless status

    # get building sync that we just uploaded, download and compare to uploaded one
    expect(status).to eq true
    expect(response[:status]).to eq 'success'

    # Note that the upload_buildingsync file now returns the property_view, not the property_state
    expect(response[:data][:property_state][:custom_id_1]).to eq UBID
    seed.update_analysis_state(response[:data][:property_view][:id], 'Queued')

    # pretend to run energy simulation, now we have building_151_results.xml
    puts 'running simulation'
    sleep(1)

    # upload results for record, this is not really a new revision of the building, just adding results
    xml_path = File.join(File.dirname(__FILE__), '../files/phase0/151_results.xml')

    # search for the building again using the GUID/UBID
    results = seed.search(UBID, nil)
    property_id = results.properties.first[:id]

    puts "updating results with BuildingSync results"
    seed.update_property_by_buildingfile(property_id, xml_path)
    seed.update_analysis_state(property_id, 'Completed')
  end
end
