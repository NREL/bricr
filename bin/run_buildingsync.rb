# usage: bundle exec ruby run_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml

require 'bricr'
require 'parallel'

config_path = ARGV[0]
require(config_path)

xml_path = ARGV[1]
if xml_path.nil? || !File.exist?(xml_path)
  puts 'usage: bundle exec ruby run_buildingsync.rb /path/to/buildingsync.xml'
  exit(1)
end

if defined?(BRICR::SIMULATION_OUTPUT_FOLDER) && BRICR::SIMULATION_OUTPUT_FOLDER
  unless BRICR::SIMULATION_OUTPUT_FOLDER
    FileUtils.mkdir_p(BRICR::SIMULATION_OUTPUT_FOLDER)
  end
  out_dir = File.join(BRICR::SIMULATION_OUTPUT_FOLDER, File.basename(xml_path, '.*') + '/')
else
  out_dir = File.join(File.dirname(xml_path), File.basename(xml_path, '.*') + '/')
end

if BRICR::DO_SIMULATIONS
  if File.exist?(out_dir)
    FileUtils.rm_rf(out_dir)
  end
end
FileUtils.mkdir_p(out_dir)

bs = BRICR::BuildingSync.new(xml_path)
custom_id = bs.customId

if !custom_id
  raise "BuildingSync file at '#{xml_path}' does not have a Custom ID defined"
end

translator = BRICR::Translator.new(xml_path)
translator.writeOSWs(out_dir)
osw_files = []
Dir.glob("#{out_dir}/**/*.osw") { |osw| osw_files << osw }

if BRICR::DO_SIMULATIONS
  num_sims = 0
  Parallel.each(osw_files, in_threads: [BRICR::NUM_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |osw|
    break if num_sims > BRICR::MAX_DATAPOINTS

    cmd = "\"#{BRICR::OPENSTUDIO_EXE}\" run -w \"#{osw}\""
    puts "Running cmd: #{cmd}\n"
    result = system(cmd)

    unless result
      raise "Failed to run the simulation with cmd: #{cmd}"
    end

    num_sims += 1
  end
end

if BRICR::DO_GET_RESULTS
  # Read the results from the out.osw file
  translator.gatherResults(out_dir)
  
  out_file = File.join(out_dir, 'results.xml')

  # Save the results back to the BuildingSync file
  translator.saveXML(out_file)
end
