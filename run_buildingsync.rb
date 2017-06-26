# usage: bundle exec ruby run_buildingsync.rb /path/to/buildingsync.xml

require_relative 'config'
require_relative 'lib/bricr'
require 'parallel'

xml_path = ARGV[0]
if xml_path.nil? || !File.exists?(xml_path)
  puts 'usage: bundle exec ruby run_buildingsync.rb /path/to/buildingsync.xml'
  exit(1)
end

out_dir = File.join(File.dirname(xml_path), File.basename(xml_path, ".*") + "/")
if BRICR::DO_SIMULATIONS
  if File.exists?(out_dir)
    FileUtils.rm_rf(out_dir)
  end
end
FileUtils.mkdir_p(out_dir)

translator = BRICR::Translator.new(xml_path)
translator.writeOSWs(out_dir)

osw_files = []
Dir.glob("#{out_dir}/**/*.osw") {|osw| osw_files << osw}

if BRICR::DO_SIMULATIONS
  num_sims = 0
  Parallel.each(osw_files, in_threads: [BRICR::NUM_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |osw|
    break if num_sims > BRICR::MAX_DATAPOINTS
    
    cmd = "\"#{BRICR::OPENSTUDIO_EXE}\" run -w \"#{osw}\""
    puts "Running cmd: #{cmd}"
    system(cmd)
    
    num_sims += 1
  end
end

translator.gatherResults(out_dir)

translator.saveXML(File.join(out_dir, 'results.xml'))