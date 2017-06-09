# usage: bundle exec ruby geojson_checks.rb /path/to/geojson.json

require 'json'
require 'rexml/document'

geojson = nil
File.open(ARGV[0], 'r') do |file|
  geojson = JSON::parse(file.read, :symbolize_names => true)
end

outdir = "./bs_output"
FileUtils.mkdir_p(outdir) if !File.exists?(outdir)

m_to_ft = 3.28084

geojson[:features].each do |feature|
  id = feature[:properties][:"Building Identifier"]

  gross_floor_area = feature[:properties][:"Gross Floor Area"]
  total_commercial_floor_area = feature[:properties][:"Total Commercial Footprint Floor Area"]
  total_office_floor_area = feature[:properties][:"Office (Management; Information; Professional Service) (MIPS) Footprint Floor Area"]
  total_retail_floor_area = feature[:properties][:"Retail; Entertainment (RETAIL) Footprint Floor Area"]
  total_industrial_floor_area = feature[:properties][:"Industrial (Production; Distribution; Repair) (PDR) Footprint Floor Area"]
  total_medical_floor_area = feature[:properties][:"Medical (MED) Footprint Floor Area"]
  total_cultural_floor_area = feature[:properties][:"Cultural; Institutional; Educational (CIE) Footprint Floor Area"]
  total_hotel_floor_area = feature[:properties][:"Hotels; Visitor Services (VISITOR) Footprint Floor Area"]
  basement_floor_area = feature[:properties][:"Basement Floor Area"]
  
  gross_floor_area = 0 if gross_floor_area.nil?
  total_commercial_floor_area = 0 if total_commercial_floor_area.nil?
  total_office_floor_area = 0 if total_office_floor_area.nil?
  total_retail_floor_area = 0 if total_retail_floor_area.nil?
  total_industrial_floor_area = 0 if total_industrial_floor_area.nil?
  total_medical_floor_area = 0 if total_medical_floor_area.nil?
  total_cultural_floor_area = 0 if total_cultural_floor_area.nil?
  total_hotel_floor_area = 0 if total_hotel_floor_area.nil?
  basement_floor_area = 0 if basement_floor_area.nil?
  
  total_area_sum = total_office_floor_area + total_retail_floor_area + total_industrial_floor_area + total_medical_floor_area + total_cultural_floor_area + total_hotel_floor_area
  
  to_street_number = feature[:properties][:"To Street Number"]
  from_street_number = feature[:properties][:"From Street Number"]
  
  to_street_number = 0 if to_street_number.nil?
  from_street_number = 0 if from_street_number.nil?
  
  building_height = feature[:properties][:"Building Height"]
  number_of_floors = feature[:properties][:"Number of Floors"]
  
  building_height = 0 if building_height.nil?
  number_of_floors = 0 if number_of_floors.nil?
  
  above_grade_floors = number_of_floors
  if basement_floor_area > 0
    above_grade_floors = above_grade_floors - 1
  end
  floor_to_floor_height = m_to_ft * building_height / above_grade_floors
  
  puts "#{id}, #{gross_floor_area - total_commercial_floor_area}, #{total_commercial_floor_area - total_area_sum}, #{basement_floor_area}, #{number_of_floors-above_grade_floors}, #{floor_to_floor_height}, #{to_street_number-from_street_number}"
  
end