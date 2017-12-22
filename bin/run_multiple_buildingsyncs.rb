# usage: bundle exec ruby run_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/ /path/to/summary.csv
require 'bricr'
require 'parallel'
require 'csv'

config_path = ARGV[0]
if config_path.nil? || !File.exist?("#{config_path}")
  puts "error: cannot find the configuration file: #{config_path}"
  puts 'usage: bundle exec ruby run_multiple_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/ /path/to/summary.csv'
  exit(1)
end
require(config_path)

xml_folder_path = ARGV[1]
if xml_folder_path.nil? || !File.exist?(xml_folder_path)
  puts "error: cannot find the xml folder path: #{xml_folder_path}"
  puts 'usage: bundle exec ruby run_multiple_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/ /path/to/summary.csv'
  exit(1)
end

building_list_filename = ARGV[2]
if building_list_filename.nil? || !File.exist?(building_list_filename)
  puts "error: cannot find the building list csv file: #{building_list_filename}"
  puts 'usage: bundle exec ruby run_multiple_buildingsync.rb /path/to/config.rb /path/to/buildingsync_dir/ /path/to/summary.csv'
  exit(1)
end

xml_paths = []
xml_path_ids = []

building_info = {}
csv_header = ""

# This function is used to get the annual electricity and natural gas results from the result.xml file
def get_results(result_xml_path)
  results = {}
  # parse the xml
  raise "File '#{result_xml_path}' does not exist" unless File.exist?(result_xml_path)
  File.open(result_xml_path, 'r') do |file|
    doc = REXML::Document.new(file)
    doc.elements.each('auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario') do |scenario|
      # get information about the scenario
      scenario_name = scenario.elements['auc:ScenarioName'].text
      next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

      package_of_measures = scenario.elements['auc:ScenarioType'].elements['auc:PackageOfMeasures']
      results['annual_electricity'] = package_of_measures.elements['auc:AnnualElectricity'].text.to_f
      results['annual_natural_gas'] = package_of_measures.elements['auc:AnnualNaturalGas'].text.to_f
    end
  end
  return results
end

# This function is used to obtain the simulation settings
def get_calibration_parameters(out_osw_path)
  cal_results = {}
  raise "File '#{out_osw_path}' does not exist" unless File.exist?(out_osw_path)

  find_cal_measure = false
  out_json = JSON.parse(File.read(out_osw_path))
  raise 'Fail to find steps in the out.osw' if out_json['steps'].nil?
  out_json['steps'].each do |step|
    next unless step['measure_dir_name'] == 'calibrate_baseline_model'
    find_cal_measure = true
    step['result']['step_values'].each do |step_value|
      cal_results[step_value['name']] = step_value['value']
    end
  end

  raise 'Fail to find the calibrate_baseline_model measure output.' unless find_cal_measure
  return cal_results
end

floor_area_index = nil

building_list = CSV.readlines(building_list_filename)
building_list.each_with_index do |building_record, index|
  if index == 0
    csv_header = building_record
    raise "error: the header of the csv file is wrong #{building_record.join(',')}" if building_record.size < 3 or
        building_record[0] != 'building_id' or building_record[1] != 'xml_filename' or building_record[2] != 'should_run_simulation'
    building_record.each_with_index do |header_item, header_index|
      if header_item == 'FloorArea(ft2)'
        floor_area_index = header_index
      end
    end
    raise "Can't find the column with FloorArea(ft2)" if floor_area_index.nil?
    next
  end
  building_info[building_record[0].to_i] = building_record

  if building_record[2].to_i == 1 and File.exist?(File.join(xml_folder_path, building_record[1]))
    xml_paths.push File.join(xml_folder_path, building_record[1])
    xml_path_ids.push building_record[0].to_i
  end
end

ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
run_buildingsync_rb = File.join(File.dirname(__FILE__), "run_buildingsync.rb")

csv_header.push 'Simulation Status,do simulations?,do get results?'
csv_header.push 'electricity_eui(kBtu/sf),natural gas_eui(kBtu/sf)'
csv_header.push 'site_eui(kBtu/sf),source_eui(kBtu/sf)'
calibration_parameter_names = ['lpd_change_rate', 'epd_change_rate', 'occupancy_change_rate','cop_change_rate', 'heating_efficiency_change_rate',
                               'initial_lpd','initial_epd','initial_occupancy','initial_cop','initial_eff',
                               'after_lpd','after_epd','after_occupancy','after_cop','after_eff']

if defined?(BRICR::DO_MODEL_CALIBRATION) and BRICR::DO_MODEL_CALIBRATION
  csv_header.push calibration_parameter_names.join(',')
end

num_sims = 0
total_xml_files = xml_paths.size.to_f
Parallel.each_with_index(xml_paths, in_threads: [BRICR::NUM_BUILDINGS_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |xml_path, index|
  break if num_sims > BRICR::MAX_DATAPOINTS
  
  command = ['bundle', 'exec', ruby_exe, run_buildingsync_rb, ARGV[0], xml_path]

  puts "Running cmd (#{index}/#{total_xml_files.to_i} #{(100*index/total_xml_files).to_i}%): #{command.join(' ')}\n"

  result = bricr_run_command(command)

  building_info[xml_path_ids[index]].push result
  building_info[xml_path_ids[index]].push BRICR::DO_SIMULATIONS
  building_info[xml_path_ids[index]].push BRICR::DO_GET_RESULTS

  if result
    if defined?(BRICR::SIMULATION_OUTPUT_FOLDER) && BRICR::SIMULATION_OUTPUT_FOLDER
      out_dir = File.join(BRICR::SIMULATION_OUTPUT_FOLDER, File.basename(xml_path, '.*') + '/')
    else
      out_dir = File.join(File.dirname(xml_path), File.basename(xml_path, '.*') + '/')
    end
    result_path = File.join(out_dir, 'results.xml')
    results = get_results(result_path)
    floor_area_sf = building_info[xml_path_ids[index]][floor_area_index].to_f
    electricity_eui = results['annual_electricity'] / floor_area_sf
    gas_eui = results['annual_natural_gas'] / floor_area_sf

    building_info[xml_path_ids[index]].push(electricity_eui)
    building_info[xml_path_ids[index]].push(gas_eui)
    building_info[xml_path_ids[index]].push(electricity_eui + gas_eui)
    building_info[xml_path_ids[index]].push(electricity_eui * 3.14 + gas_eui * 1.05)

    if defined?(BRICR::DO_MODEL_CALIBRATION) and BRICR::DO_MODEL_CALIBRATION
      out_osw_path = File.join(out_dir, 'baseline', 'out.osw')
      cal_results  = get_calibration_parameters(out_osw_path)
      calibration_parameter_names.each do |parameter_name|
        building_info[xml_path_ids[index]].push(cal_results[parameter_name])
      end
    end
  end

  num_sims += 1
end

if defined?(BRICR::SIMULATION_OUTPUT_FOLDER) && BRICR::SIMULATION_OUTPUT_FOLDER
  summary_output_path = File.join(BRICR::SIMULATION_OUTPUT_FOLDER, 'summary_output.csv')
else
  summary_output_path = 'summary_output.csv'
end

File.open(summary_output_path, 'w') do |file|
  file.puts csv_header.join(',')
  building_info.values.each do |value|
    file.puts value.join(',')
  end
end
