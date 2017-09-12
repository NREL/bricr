# usage: bundle exec ruby run_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml
require 'bricr'
require 'parallel'
require 'csv'

config_path = ARGV[0]
if config_path.nil? || !File.exist?("#{config_path}")
  puts "error: cannot find the configuration file: #{config_path}"
  puts 'usage: bundle exec ruby run_multiple_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml /path/to/summary.csv'
  exit(1)
end
require(config_path)

xml_folder_path = ARGV[1]
if xml_folder_path.nil? || !File.exist?(xml_folder_path)
  puts "error: cannot find the xml folder path: #{xml_folder_path}"
  puts 'usage: bundle exec ruby run_multiple_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml /path/to/summary.csv'
  exit(1)
end

building_list_filename = ARGV[2]
if building_list_filename.nil? || !File.exist?(building_list_filename)
  puts "error: cannot find the building list csv file: #{building_list_filename}"
  puts 'usage: bundle exec ruby run_multiple_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml /path/to/summary.csv'
  exit(1)
end

xml_paths = []
xml_path_ids = []

building_info = {}
csv_header = ""

building_list = CSV.readlines(building_list_filename)
building_list.each_with_index do |building_record, index|
  if index == 0
    csv_header = building_record
    raise "error: the header of the csv file is wrong #{building_record.join(',')}" if building_record.size < 3 or
        building_record[0] != 'building_id' or building_record[1] != 'xml_filename' or building_record[2] != 'should_run_simulation'
    next
  end
  building_info[building_record[0].to_i] = building_record

  if building_record[2].to_i == 1 and File.exist?(File.join(xml_folder_path, building_record[1]))
    xml_paths.push File.join(xml_folder_path, building_record[1])
    xml_path_ids.push building_record[0].to_i
  end
end

csv_header.push 'Simulation Status,do simulations?,do get results?'
num_sims = 0
total_xml_files = xml_paths.size.to_f

Parallel.each_with_index(xml_paths, in_threads: [BRICR::NUM_BUILDINGS_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |xml_path, index|
  break if num_sims > BRICR::MAX_DATAPOINTS
  cmd = "ruby run_buildingsync.rb #{config_path} #{xml_path}"
  puts "Running cmd (#{(index/total_xml_files*100).to_i}%): #{cmd}\n"
  result = system(cmd)
  building_info[xml_path_ids[index]].push result
  building_info[xml_path_ids[index]].push BRICR::DO_SIMULATIONS
  building_info[xml_path_ids[index]].push BRICR::DO_GET_RESULTS

  num_sims += 1
end

File.open('summary_output.csv', 'w') do |file|
  file.puts csv_header.join(',')
  building_info.values.each do |value|
    file.puts value.join(',')
  end
end
