require_relative './../spec_helper'

require 'fileutils'
require 'parallel'

describe 'BRICR' do
  it 'should have a version' do
    expect(BRICR::VERSION).not_to be_nil
  end

  it 'should parse a phase zero xml' do
    xml_path = File.join(File.dirname(__FILE__), '../files/phase0/building_151.xml')
    expect(File.exist?(xml_path)).to be true

    out_path = File.join(File.dirname(__FILE__), '../output/phase0_building_151/')
    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    translator = BRICR::Translator.new(xml_path)
    translator.writeOSWs(out_path)

    osw_files = []
    Dir.glob("#{out_path}/**/*.osw") { |osw| osw_files << osw }

    expect(osw_files.size).to eq 30

    if BRICR::DO_SIMULATIONS
      num_sims = 0
      Parallel.each(osw_files, in_threads: [BRICR::NUM_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |osw|
        break if num_sims > BRICR::MAX_DATAPOINTS

        cmd = "\"#{BRICR::OPENSTUDIO_EXE}\" -I E:/openstudio-standards/lib run -w \"#{osw}\""
        puts "Running cmd: #{cmd}"
        result = system(cmd)
        expect(result).to be true
        
        num_sims += 1
      end

      translator.gatherResults(out_path)
      expect(translator.failed_scenarios.empty?).to be(true), "Scenarios #{translator.failed_scenarios.join(', ')} failed to run"
      translator.saveXML(File.join(out_path, 'results.xml'))
    end
  end
end
