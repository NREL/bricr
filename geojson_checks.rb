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

require 'json'
require 'rexml/document'

geojson = nil
File.open(ARGV[0], 'r') do |file|
  geojson = JSON.parse(file.read, symbolize_names: true)
end

outdir = './bs_output'
FileUtils.mkdir_p(outdir) unless File.exist?(outdir)

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
    above_grade_floors -= 1
  end
  floor_to_floor_height = m_to_ft * building_height / above_grade_floors

  puts "#{id}, #{gross_floor_area - total_commercial_floor_area}, #{total_commercial_floor_area - total_area_sum}, #{basement_floor_area}, #{number_of_floors - above_grade_floors}, #{floor_to_floor_height}, #{to_street_number - from_street_number}"
end
