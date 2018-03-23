# usage: bundle exec ruby geojson_to_buildingsync.rb /path/to/geojson.json

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
  site = REXML::Element.new('auc:Site')

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
  street_address.text = "#{street_number} #{feature[:properties][:"Street Name"]} #{feature[:properties][:"Street Name Post Type"]}"
  simplified.add_element(street_address)
  street_address_detail.add_element(simplified)
  address.add_element(street_address_detail)

  city = REXML::Element.new('auc:City')
  city.text = 'San Francisco'
  address.add_element(city)

  state = REXML::Element.new('auc:State')
  state.text = 'CA'
  address.add_element(state)

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
  longitude = REXML::Element.new('auc:Longitude')
  longitude.text = feature[:geometry][:coordinates][0][0][0][0]
  site.add_element(longitude)

  # latitude
  latitude = REXML::Element.new('auc:Latitude')
  latitude.text = feature[:geometry][:coordinates][0][0][0][1]
  site.add_element(latitude)

  # facilities
  facilities = REXML::Element.new('auc:Facilities')
  facility = REXML::Element.new('auc:Facility')
  facility.attributes['ID'] = "Building#{feature[:properties][:"Building Identifier"]}"

  premises_name = REXML::Element.new('auc:PremisesName')
  premises_name.text = feature[:properties][:"Building Name"]
  facility.add_element(premises_name)

  premises_identifiers = REXML::Element.new('auc:PremisesIdentifiers')
  
  premises_identifier = REXML::Element.new('auc:PremisesIdentifier')
  identifier_label = REXML::Element.new('auc:IdentifierLabel')
  identifier_label.text = 'Assessor parcel number'
  premises_identifier.add_element(identifier_label)
  identifier_value = REXML::Element.new('auc:IdentifierValue')
  identifier_value.text = feature[:properties][:"Assessor parcel number"]
  premises_identifier.add_element(identifier_value)
  premises_identifiers.add_element(premises_identifier)
  
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
  
  facility.add_element(premises_identifiers)

  facility_classification = REXML::Element.new('auc:FacilityClassification')
  facility_classification.text = get_facility_classification(feature)
  facility.add_element(facility_classification)

  occupancy_classification = REXML::Element.new('auc:OccupancyClassification')
  occupancy_classification.text = get_occupancy_classification(feature)
  facility.add_element(occupancy_classification)

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

  facilities.add_element(facility)
  site.add_element(facilities)

  return site
end

