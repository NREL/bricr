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
require 'FileUtils'

if ARGV[0].nil? || !File.exist?(ARGV[0])
  puts 'usage: bundle exec ruby geojson_to_buildingsync.rb /path/to/geojson.json'
  exit(1)
end

def convert(value, unit_in, unit_out)
  if unit_in == unit_out
  elsif unit_in == 'm'
    if unit_out == 'ft'
      value = 3.28084 * value
    end
  elsif unit_in == 'm2'
    if unit_out == 'ft2'
      value = 10.7639 * value
    end
  end
  return value
end

def get_facility_classification(feature)
  classification = feature[:properties][:"Occupancy Classification"]

  # https://data.sfgov.org/Housing-and-Buildings/Land-Use/us3s-fp9q/about
  result = nil
  case classification
  when 'CIE'
    result = 'Commercial'
  when 'MED'
    result = 'Commercial'
  when 'MIPS'
    result = 'Commercial'
  when 'MIXED'
    result = 'Mixed use commercial'
  when 'MIXRES'
    result = 'Residential'
  when 'OPENSPACE', 'OpenSpace'
    result = 'Other'
  when 'PDR'
    result = 'Other'
  when "RETAIL\/ENT"
    result = 'Commercial'
  when 'RESIDENT'
    result = 'Residential'
  when 'VISITOR'
    result = 'Commercial'
  when 'MISSING DATA'
    result = 'Other'
  else
    raise "Unknown classification #{classification}"
  end

  return result
end

def get_occupancy_classification(feature)
  classification = feature[:properties][:"Occupancy Classification"]

  # https://data.sfgov.org/Housing-and-Buildings/Land-Use/us3s-fp9q/about
  result = nil
  case classification
  when 'CIE'
    result = 'Assembly-Cultural entertainment'
    raise "#{result} is not a supported Occupancy Classification"
  when 'MED'
    result = 'Health care'
    raise "#{result} is not a supported Occupancy Classification"
  when 'MIPS'
    result = 'Office'
  when 'MIXED'
    result = 'Mixed-use commercial'
    raise "#{result} is not a supported Occupancy Classification"
  when 'MIXRES'
    result = 'Residential'
    raise "#{result} is not a supported Occupancy Classification"
  when 'OPENSPACE', 'OpenSpace'
    result = 'Other'
    raise "#{result} is not a supported Occupancy Classification"
  when 'PDR'
    result = 'Industrial'
    raise "#{result} is not a supported Occupancy Classification"
  when "RETAIL\/ENT"
    result = 'Retail'
  when 'RESIDENT'
    result = 'Residential'
    raise "#{result} is not a supported Occupancy Classification"
  when 'VISITOR'
    result = 'Lodging'
    raise "#{result} is not a supported Occupancy Classification"
  when 'MISSING DATA'
    result = 'Unknown'
    raise "#{result} is not a supported Occupancy Classification"
  else
    raise "Unknown classification #{classification}"
  end

  return result
end

def calculate_aspect_ratio(feature)
  perimeter = feature[:properties][:"Building Perimeter"]
  footprint_area = feature[:properties][:"Building Footprint Floor Area"]

  aspect = nil
  if perimeter && footprint_area
    perimeter = perimeter.to_f
    footprint_area = footprint_area.to_f

    # perimeter = P = 2*W + 2*L
    # area = A = W*L
    # aspect = L/W
    # W = 0.5*P - L
    # A = 0.5*P*L - L^2
    # 0 = L^2 - 0.5*P*L + A
    # L = (0.5*P +/- sqrt(0.25*P^2-4*A)) / 2
    discriminant = 0.25 * perimeter * perimeter - 4 * footprint_area
    if discriminant >= 0
      length = (0.5 * perimeter + Math.sqrt(discriminant)) / 2.0
      # length = (0.5*perimeter - Math.sqrt(discriminant)) / 2.0
      width = footprint_area / length
      aspect = length / width
    end
  end

  return aspect
end

