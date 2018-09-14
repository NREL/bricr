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

def get_facility_id(feature)
  return "Building#{feature[:properties][:"Building Identifier"]}"
end

def get_floor_area(feature)
  return convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
end

def create_site(feature)
  site = REXML::Element.new('auc:Site')
  feature_id = get_facility_id(feature)
  
  raise "Facility ID is empty" if feature_id.nil?

  # address
  address = REXML::Element.new('auc:Address')
  street_address_detail = REXML::Element.new('auc:StreetAddressDetail')
  simplified = REXML::Element.new('auc:Simplified')
  street_address = REXML::Element.new('auc:StreetAddress')
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

  city = REXML::Element.new('auc:City')
  city.text = 'San Francisco'
  address.add_element(city)

  state = REXML::Element.new('auc:State')
  state.text = 'CA'
  address.add_element(state)

  # if zip code is nil, default for now
  feature[:properties][:"ZIP Code"] = 94104 if feature[:properties][:"ZIP Code"].nil?
  raise "ZIP Code is not set" if feature[:properties][:"ZIP Code"].nil?
  postal_code = REXML::Element.new('auc:PostalCode')
  postal_code.text = feature[:properties][:"ZIP Code"]
  address.add_element(postal_code)

  site.add_element(address)

  # climate zone
  # DLM: hard code for now
  climate_zone = REXML::Element.new('auc:ClimateZoneType')

  ashrae = REXML::Element.new('auc:ASHRAE')
  ashrae_climate = REXML::Element.new('auc:ClimateZone')
  ashrae_climate.text = '3C'
  ashrae.add_element(ashrae_climate)
  climate_zone.add_element(ashrae)

  title24 = REXML::Element.new('auc:CaliforniaTitle24')
  title24_climate = REXML::Element.new('auc:ClimateZone')
  title24_climate.text = 'Climate Zone 3'
  title24.add_element(title24_climate)
  climate_zone.add_element(title24)

  site.add_element(climate_zone)

  # weather file
  # DLM: hard code for now

  weather_data_station_id = REXML::Element.new('auc:WeatherDataStationID')
  weather_data_station_id.text = '724940'
  site.add_element(weather_data_station_id)

  weather_station_name = REXML::Element.new('auc:WeatherStationName')
  weather_station_name.text = 'USA_CA_San.Francisco.Intl.AP'
  site.add_element(weather_station_name)

  # longitude
  raise "Longitude is not set" if feature[:geometry].nil? || feature[:geometry][:coordinates].nil?
  longitude = REXML::Element.new('auc:Longitude')
  longitude.text = feature[:geometry][:coordinates][0][0][0][0]
  site.add_element(longitude)

  # latitude
  raise "Latitude is not set" if feature[:geometry].nil? || feature[:geometry][:coordinates].nil?
  latitude = REXML::Element.new('auc:Latitude')
  latitude.text = feature[:geometry][:coordinates][0][0][0][1]
  site.add_element(latitude)

  # ownership
  ownership = REXML::Element.new('auc:Ownership')
  ownership.text = 'Unknown'
  site.add_element(ownership)
  
  # facilities
  facilities = REXML::Element.new('auc:Facilities')
  facility = REXML::Element.new('auc:Facility')
  facility.attributes['ID'] = feature_id

  # default name
  feature[:properties][:"Building Name"] = "Building" if feature[:properties][:"Building Name"].nil?
  raise "Building Name is not set" if feature[:properties][:"Building Name"].nil?
  premises_name = REXML::Element.new('auc:PremisesName')
  premises_name.text = "#{feature[:properties][:"Building Name"]} [#{street_address_text}]"
  facility.add_element(premises_name)
  
  premises_notes = REXML::Element.new('auc:PremisesNotes')
  premises_notes.text = ''
  facility.add_element(premises_notes)

  premises_identifiers = REXML::Element.new('auc:PremisesIdentifiers')
  
  premises_identifier = REXML::Element.new('auc:PremisesIdentifier')
  identifier_label = REXML::Element.new('auc:IdentifierLabel')
  identifier_label.text = 'Assessor parcel number'
  premises_identifier.add_element(identifier_label)
  identifier_value = REXML::Element.new('auc:IdentifierValue')
  identifier_value.text = feature[:properties][:"Assessor parcel number"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  # DLM: Custom ID is deprecated, just keeping here for testing with old seed instance
  premises_identifier = REXML::Element.new('auc:PremisesIdentifier')
  identifier_label = REXML::Element.new('auc:IdentifierLabel')
  identifier_label.text = 'Custom'
  premises_identifier.add_element(identifier_label)
  identifier_name = REXML::Element.new('auc:IdentifierCustomName')
  identifier_name.text = 'Custom ID'
  premises_identifier.add_element(identifier_name)
  identifier_value = REXML::Element.new('auc:IdentifierValue')
  identifier_value.text = feature[:properties][:"Building Identifier"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  premises_identifier = REXML::Element.new('auc:PremisesIdentifier')
  identifier_label = REXML::Element.new('auc:IdentifierLabel')
  identifier_label.text = 'Custom'
  premises_identifier.add_element(identifier_label)
  identifier_name = REXML::Element.new('auc:IdentifierCustomName')
  identifier_name.text = 'Custom ID 1'
  premises_identifier.add_element(identifier_name)
  identifier_value = REXML::Element.new('auc:IdentifierValue')
  identifier_value.text = feature[:properties][:"Building Identifier"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  premises_identifier = REXML::Element.new('auc:PremisesIdentifier')
  identifier_label = REXML::Element.new('auc:IdentifierLabel')
  identifier_label.text = 'Custom'
  premises_identifier.add_element(identifier_label)
  identifier_name = REXML::Element.new('auc:IdentifierCustomName')
  identifier_name.text = 'City Custom Building ID'
  premises_identifier.add_element(identifier_name)
  identifier_value = REXML::Element.new('auc:IdentifierValue')
  identifier_value.text = feature[:properties][:"Building Identifier"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
  facility.add_element(premises_identifiers)

  #facility_classification = REXML::Element.new('auc:FacilityClassification')
  #facility_classification.text = get_facility_classification(feature)
  #facility.add_element(facility_classification)

  #occupancy_classification = REXML::Element.new('auc:OccupancyClassification')
  #occupancy_classification.text = get_occupancy_classification(feature)
  #facility.add_element(occupancy_classification)

  floors_above_grade = REXML::Element.new('auc:FloorsAboveGrade')
  floors_above_grade.text = feature[:properties][:"Number of Floors"] # DLM need to map this?
  facility.add_element(floors_above_grade)

  floors_below_grade = REXML::Element.new('auc:FloorsBelowGrade')
  floors_below_grade.text = 0 # DLM need to map this?
  facility.add_element(floors_below_grade)

  floor_areas = REXML::Element.new('auc:FloorAreas')

  floor_area = REXML::Element.new('auc:FloorArea')
  floor_area_type = REXML::Element.new('auc:FloorAreaType')
  floor_area_type.text = 'Gross'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('auc:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('auc:FloorArea')
  floor_area_type = REXML::Element.new('auc:FloorAreaType')
  floor_area_type.text = 'Heated and Cooled'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('auc:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('auc:FloorArea')
  floor_area_type = REXML::Element.new('auc:FloorAreaType')
  floor_area_type.text = 'Footprint'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('auc:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Building Footprint Floor Area"], 'm2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)

  facility.add_element(floor_areas)

  # aspect ratio and perimeter
  if ar = calculate_aspect_ratio(feature)
    aspect_ratio = REXML::Element.new('auc:AspectRatio')
    aspect_ratio.text = ar
    facility.add_element(aspect_ratio)
  end

  perimeter = REXML::Element.new('auc:Perimeter')
  perimeter.text = convert(feature[:properties][:"Building Perimeter"], 'm', 'ft').to_i # DLM: BS thinks this is an int
  facility.add_element(perimeter)

  # year of construction and modified
  year_of_construction = REXML::Element.new('auc:YearOfConstruction')
  year_of_construction.text = feature[:properties][:"Completed Construction Status Date"]
  facility.add_element(year_of_construction)

  if md = /^(\d\d\d\d).*/.match(feature[:properties][:"Last Modified Date"].to_s)
    year_of_last_major_remodel = REXML::Element.new('auc:YearOfLastMajorRemodel')
    year_of_last_major_remodel.text = md[1]
    facility.add_element(year_of_last_major_remodel)
  end
  
  # subsections
  subsections = REXML::Element.new('auc:Subsections')
  
  # create single subsection
  subsection = REXML::Element.new('auc:Subsection')
  subsection.attributes['ID'] = "Default_Subsection"

  occupancy_classification = REXML::Element.new('auc:OccupancyClassification')
  occupancy_classification.text = get_occupancy_classification(feature)
  subsection.add_element(occupancy_classification)
  
  typical_occupant_usages = REXML::Element.new('auc:TypicalOccupantUsages')
  
  typical_occupant_usage = REXML::Element.new('auc:TypicalOccupantUsage')
  typical_occupant_usage_value = REXML::Element.new('auc:TypicalOccupantUsageValue')
  typical_occupant_usage_value.text = '40.0'
  typical_occupant_usage.add_element(typical_occupant_usage_value)
  typical_occupant_usage_units = REXML::Element.new('auc:TypicalOccupantUsageUnits')
  typical_occupant_usage_units.text = 'Hours per week'
  typical_occupant_usage.add_element(typical_occupant_usage_units)
  typical_occupant_usages.add_element(typical_occupant_usage)
  
  typical_occupant_usage = REXML::Element.new('auc:TypicalOccupantUsage')
  typical_occupant_usage_value = REXML::Element.new('auc:TypicalOccupantUsageValue')
  typical_occupant_usage_value.text = '50.0'
  typical_occupant_usage.add_element(typical_occupant_usage_value)
  typical_occupant_usage_units = REXML::Element.new('auc:TypicalOccupantUsageUnits')
  typical_occupant_usage_units.text = 'Weeks per year'
  typical_occupant_usage.add_element(typical_occupant_usage_units)
  typical_occupant_usages.add_element(typical_occupant_usage)
  
  subsection.add_element(typical_occupant_usages)
  
  floor_areas = REXML::Element.new('auc:FloorAreas')

  floor_area = REXML::Element.new('auc:FloorArea')
  floor_area_type = REXML::Element.new('auc:FloorAreaType')
  floor_area_type.text = 'Gross'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('auc:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('auc:FloorArea')
  floor_area_type = REXML::Element.new('auc:FloorAreaType')
  floor_area_type.text = 'Tenant'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('auc:FloorAreaValue')
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new('auc:FloorArea')
  floor_area_type = REXML::Element.new('auc:FloorAreaType')
  floor_area_type.text = 'Common'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new('auc:FloorAreaValue')
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
  facility_id = get_facility_id(feature)
  floor_area = get_floor_area(feature)
  
  measures = []
  measures << {ID: 'Measure1',
               SingleMeasure: true,
               SystemCategoryAffected: 'Lighting', 
               TechnologyCategory: 'LightingImprovements', 
               MeasureName: 'Retrofit with light emitting diode technologies',
               LongDescription: 'Retrofit with light emitting diode technologies',
               ScenarioName: 'LED',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 3.85*floor_area}
               
  measures << {ID: 'Measure2',
               SingleMeasure: true,
               SystemCategoryAffected: 'Plug Load', 
               TechnologyCategory: 'PlugLoadReductions', 
               MeasureName: 'Replace with ENERGY STAR rated',
               LongDescription: 'Replace with ENERGY STAR rated',
               ScenarioName: 'Electric_Appliance_30%_Reduction',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.51*floor_area}
               
  measures << {ID: 'Measure3',
               SingleMeasure: true,
               SystemCategoryAffected: 'Wall', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Air seal envelope',
               LongDescription: 'Air seal envelope',
               ScenarioName: 'Air_Seal_Infiltration_30%_More_Airtight',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 2.34*floor_area}

  measures << {ID: 'Measure4',
               SingleMeasure: true,
               SystemCategoryAffected: 'Cooling System', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Replace package units',
               LongDescription: 'Replace package units',
               ScenarioName: 'Cooling_System_SEER 14',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 4.18*floor_area}
               
  measures << {ID: 'Measure5',
               SingleMeasure: true,
               SystemCategoryAffected: 'Heating System', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Replace burner',
               LongDescription: 'Replace burner',
               ScenarioName: 'Heating_System_Efficiency_0.93',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.89*floor_area}
               
  measures << {ID: 'Measure6',
               SingleMeasure: true,
               SystemCategoryAffected: 'Lighting', 
               TechnologyCategory: 'LightingImprovements', 
               MeasureName: 'Add daylight controls',
               LongDescription: 'Add daylight controls',
               ScenarioName: 'Add daylight controls',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.53*floor_area}
      
  measures << {ID: 'Measure7',
               SingleMeasure: true,
               SystemCategoryAffected: 'Lighting', 
               TechnologyCategory: 'LightingImprovements', 
               MeasureName: 'Add occupancy sensors',
               LongDescription: 'Add occupancy sensors',
               ScenarioName: 'Add occupancy sensors',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 1.55*floor_area}
     
  measures << {ID: 'Measure8',
               SingleMeasure: true,
               SystemCategoryAffected: 'Plug Load', 
               TechnologyCategory: 'PlugLoadReductions', 
               MeasureName: 'Install plug load controls',
               LongDescription: 'Install plug load controls',
               ScenarioName: 'Install plug load controls',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.82*floor_area}
     
  measures << {ID: 'Measure9',
               SingleMeasure: true,
               SystemCategoryAffected: 'Wall', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Increase wall insulation',
               LongDescription: 'Increase wall insulation',
               ScenarioName: 'Increase wall insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 1.63*floor_area}
      
  measures << {ID: 'Measure10',
               SingleMeasure: true,
               SystemCategoryAffected: 'Wall', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Insulate thermal bypasses',
               LongDescription: 'Insulate thermal bypasses',
               ScenarioName: 'Insulate thermal bypasses',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 1.00*floor_area}

  measures << {ID: 'Measure11',
               SingleMeasure: true,
               SystemCategoryAffected: 'Roof', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Increase roof insulation',
               LongDescription: 'Increase roof insulation',
               ScenarioName: 'Increase roof insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 14.46*floor_area}
               
  measures << {ID: 'Measure12',
               SingleMeasure: true,
               SystemCategoryAffected: 'Ceiling', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Increase ceiling insulation',
               LongDescription: 'Increase ceiling insulation',
               ScenarioName: 'Increase ceiling insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 2.67*floor_area}
               
  measures << {ID: 'Measure13',
               SingleMeasure: true,
               SystemCategoryAffected: 'Fenestration', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Add window films',
               LongDescription: 'Add window films',
               ScenarioName: 'Add window films',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 1.00*floor_area}
               
  measures << {ID: 'Measure14',
               SingleMeasure: true,
               SystemCategoryAffected: 'General Controls and Operations', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Upgrade operating protocols, calibration, and/or sequencing',
               LongDescription: 'Upgrade operating protocols, calibration, and/or sequencing',
               ScenarioName: 'Upgrade operating protocols calibration and-or sequencing',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.005*floor_area}
  
  measures << {ID: 'Measure15',
               SingleMeasure: true,
               SystemCategoryAffected: 'Domestic Hot Water', 
               TechnologyCategory: 'ChilledWaterHotWaterAndSteamDistributionSystems', 
               MeasureName: 'Replace or upgrade water heater',
               LongDescription: 'Replace or upgrade water heater',
               ScenarioName: 'Replace or upgrade water heater',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.17*floor_area}
  
  measures << {ID: 'Measure16',
               SingleMeasure: true,
               SystemCategoryAffected: 'Refrigeration', 
               TechnologyCategory: 'Refrigeration', 
               MeasureName: 'Replace ice/refrigeration equipment with high efficiency units',
               LongDescription: 'Replace ice/refrigeration equipment with high efficiency units',
               ScenarioName: 'Replace ice-refrigeration equipment with high efficiency units',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 1.95*floor_area}
  
  measures << {ID: 'Measure17',
               SingleMeasure: true,
               SystemCategoryAffected: 'Fenestration', 
               TechnologyCategory: 'BuildingEnvelopeModifications', 
               MeasureName: 'Replace windows',
               LongDescription: 'Replace windows',
               ScenarioName: 'Replace windows',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 2.23*floor_area}
  
  measures << {ID: 'Measure18',
               SingleMeasure: true,
               SystemCategoryAffected: 'Heating System', 
               TechnologyCategory: 'BoilerPlantImprovements', 
               MeasureName: 'Replace boiler',
               LongDescription: 'Replace boiler',
               ScenarioName: 'Replace boiler',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.95*floor_area}
  
  measures << {ID: 'Measure19',
               SingleMeasure: true,
               SystemCategoryAffected: 'Other HVAC', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Replace AC and heating units with ground coupled heat pump systems',
               LongDescription: 'Replace AC and heating units with ground coupled heat pump systems',
               ScenarioName: 'Replace HVAC with GSHP and DOAS',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 14.00*floor_area}
  
  measures << {ID: 'Measure20',
               SingleMeasure: true,
               SystemCategoryAffected: 'Other HVAC', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Other',
               LongDescription: 'VRF with DOAS',
               ScenarioName: 'VRF with DOAS',
               OpenStudioMeasureName: 'Replace HVAC system type to VRF',
               UsefulLife: 20,
               MeasureTotalFirstCost: 16.66*floor_area}
  
  measures << {ID: 'Measure21',
               SingleMeasure: true,
               SystemCategoryAffected: 'Other HVAC', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Other',
               LongDescription: 'Replace HVAC system type to PZHP',
               ScenarioName: 'Replace HVAC system type to PZHP',
               OpenStudioMeasureName: 'Replace HVAC system type to PZHP',
               UsefulLife: 20,
               MeasureTotalFirstCost: 4.26*floor_area}
  
  measures << {ID: 'Measure22',
               SingleMeasure: true,
               SystemCategoryAffected: 'Fan', 
               TechnologyCategory: 'OtherElectricMotorsAndDrives', 
               MeasureName: 'Replace with higher efficiency',
               LongDescription: 'Replace with higher efficiency',
               ScenarioName: 'Replace with higher efficiency',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 10.75*floor_area}
  
  measures << {ID: 'Measure23',
               SingleMeasure: true,
               SystemCategoryAffected: 'Air Distribution', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Improve ventilation fans',
               LongDescription: 'Improve ventilation fans',
               ScenarioName: 'Improve ventilation fans',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 1.00*floor_area}
  
  measures << {ID: 'Measure24',
               SingleMeasure: true,
               SystemCategoryAffected: 'Air Distribution', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Install demand control ventilation',
               LongDescription: 'Install demand control ventilation',
               ScenarioName: 'Install demand control ventilation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.33*floor_area}

  measures << {ID: 'Measure25',
               SingleMeasure: true,
               SystemCategoryAffected: 'Air Distribution', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Add or repair economizer',
               LongDescription: 'Add or repair economizer',
               ScenarioName: 'Add or repair economizer',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.80*floor_area}
  
  measures << {ID: 'Measure26',
               SingleMeasure: true,
               SystemCategoryAffected: 'Heat Recovery', 
               TechnologyCategory: 'OtherHVAC', 
               MeasureName: 'Add energy recovery',
               LongDescription: 'Add energy recovery',
               ScenarioName: 'Add energy recovery',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 4.53*floor_area}
  
  measures << {ID: 'Measure27',
               SingleMeasure: true,
               SystemCategoryAffected: 'Domestic Hot Water', 
               TechnologyCategory: 'ChilledWaterHotWaterAndSteamDistributionSystems', 
               MeasureName: 'Add pipe insulation',
               LongDescription: 'Add pipe insulation',
               ScenarioName: 'Add pipe insulation',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
                MeasureTotalFirstCost: 0.14*floor_area}
  
  measures << {ID: 'Measure28',
               SingleMeasure: true,
               SystemCategoryAffected: 'Domestic Hot Water', 
               TechnologyCategory: 'ChilledWaterHotWaterAndSteamDistributionSystems', 
               MeasureName: 'Add recirculating pumps',
               LongDescription: 'Add recirculating pumps',
               ScenarioName: 'Add recirculating pumps',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 0.18*floor_area}
  
  measures << {ID: 'Measure29',
               SingleMeasure: true,
               SystemCategoryAffected: 'Water Use', 
               TechnologyCategory: 'WaterAndSewerConservationSystems', 
               MeasureName: 'Install low-flow faucets and showerheads',
               LongDescription: 'Install low-flow faucets and showerheads',
               ScenarioName: 'Install low-flow faucets and showerheads',
               OpenStudioMeasureName: 'TBD',
               UsefulLife: 20,
               MeasureTotalFirstCost: 1.00*floor_area}
  
  packages = []
  packages << {ScenarioName: 'Retail Package',
               MeasureIDs: ['Measure1', 'Measure2', 'Measure8', 'Measure14', 'Measure29']}
  
  packages << {ScenarioName: 'Office-Tenant Package',
               MeasureIDs: ['Measure1', 'Measure2', 'Measure7', 'Measure8', 'Measure13', 'Measure14', 'Measure24', 'Measure29']}
  
  packages << {ScenarioName: 'Office-Central Systems Package',
               MeasureIDs: ['Measure1', 'Measure2', 'Measure7', 'Measure8', 'Measure11', 'Measure13', 'Measure14', 'Measure18', 'Measure23', 'Measure24', 'Measure25', 'Measure27', 'Measure29']}

  packages << {ScenarioName: 'Office-Deep Package',
               MeasureIDs: ['Measure1', 'Measure2', 'Measure3', 'Measure6', 'Measure7', 'Measure8', 'Measure10', 'Measure13', 'Measure14', 'Measure15', 'Measure17', 'Measure18', 'Measure20', 'Measure23', 'Measure24', 'Measure27', 'Measure29']}
  
  # create unique measures for each package
  packages.each_index do |i|
    package = packages[i]
    this_measures = []
    package[:MeasureIDs].each do |measureID|
      measures.each do |measure|
        this_measures << measure if measure[:ID] == measureID
      end
    end
    
    #puts "Package: #{package[:ScenarioName]}"
    new_measure_ids = []
    this_measures.each do |this_measure|
      #puts "  #{this_measure[:MeasureName]}"
      new_measure = this_measure.clone
      new_measure_id = new_measure[:ID] + "_Package#{i}"
      new_measure_ids << new_measure_id
      new_measure[:ID] = new_measure_id
      new_measure[:LongDescription] = new_measure[:LongDescription] + " Package#{i}"
      new_measure[:SingleMeasure] = false
      new_measure[:ScenarioName] = package[:ScenarioName]
      measures << new_measure
    end
    package[:MeasureIDs] = new_measure_ids
  end
        
  source = '
  <auc:Audits xmlns:auc="http://nrel.gov/schemas/bedes-auc/2014" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://nrel.gov/schemas/bedes-auc/2014 https://github.com/BuildingSync/schema/releases/download/v0.3/BuildingSync.xsd">
	<auc:Audit>
		<auc:Sites>
		</auc:Sites>
    <auc:Measures>
'
  # add measures
  measures.each do |measure|
    source += "      <auc:Measure ID=\"#{measure[:ID]}\">
        <auc:SystemCategoryAffected>#{measure[:SystemCategoryAffected]}</auc:SystemCategoryAffected>
        <auc:PremisesAffected>
          <auc:PremiseAffected IDref=\"#{facility_id}\"/>
        </auc:PremisesAffected>
        <auc:TechnologyCategories>
          <auc:TechnologyCategory>
            <auc:#{measure[:TechnologyCategory]}>
              <auc:MeasureName>#{measure[:MeasureName]}</auc:MeasureName>
            </auc:#{measure[:TechnologyCategory]}>
          </auc:TechnologyCategory>
        </auc:TechnologyCategories>
        <auc:MeasureScaleOfApplication>Entire facility</auc:MeasureScaleOfApplication>
        <auc:LongDescription>#{measure[:LongDescription]}</auc:LongDescription>
        <auc:MVCost>0</auc:MVCost>
        <auc:UsefulLife>#{measure[:UsefulLife]}</auc:UsefulLife>
        <auc:MeasureTotalFirstCost>#{measure[:MeasureTotalFirstCost]}</auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost>0</auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost>0</auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
        <auc:UserDefinedFields>
          <auc:UserDefinedField>
            <auc:FieldName>OpenStudioMeasureName</auc:FieldName>
            <auc:FieldValue>#{measure[:OpenStudioMeasureName]}</auc:FieldValue>
          </auc:UserDefinedField>  
        </auc:UserDefinedFields>
      </auc:Measure>
"    
  end

  source += '   </auc:Measures>
    <auc:Report>
      <auc:Scenarios>
        <auc:Scenario ID="Baseline">
          <auc:ScenarioName>Baseline</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
  '
  # add single measures
  measures.each do |measure|
    
    # skip duplicate measures added for packages
    next if !measure[:SingleMeasure]
    
    source += "        <auc:Scenario>
          <auc:ScenarioName>#{measure[:ScenarioName]} Only</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref=\"Baseline\"/>
              <auc:MeasureIDs>
                <auc:MeasureID IDref=\"#{measure[:ID]}\"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
          <auc:LinkedPremises>
						<auc:Facility>
							<auc:LinkedFacilityID IDref=\"#{facility_id}\"/>
						</auc:Facility>
					</auc:LinkedPremises>
					<auc:UserDefinedFields>
						<auc:UserDefinedField>
							<auc:FieldName>Recommendation Category</auc:FieldName>
							<auc:FieldValue>Potential Capital Recommendations</auc:FieldValue>
						</auc:UserDefinedField>
					</auc:UserDefinedFields>
        </auc:Scenario>
"    
  end
  
   # add measure paackages
   packages.each do |package|
   
    measure_ids = []
    package[:MeasureIDs].each do |measure_id|
      measure_ids << "<auc:MeasureID IDref=\"#{measure_id}\"/>"
    end
    measure_ids = measure_ids.join("\n")
   
    source += "     <auc:Scenario>
         <auc:ScenarioName>#{package[:ScenarioName]}</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref=\"Baseline\"/>
              <auc:MeasureIDs>
                #{measure_ids}
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
          <auc:LinkedPremises>
						<auc:Facility>
							<auc:LinkedFacilityID IDref=\"#{facility_id}\"/>
						</auc:Facility>
					</auc:LinkedPremises>
					<auc:UserDefinedFields>
						<auc:UserDefinedField>
							<auc:FieldName>Recommendation Category</auc:FieldName>
							<auc:FieldValue>Potential Capital Recommendations</auc:FieldValue>
						</auc:UserDefinedField>
					</auc:UserDefinedFields>
        </auc:Scenario>"
   end

  source += '      </auc:Scenarios>
    </auc:Report>
  </auc:Audit>
</auc:Audits>
  '
  
  doc = REXML::Document.new(source)
  sites = doc.elements['*/*/auc:Sites']
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

  floor_area = get_floor_area(feature)
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
    template = "CBES Pre-1978"
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