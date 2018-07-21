########################################################################################################################
#  BRICR, Copyright (c) 2017, Alliance for Sustainable Energy, LLC and The Regents of the University of California, through Lawrence 
#  Berkeley National Laboratory (subject to receipt of any required approvals from the U.S. Dept. of Energy). All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions 
#  are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in 
#  the documentation and/or other materials provided with the distribution.
#
#  (3) The name of the copyright holder(s), any contributors, the United States Government, the United States Department of Energy, or 
#  any of their employees may not be used to endorse or promote products derived from this software without specific prior written 
#  permission from the respective party.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
#  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
#  THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR 
#  EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
#  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
#  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
########################################################################################################################

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
    doc.elements.each('n1:Audits/n1:Audit/n1:Report/n1:Scenarios/n1:Scenario') do |scenario|
      # get information about the scenario
      scenario_name = scenario.elements['n1:ScenarioName'].text
      next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

      package_of_measures = scenario.elements['n1:ScenarioType'].elements['n1:PackageOfMeasures']
      results['annual_electricity'] = package_of_measures.elements['n1:AnnualElectricity'].text.to_f
      results['annual_natural_gas'] = package_of_measures.elements['n1:AnnualNaturalGas'].text.to_f
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

  result = BRICR::bricr_run_command(command)

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
