require_relative './../spec_helper'

require 'fileutils'
require 'parallel'
require 'seed'

describe 'BRICR' do
  it 'should upload and download building sync for multiple cycles' do
    xml_path = File.expand_path('../files/phase0/building_151.xml', File.dirname(__FILE__))

    # upload to SEED as new record

    # now user has edited building sync and added info

    # DLM: we don't have phase 1 files, just re-upload phase 0 but pretend user modified it
    xml_path = File.join(File.dirname(__FILE__), '../files/phase0/building_151.xml')

    # upload new cycle
  end
end