def convert_feature(feature)
  source = '
  <auc:Audits xmlns:auc="http://nrel.gov/schemas/bedes-auc/2014" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://nrel.gov/schemas/bedes-auc/2014 file:///E:/buildingsync/BuildingSync.xsd">
	<auc:Audit>
		<auc:Sites>
		</auc:Sites>
    <auc:Measures>
      <auc:Measure ID="Measure1">
        <auc:SystemCategoryAffected>Lighting</auc:SystemCategoryAffected>
        <auc:PremisesAffected>
          <auc:PremiseAffected IDref="FACILITY_ID"/>
        </auc:PremisesAffected>
        <auc:TechnologyCategories>
          <auc:TechnologyCategory>
            <auc:LightingImprovements>
              <auc:MeasureName>Retrofit with light emitting diode technologies</auc:MeasureName>
            </auc:LightingImprovements>
          </auc:TechnologyCategory>
        </auc:TechnologyCategories>
        <auc:MeasureScaleOfApplication>Entire facility</auc:MeasureScaleOfApplication>
        <auc:MVCost></auc:MVCost>
        <auc:MeasureTotalFirstCost></auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost></auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost></auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
      </auc:Measure>
      <auc:Measure ID="Measure2">
        <auc:SystemCategoryAffected>Plug Load</auc:SystemCategoryAffected>
        <auc:PremisesAffected>
          <auc:PremiseAffected IDref="FACILITY_ID"/>
        </auc:PremisesAffected>
        <auc:TechnologyCategories>
          <auc:TechnologyCategory>
            <auc:PlugLoadReductions>
              <auc:MeasureName>Replace with ENERGY STAR rated</auc:MeasureName>
            </auc:PlugLoadReductions>
          </auc:TechnologyCategory>
        </auc:TechnologyCategories>
        <auc:MeasureScaleOfApplication>Entire facility</auc:MeasureScaleOfApplication>
        <auc:MVCost></auc:MVCost>
        <auc:MeasureTotalFirstCost></auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost></auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost></auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
      </auc:Measure>
      <auc:Measure ID="Measure3">
        <auc:SystemCategoryAffected>Wall</auc:SystemCategoryAffected>
        <auc:PremisesAffected>
          <auc:PremiseAffected IDref="FACILITY_ID"/>
        </auc:PremisesAffected>
        <auc:TechnologyCategories>
          <auc:TechnologyCategory>
            <auc:BuildingEnvelopeModifications>
              <auc:MeasureName>Air seal envelope</auc:MeasureName>
            </auc:BuildingEnvelopeModifications>
          </auc:TechnologyCategory>
        </auc:TechnologyCategories>
        <auc:MeasureScaleOfApplication>Entire facility</auc:MeasureScaleOfApplication>
        <auc:MVCost></auc:MVCost>
        <auc:MeasureTotalFirstCost></auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost></auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost></auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
      </auc:Measure>
      <auc:Measure ID="Measure4">
        <auc:SystemCategoryAffected>Cooling System</auc:SystemCategoryAffected>
        <auc:PremisesAffected>
          <auc:PremiseAffected IDref="FACILITY_ID"/>
        </auc:PremisesAffected>
        <auc:TechnologyCategories>
          <auc:TechnologyCategory>
            <auc:OtherHVAC>
              <auc:MeasureName>Replace package units</auc:MeasureName>
            </auc:OtherHVAC>
          </auc:TechnologyCategory>
        </auc:TechnologyCategories>
        <auc:MeasureScaleOfApplication>Entire facility</auc:MeasureScaleOfApplication>
        <auc:MVCost></auc:MVCost>
        <auc:MeasureTotalFirstCost></auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost></auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost></auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
      </auc:Measure>
      <auc:Measure ID="Measure5">
        <auc:SystemCategoryAffected>Heating System</auc:SystemCategoryAffected>
        <auc:PremisesAffected>
          <auc:PremiseAffected IDref="FACILITY_ID"/>
        </auc:PremisesAffected>
        <auc:TechnologyCategories>
          <auc:TechnologyCategory>
            <auc:OtherHVAC>
              <auc:MeasureName>Replace burner</auc:MeasureName>
            </auc:OtherHVAC>
          </auc:TechnologyCategory>
        </auc:TechnologyCategories>
        <auc:MeasureScaleOfApplication>Entire facility</auc:MeasureScaleOfApplication>
        <auc:MVCost></auc:MVCost>
        <auc:MeasureTotalFirstCost></auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost></auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost>1000</auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
      </auc:Measure>
    </auc:Measures>
    <auc:Report>
      <auc:Scenarios>
        <auc:Scenario ID="Baseline">
          <auc:ScenarioName>Baseline</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
              <auc:MeasureIDs>
                <auc:MeasureID/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>LED</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure1"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Electric_Appliance_30%_Reduction</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure2"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Air_Seal_Infiltration_30%_More_Airtight</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure3"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Cooling_System_SEER 14</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure4"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Heating_System_Efficiency_0.93</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure5"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Max_Tech</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:ReferenceCase IDref="Baseline"/>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure1"/>
                <auc:MeasureID IDref="Measure2"/>
                <auc:MeasureID IDref="Measure3"/>
                <auc:MeasureID IDref="Measure4"/>
                <auc:MeasureID IDref="Measure5"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
      </auc:Scenarios>
    </auc:Report>
  </auc:Audit>
</auc:Audits>
  '
  id = feature[:properties][:"Building Identifier"]
  source.gsub!('FACILITY_ID', "Building#{id}")

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
  rescue
    puts "Building #{id} not converted"
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
    template = "CEC T24 1978"
  elsif year_built >= 1992 && year_built < 2001
    template = "CEC T24 1992"
  elsif year_built >= 2001 && year_built < 2005
    template = "CEC T24 2001"
  elsif year_built >= 2005 && year_built < 2008
    template = "CEC T24 2005"
  else
    template = "CEC T24 2008"
  end

  # source factor: 1.05 for gas, 3.14 for electricity
  if site_eui != nil and source_eui != nil
    ele_eui = (source_eui - site_eui * 1.05)/(3.14-1.05)
    gas_eui = site_eui - ele_eui
  end

  summary_file.puts "#{id},#{id}.xml,1,#{building_type},#{floor_area},#{year_built},#{template},#{site_eui},#{source_eui},#{ele_eui},#{gas_eui},#{year_eui}"
end

summary_file.close