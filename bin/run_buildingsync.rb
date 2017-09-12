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

out_dir = File.join(File.dirname(xml_path), File.basename(xml_path, '.*') + '/')
if BRICR::DO_SIMULATIONS
  if File.exist?(out_dir)
    FileUtils.rm_rf(out_dir)
  end
end
FileUtils.mkdir_p(out_dir)

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
    system(cmd)

    num_sims += 1
  end
end

if BRICR::DO_GET_RESULTS
  # Read the results from the out.osw file
  translator.gatherResults(out_dir)

  # Save the results back to the BuildingSync file
  translator.saveXML(File.join(out_dir, 'results.xml'))
end