def create_site(feature)
  site = REXML::Element.new('n1:Site')

  # address
  address = REXML::Element.new('n1:Address')
  street_address_detail = REXML::Element.new('n1:StreetAddressDetail')
  simplified = REXML::Element.new('n1:Simplified')
  street_address = REXML::Element.new('n1:StreetAddress')
  # DLM: there is also a "To Street Number", check if these are equal
  street_number = feature[:properties][:"From Street Number"].to_s
  if street_number != feature[:properties][:"To Street Number"]
    street_number += " - #{feature[:properties][:"To Street Number"]}"
  end
  street_address_text = "#{street_number} #{feature[:properties][:"Street Name"]} #{feature[:properties][:"Street Name Post Type"]}"
  street_address.text = street_address_text
  simplified.add_element(street_address)
  street_address_detail.add_element(simplified)
  address.add_element(street_address_detail)

  city = REXML::Element.new('n1:City')
  city.text = 'San Francisco'
  address.add_element(city)

  state = REXML::Element.new('n1:State')
  state.text = 'CA'
  address.add_element(state)

  postal_code = REXML::Element.new('n1:PostalCode')
  postal_code.text = feature[:properties][:"ZIP Code"]
  address.add_element(postal_code)

  site.add_element(address)

  # climate zone
  # DLM: hard code for now
  climate_zone = REXML::Element.new('n1:ClimateZoneType')

  ashrae = REXML::Element.new('n1:ASHRAE')
  ashrae_climate = REXML::Element.new('n1:ClimateZone')
  ashrae_climate.text = '3C'
  ashrae.add_element(ashrae_climate)
  climate_zone.add_element(ashrae)

  title24 = REXML::Element.new('n1:CaliforniaTitle24')
  title24_climate = REXML::Element.new('n1:ClimateZone')
  title24_climate.text = 'Climate Zone 3'
  title24.add_element(title24_climate)
  climate_zone.add_element(title24)

  site.add_element(climate_zone)

  # weather file
  # DLM: hard code for now

  weather_data_station_id = REXML::Element.new('n1:WeatherDataStationID')
  weather_data_station_id.text = '724940'
  site.add_element(weather_data_station_id)

  weather_station_name = REXML::Element.new('n1:WeatherStationName')
  weather_station_name.text = 'USA_CA_San.Francisco.Intl.AP'
  site.add_element(weather_station_name)

  # longitude
  longitude = REXML::Element.new('n1:Longitude')
  longitude.text = feature[:geometry][:coordinates][0][0][0][0]
  site.add_element(longitude)

  # latitude
  latitude = REXML::Element.new('n1:Latitude')
  latitude.text = feature[:geometry][:coordinates][0][0][0][1]
  site.add_element(latitude)

  # ownership
  ownership = REXML::Element.new('n1:Ownership')
  ownership.text = 'Unknown'
  site.add_element(ownership)
  
  # facilities
  facilities = REXML::Element.new('n1:Facilities')
  facility = REXML::Element.new('n1:Facility')
  facility.attributes['ID'] = "Building#{feature[:properties][:"Building Identifier"]}"

  premises_name = REXML::Element.new('n1:PremisesName')
  premises_name.text = "#{feature[:properties][:"Building Name"]}, #{street_address_text}"
  facility.add_element(premises_name)
  
  premises_notes = REXML::Element.new('n1:PremisesNotes')
  premises_notes.text = ''
  facility.add_element(premises_notes)

  premises_identifiers = REXML::Element.new('n1:PremisesIdentifiers')
  
  premises_identifier = REXML::Element.new('n1:PremisesIdentifier')
  identifier_label = REXML::Element.new('n1:IdentifierLabel')
  identifier_label.text = 'Assessor parcel number'
  premises_identifier.add_element(identifier_label)
  identifier_value = REXML::Element.new('n1:IdentifierValue')
  identifier_value.text = feature[:properties][:"Assessor parcel number"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  # DLM: Custom ID is deprecated, just keeping here for testing with old seed instance
  premises_identifier = REXML::Element.new('n1:PremisesIdentifier')
  identifier_label = REXML::Element.new('n1:IdentifierLabel')
  identifier_label.text = 'Custom'
  premises_identifier.add_element(identifier_label)
  identifier_name = REXML::Element.new('n1:IdentifierCustomName')
  identifier_name.text = 'Custom ID'
  premises_identifier.add_element(identifier_name)
  identifier_value = REXML::Element.new('n1:IdentifierValue')
  identifier_value.text = feature[:properties][:"Building Identifier"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  premises_identifier = REXML::Element.new('n1:PremisesIdentifier')
  identifier_label = REXML::Element.new('n1:IdentifierLabel')
  identifier_label.text = 'Custom'
  premises_identifier.add_element(identifier_label)
  identifier_name = REXML::Element.new('n1:IdentifierCustomName')
  identifier_name.text = 'BRICR Custom ID 1'
  premises_identifier.add_element(identifier_name)
  identifier_value = REXML::Element.new('n1:IdentifierValue')
  identifier_value.text = feature[:properties][:"Building Identifier"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  premises_identifier = REXML::Element.new('n1:PremisesIdentifier')
  identifier_label = REXML::Element.new('n1:IdentifierLabel')
  identifier_label.text = 'Custom'
  premises_identifier.add_element(identifier_label)
  identifier_name = REXML::Element.new('n1:IdentifierCustomName')
  identifier_name.text = 'City Custom Building ID'
  premises_identifier.add_element(identifier_name)
  identifier_value = REXML::Element.new('n1:IdentifierValue')
  identifier_value.text = feature[:properties][:"Building Identifier"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  facility.add_element(premises_identifiers)

  #facility_classification = REXML::Element.new('n1:FacilityClassification')
  #facility_classification.text = get_facility_classification(feature)
  #facility.add_element(facility_classification)

  #occupancy_classification = REXML::Element.new('n1:OccupancyClassification')
  #occupancy_classification.text = get_occupancy_classification(feature)
  #facility.add_element(occupancy_classification)

  floors_above_grade = REXML::Element.new('n1:FloorsAboveGrade')
  floors_above_grade.text = feature[:properties][:"Number of Floors"] # DLM need to map this?
  facility.add_element(floors_above_grade)

  floors_below_grade = REXML::Element.new('n1:FloorsBelowGrade')
  floors_below_grade.text = 0 # DLM need to map this?
  facility.add_element(floors_below_grade)

  floor_areas = REXML::Element.new('n1:FloorAreas')

  floor_area = REXML::Element.new('n1:FloorArea')
  floor_area_type = REXML::Element.new('n1:FloorAreaType')
  floor_area_type.text = 'Gross'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('n1:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('n1:FloorArea')
  floor_area_type = REXML::Element.new('n1:FloorAreaType')
  floor_area_type.text = 'Heated and Cooled'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('n1:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('n1:FloorArea')
  floor_area_type = REXML::Element.new('n1:FloorAreaType')
  floor_area_type.text = 'Footprint'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('n1:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Building Footprint Floor Area"], 'm2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)

  facility.add_element(floor_areas)

  # aspect ratio and perimeter
  if ar = calculate_aspect_ratio(feature)
    aspect_ratio = REXML::Element.new('n1:AspectRatio')
    aspect_ratio.text = ar
    facility.add_element(aspect_ratio)
  end

  perimeter = REXML::Element.new('n1:Perimeter')
  perimeter.text = convert(feature[:properties][:"Building Perimeter"], 'm', 'ft').to_i # DLM: BS thinks this is an int
  facility.add_element(perimeter)

  # year of construction and modified
  year_of_construction = REXML::Element.new('n1:YearOfConstruction')
  year_of_construction.text = feature[:properties][:"Completed Construction Status Date"]
  facility.add_element(year_of_construction)

  if md = /^(\d\d\d\d).*/.match(feature[:properties][:"Last Modified Date"].to_s)
    year_of_last_major_remodel = REXML::Element.new('n1:YearOfLastMajorRemodel')
    year_of_last_major_remodel.text = md[1]
    facility.add_element(year_of_last_major_remodel)
  end
  
  # subsections
  subsections = REXML::Element.new('n1:Subsections')
  
  # create single subsection
  subsection = REXML::Element.new('n1:Subsection')
  subsection.attributes['ID'] = "Default_Subsection"

  occupancy_classification = REXML::Element.new('n1:OccupancyClassification')
  occupancy_classification.text = get_occupancy_classification(feature)
  subsection.add_element(occupancy_classification)
  
  typical_occupant_usages = REXML::Element.new('n1:TypicalOccupantUsages')
  
  typical_occupant_usage = REXML::Element.new('n1:TypicalOccupantUsage')
  typical_occupant_usage_value = REXML::Element.new('n1:TypicalOccupantUsageValue')
  typical_occupant_usage_value.text = '40.0'
  typical_occupant_usage.add_element(typical_occupant_usage_value)
  typical_occupant_usage_units = REXML::Element.new('n1:TypicalOccupantUsageUnits')
  typical_occupant_usage_units.text = 'Hours per week'
  typical_occupant_usage.add_element(typical_occupant_usage_units)
  typical_occupant_usages.add_element(typical_occupant_usage)
  
  typical_occupant_usage = REXML::Element.new('n1:TypicalOccupantUsage')
  typical_occupant_usage_value = REXML::Element.new('n1:TypicalOccupantUsageValue')
  typical_occupant_usage_value.text = '50.0'
  typical_occupant_usage.add_element(typical_occupant_usage_value)
  typical_occupant_usage_units = REXML::Element.new('n1:TypicalOccupantUsageUnits')
  typical_occupant_usage_units.text = 'Weeks per year'
  typical_occupant_usage.add_element(typical_occupant_usage_units)
  typical_occupant_usages.add_element(typical_occupant_usage)
  
  subsection.add_element(typical_occupant_usages)
  
  floor_areas = REXML::Element.new('n1:FloorAreas')

  floor_area = REXML::Element.new('n1:FloorArea')
  floor_area_type = REXML::Element.new('n1:FloorAreaType')
  floor_area_type.text = 'Gross'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('n1:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('n1:FloorArea')
  floor_area_type = REXML::Element.new('n1:FloorAreaType')
  floor_area_type.text = 'Tenant'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('n1:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('n1:FloorArea')
  floor_area_type = REXML::Element.new('n1:FloorAreaType')
  floor_area_type.text = 'Common'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('n1:FloorAreaValue')
  floor_area_value.text = '0.0'
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  subsection.add_element(floor_areas)
  
  # put it all together
  subsections.add_element(subsection)
  facility.add_element(subsections)
  facilities.add_element(facility)
  site.add_element(facilities)

  return site
end

def convert_feature(feature)
  
  # this is where we estimate Phase 0 measure costs
  id = feature[:properties][:"Building Identifier"]
  floor_area = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  
  facility_id = "Building#{id}"
  
  measures = []
  measures << {ID: 'Measure1',
               SystemCategoryAffected: 'Lighting', 
               TechnologyCategory: 'LightingImprovements', 
               MeasureName: 'Retrofit with light emitting diode technologies',
               ScenarioName: 'LED',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
               
  measures << {ID: 'Measure2',
               SystemCategoryAffected: 'Plug Load', 
               TechnologyCategory: 'PlugLoadReductions', 
               MeasureName: 'Replace with ENERGY STAR rated',
               ScenarioName: 'Electric_Appliance_30%_Reduction',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
               
  measures << {ID: 'Measure3',
               SystemCategoryAffected: 'Wall', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Air seal envelope',
               ScenarioName: 'Air_Seal_Infiltration_30%_More_Airtight',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}

  measures << {ID: 'Measure4',
               SystemCategoryAffected: 'Cooling System', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Replace package units',
               ScenarioName: 'Cooling_System_SEER 14',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
               
  measures << {ID: 'Measure5',
               SystemCategoryAffected: 'Heating System', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Replace burner',
               ScenarioName: 'Heating_System_Efficiency_0.93',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
               
  measures << {ID: 'Measure6',
               SystemCategoryAffected: 'Lighting', 
               TechnologyCategory: 'LightingImprovements', 
               MeasureName: 'Add daylight controls',
               ScenarioName: 'Add daylight controls',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
      
  measures << {ID: 'Measure7',
               SystemCategoryAffected: 'Lighting', 
               TechnologyCategory: 'LightingImprovements', 
               MeasureName: 'Add occupancy sensors',
               ScenarioName: 'Add occupancy sensors',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
     
  measures << {ID: 'Measure8',
               SystemCategoryAffected: 'Plug Load', 
               TechnologyCategory: 'PlugLoadReductions', 
               MeasureName: 'Install plug load controls',
               ScenarioName: 'Install plug load controls',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
     
  measures << {ID: 'Measure9',
               SystemCategoryAffected: 'Wall', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Increase wall insulation',
               ScenarioName: 'Increase wall insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
      
  measures << {ID: 'Measure10',
               SystemCategoryAffected: 'Wall', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Insulate thermal bypasses',
               ScenarioName: 'Insulate thermal bypasses',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}

  measures << {ID: 'Measure11',
               SystemCategoryAffected: 'Roof', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Increase roof insulation',
               ScenarioName: 'Increase roof insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
               
  measures << {ID: 'Measure12',
               SystemCategoryAffected: 'Ceiling', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Increase ceiling insulation',
               ScenarioName: 'Increase ceiling insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
               
  measures << {ID: 'Measure13',
               SystemCategoryAffected: 'Fenestration', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Add window films',
               ScenarioName: 'Add window films',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
               
  measures << {ID: 'Measure14',
               SystemCategoryAffected: 'General Controls and Operations', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Upgrade operating protocols, calibration, and/or sequencing',
               ScenarioName: 'Upgrade operating protocols, calibration, and/or sequencing',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure15',
               SystemCategoryAffected: 'Domestic Hot Water', 
               TechnologyCategory: 'ChilledWaterHotWaterAndSteamDistributionSystems', 
               MeasureName: 'Replace or upgrade water heater',
               ScenarioName: 'Replace or upgrade water heater',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure16',
               SystemCategoryAffected: 'Refrigeration', 
               TechnologyCategory: 'Refrigeration', 
               MeasureName: 'Replace ice/refrigeration equipment with high efficiency units',
               ScenarioName: 'Replace ice/refrigeration equipment with high efficiency units',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure17',
               SystemCategoryAffected: 'Fenestration', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Replace windows',
               ScenarioName: 'Replace windows',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure18',
               SystemCategoryAffected: 'Heating System', 
               TechnologyCategory: 'BoilerPlantImprovements', 
               MeasureName: 'Replace boiler',
               ScenarioName: 'Replace boiler',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure19',
               SystemCategoryAffected: 'Other HVAC', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Replace AC and heating units with ground coupled heat pump systems',
               ScenarioName: 'Replace HVAC with GSHP and DOAS',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure20',
               SystemCategoryAffected: 'Other HVAC', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Other',
               ScenarioName: 'VRF with DOAS',
               OpenStudioMeasureName: 'Replace HVAC system type to VRF',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure21',
               SystemCategoryAffected: 'Other HVAC', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Other',
               ScenarioName: 'Replace HVAC system type to PZHP',
               OpenStudioMeasureName: 'Replace HVAC system type to PZHP',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure22',
               SystemCategoryAffected: 'Fan', 
               TechnologyCategory: 'OtherElectricMotorsAndDrives', 
               MeasureName: 'Replace with higher efficiency',
               ScenarioName: 'Replace with higher efficiency',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure23',
               SystemCategoryAffected: 'Air Distribution', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Improve ventilation fans',
               ScenarioName: 'Improve ventilation fans',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure24',
               SystemCategoryAffected: 'Air Distribution', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Install demand control ventilation',
               ScenarioName: 'Install demand control ventilation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}

  measures << {ID: 'Measure25',
               SystemCategoryAffected: 'Air Distribution', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Add or repair economizer',
               ScenarioName: 'Add or repair economizer',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure26',
               SystemCategoryAffected: 'Heat Recovery', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Add energy recovery',
               ScenarioName: 'Add energy recovery',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure27',
               SystemCategoryAffected: 'Domestic Hot Water', 
               TechnologyCategory: 'ChilledWaterHotWaterAndSteamDistributionSystems', 
               MeasureName: 'Add pipe insulation',
               ScenarioName: 'Add pipe insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure28',
               SystemCategoryAffected: 'Domestic Hot Water', 
               TechnologyCategory: 'ChilledWaterHotWaterAndSteamDistributionSystems', 
               MeasureName: 'Add recirculating pumps',
               ScenarioName: 'Add recirculating pumps',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
  
  measures << {ID: 'Measure29',
               SystemCategoryAffected: 'Water Use', 
               TechnologyCategory: 'WaterAndSewerConservationSystems', 
               MeasureName: 'Install low-flow faucets and showerheads',
               ScenarioName: 'Install low-flow faucets and showerheads',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 10,
               MeasureTotalFirstCost: 1*floor_area}
                                                       
  source = '
  <n1:Audits xmlns:n1="http://nrel.gov/schemas/bedes-auc/2014" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://nrel.gov/schemas/bedes-auc/2014 https://github.com/BuildingSync/schema/releases/download/v0.3/BuildingSync.xsd">
	<n1:Audit>
		<n1:Sites>
		</n1:Sites>
    <n1:Measures>
'
  measures.each do |measure|
    source += "      <n1:Measure ID=\"#{measure[:ID]}\">
        <n1:SystemCategoryAffected>#{measure[:SystemCategoryAffected]}</n1:SystemCategoryAffected>
        <n1:PremisesAffected>
          <n1:PremiseAffected IDref=\"#{facility_id}\"/>
        </n1:PremisesAffected>
        <n1:TechnologyCategories>
          <n1:TechnologyCategory>
            <n1:#{measure[:TechnologyCategory]}>
              <n1:MeasureName>#{measure[:MeasureName]}</n1:MeasureName>
            </n1:#{measure[:TechnologyCategory]}>
          </n1:TechnologyCategory>
        </n1:TechnologyCategories>
        <n1:MeasureScaleOfApplication>Entire facility</n1:MeasureScaleOfApplication>
        <n1:LongDescription>#{measure[:MeasureName]}</n1:LongDescription>
        <n1:MVCost>0</n1:MVCost>
        <n1:UsefulLife>#{measure[:UsefulLife]}</n1:UsefulLife>
        <n1:MeasureTotalFirstCost>#{measure[:MeasureTotalFirstCost]}</n1:MeasureTotalFirstCost>
        <n1:MeasureInstallationCost>0</n1:MeasureInstallationCost>
        <n1:MeasureMaterialCost>0</n1:MeasureMaterialCost>
        <n1:Recommended>true</n1:Recommended>
        <n1:ImplementationStatus>Proposed</n1:ImplementationStatus>
        <n1:UserDefinedFields>
          <n1:UserDefinedField>
            <n1:FieldName>OpenStudioMeasureName</n1:FieldName>
            <n1:FieldValue>#{measure[:OpenStudioMeasureName]}</n1:FieldValue>
          </n1:UserDefinedField>  
        </n1:UserDefinedFields>
      </n1:Measure>
"    
  end

  source += '   </n1:Measures>
    <n1:Report>
      <n1:Scenarios>
        <n1:Scenario ID="Baseline">
          <n1:ScenarioName>Baseline</n1:ScenarioName>
          <n1:ScenarioType>
            <n1:PackageOfMeasures>
              <n1:ReferenceCase IDref="Baseline"/>
            </n1:PackageOfMeasures>
          </n1:ScenarioType>
        </n1:Scenario>
  '
  measures.each do |measure|
    source += "        <n1:Scenario>
          <n1:ScenarioName>#{measure[:ScenarioName]} Only</n1:ScenarioName>
          <n1:ScenarioType>
            <n1:PackageOfMeasures>
              <n1:ReferenceCase IDref=\"Baseline\"/>
              <n1:MeasureIDs>
                <n1:MeasureID IDref=\"#{measure[:ID]}\"/>
              </n1:MeasureIDs>
            </n1:PackageOfMeasures>
          </n1:ScenarioType>
        </n1:Scenario>
"    
  end
  
  source += '      </n1:Scenarios>
    </n1:Report>
  </n1:Audit>
</n1:Audits>
  '
  
  doc = REXML::Document.new(source)
  sites = doc.elements['*/*/n1:Sites']
  site = create_site(feature)
  sites.add_element(site)

  return doc
end

geojson = nil
File.open(ARGV[0], 'r') do |file|
  geojson = JSON.parse(file.read, symbolize_names: true)
end

outdir = './bs_output'
FileUtils.mkdir_p(outdir) unless File.exist?(outdir)

summary_file = File.open(outdir + "/summary.csv", 'w')
summary_file.puts "building_id,xml_filename,should_run_simulation,OccupancyClassification,FloorArea(ft2),YearBuilt,template,SiteEUI(kBtu/ft2),SourceEUI(kBtu/ft2),ElectricityEUI(kBtu/ft2),GasEUI(kBtu/ft2),YearEUI"

geojson[:features].each do |feature|
  id = feature[:properties][:"Building Identifier"]

  puts "id = #{id}"
  
  begin
    doc = convert_feature(feature)
    filename = File.join(outdir, "#{id}.xml")
    File.open(filename, 'w') do |file|
      doc.write(file)
    end
  rescue => e
    puts "Building #{id} not converted, #{e.message}"
    next
  end

  floor_area = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  building_type = get_occupancy_classification(feature)
  year_of_construction = feature[:properties][:"Completed Construction Status Date"]
  year_of_last_major_remodel = nil
  if md = /^(\d\d\d\d).*/.match(feature[:properties][:"Last Modified Date"].to_s)
    year_of_last_major_remodel = md[1]
  end

  site_eui = nil
  source_eui =nil
  ele_eui = nil
  gas_eui = nil
  year_eui = nil
  for year in 2011..2015
    if feature[:properties][:"#{year} Annual Site Energy Resource Intensity"] != nil
      site_eui = feature[:properties][:"#{year} Annual Site Energy Resource Intensity"].to_f
      year_eui = year
    end

    if feature[:properties][:"#{year} Annual Source Energy Resource Intensity"] != nil
      source_eui = feature[:properties][:"#{year} Annual Source Energy Resource Intensity"].to_f
      year_eui = year
    end
  end

  if year_of_last_major_remodel != nil and year_of_last_major_remodel.to_i > 1000
    year_built = year_of_last_major_remodel.to_i
  else
    year_built = year_of_construction.to_i
  end

  if year_built < 1978
    template = "CEC Pre-1978"
  elsif year_built >= 1978 && year_built < 1992
    template = "CBES T24 1978"
  elsif year_built >= 1992 && year_built < 2001
    template = "CBES T24 1992"
  elsif year_built >= 2001 && year_built < 2005
    template = "CBES T24 2001"
  elsif year_built >= 2005 && year_built < 2008
    template = "CBES T24 2005"
  else
    template = "CBES T24 2008"
  end

  # source factor: 1.05 for gas, 3.14 for electricity
  if site_eui != nil and source_eui != nil
    ele_eui = (source_eui - site_eui * 1.05)/(3.14-1.05)
    gas_eui = site_eui - ele_eui
  end

  summary_file.puts "#{id},#{id}.xml,1,#{building_type},#{floor_area},#{year_built},#{template},#{site_eui},#{source_eui},#{ele_eui},#{gas_eui},#{year_eui}"
end

summary_file.close