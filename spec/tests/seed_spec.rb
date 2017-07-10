require_relative './../spec_helper'

require 'fileutils'
require 'parallel'


describe 'BRICR' do

  it 'should upload and download building sync for one cycle' do
    xml_path = File.expand_path('../files/phase0/building_151.xml', File.dirname(__FILE__))

    # upload to SEED as new record

    # get building sync that we just uploaded, download and compare to uploaded one

    # pretend to run energy simulation, now we have building_151_results.xml

    xml_path = File.join(File.dirname(__FILE__), '../files/phase0/building_151.xml')

    # upload results for record, this is not really a new revision of the building, just adding results 

  end

  it 'should upload and download building sync for multiple cycles' do
    xml_path = File.expand_path('../files/phase0/building_151.xml', File.dirname(__FILE__))

    # upload to SEED as new record

    # now user has edited building sync and added info

    # DLM: we don't have phase 1 files, just reupload phase 0 but pretend user modified it
    xml_path = File.join(File.dirname(__FILE__), '../files/phase0/building_151.xml')

    # upload new cycle

  end

end
