# usage: bundle exec ruby geojson_to_buildingsync.rb /path/to/geojson.json

require 'json'
require 'rexml/document'

if ARGV[0].nil? || !File.exists?(ARGV[0])
  puts "usage: bundle exec ruby geojson_to_buildingsync.rb /path/to/geojson.json"
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
  when "CIE"
    result = 'Commercial'    
  when "MED"
    result = 'Commercial'    
  when "MIPS"
    result = 'Commercial'
  when "MIXED"
    result = 'Mixed use commercial'
  when "MIXRES"
    result = 'Residential'
  when "OPENSPACE", "OpenSpace"
    result = 'Other'       
  when "PDR"
    result = 'Other'      
  when "RETAIL\/ENT"
    result = 'Commercial'
  when "RESIDENT"
    result = 'Residential'
  when "VISITOR"
    result = 'Commercial'    
  when "MISSING DATA"
    result = 'Other'    
  else
    throw "Unknown classification #{classification}"
  end
  
  return result
end

def get_occupancy_classification(feature)
  classification = feature[:properties][:"Occupancy Classification"]
  
  # https://data.sfgov.org/Housing-and-Buildings/Land-Use/us3s-fp9q/about 
  result = nil
  case classification
  when "CIE"
    result = 'Assembly-Cultural entertainment'  
  when "MED"
    result = 'Health care'    
  when "MIPS"
    result = 'Office'
  when "MIXED"
    result = 'Mixed-use commercial'
  when "MIXRES"
    result = 'Residential' 
  when "OPENSPACE", "OpenSpace"
    result = 'Other'
  when "PDR"
    result = 'Industrial'   
  when "RETAIL\/ENT"
    result = 'Retail'
  when "RESIDENT"
    result = 'Residential'
  when "VISITOR"
    result = 'Lodging'
  when "MISSING DATA"
    result = 'Unknown'        
  else
    throw "Unknown classification #{classification}"
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
    discriminant = 0.25*perimeter*perimeter-4*footprint_area
    if discriminant >= 0
      length = (0.5*perimeter + Math.sqrt(discriminant)) / 2.0
      #length = (0.5*perimeter - Math.sqrt(discriminant)) / 2.0
      width = footprint_area/length
      aspect = length/width
    end
  end
  
  return aspect
end

def create_site(feature)
  site = REXML::Element.new("auc:Site")
  
  # address
  address = REXML::Element.new("auc:Address")
  street_address_detail = REXML::Element.new("auc:StreetAddressDetail")
  simplified = REXML::Element.new("auc:Simplified") 
  street_address = REXML::Element.new("auc:StreetAddress") 
  # DLM: there is also a "To Street Number", check if these are equal
  street_number = feature[:properties][:"From Street Number"].to_s
  if street_number != feature[:properties][:"To Street Number"]
    street_number += " - #{feature[:properties][:"To Street Number"]}"
  end
  street_address.text = "#{street_number} #{feature[:properties][:"Street Name"]} #{feature[:properties][:"Street Name Post Type"]}"
  simplified.add_element(street_address)
  street_address_detail.add_element(simplified)
  address.add_element(street_address_detail)
  
  city = REXML::Element.new("auc:City") 
  city.text = 'San Francisco'
  address.add_element(city)
  
  state = REXML::Element.new("auc:State")
  state.text = 'CA'
  address.add_element(state)
  
  postal_code = REXML::Element.new("auc:PostalCode")
  postal_code.text = feature[:properties][:"ZIP Code"]
  address.add_element(postal_code)
  
  site.add_element(address)
  
  # climate zone
  # DLM: hard code for now
  climate_zone = REXML::Element.new("auc:ClimateZoneType")
  
  ashrae = REXML::Element.new("auc:ASHRAE")
  ashrae_climate = REXML::Element.new("auc:ClimateZone")
  ashrae_climate.text = '3C'
  ashrae.add_element(ashrae_climate)
  climate_zone.add_element(ashrae)
  
  title24 = REXML::Element.new("auc:CaliforniaTitle24")
  title24_climate = REXML::Element.new("auc:ClimateZone")
  title24_climate.text = 'Climate Zone 3'
  title24.add_element(title24_climate)
  climate_zone.add_element(title24)
  
  site.add_element(climate_zone)
  
  # weather file
  # DLM: hard code for now

  weather_data_station_id = REXML::Element.new("auc:WeatherDataStationID")
  weather_data_station_id.text = '724940'
  site.add_element(weather_data_station_id)
  
  weather_station_name = REXML::Element.new("auc:WeatherStationName")
  weather_station_name.text = 'USA_CA_San.Francisco.Intl.AP'
  site.add_element(weather_station_name)
  
  # longitude
  longitude = REXML::Element.new("auc:Longitude")
  longitude.text = feature[:geometry][:coordinates][0][0][0][0]
  site.add_element(longitude)
  
  # latitude
  latitude = REXML::Element.new("auc:Latitude")
  latitude.text = feature[:geometry][:coordinates][0][0][0][1]
  site.add_element(latitude)
  
  # facilities
  facilities = REXML::Element.new("auc:Facilities")
  facility = REXML::Element.new("auc:Facility")
  facility.attributes["ID"] = "Building#{feature[:properties][:"Building Identifier"]}"
  
  premises_name = REXML::Element.new("auc:PremisesName")
  premises_name.text = feature[:properties][:"Building Name"]
  facility.add_element(premises_name)

  premises_identifiers = REXML::Element.new("auc:PremisesIdentifiers")  
  premises_identifier = REXML::Element.new("auc:PremisesIdentifier")
  
  identifier_label = REXML::Element.new("auc:IdentifierLabel")
  identifier_label.text = 'Assessor parcel number'
  premises_identifier.add_element(identifier_label)
  
  identifier_value = REXML::Element.new("auc:IdentifierValue")
  identifier_value.text = feature[:properties][:"Assessor parcel number"]
  premises_identifier.add_element(identifier_value)
  
  premises_identifiers.add_element(premises_identifier)
  facility.add_element(premises_identifiers)
  
  facility_classification = REXML::Element.new("auc:FacilityClassification")
  facility_classification.text = get_facility_classification(feature)
  facility.add_element(facility_classification)
  
  occupancy_classification = REXML::Element.new("auc:OccupancyClassification")
  occupancy_classification.text = get_occupancy_classification(feature)
  facility.add_element(occupancy_classification)
  
  floors_above_grade = REXML::Element.new("auc:FloorsAboveGrade")
  floors_above_grade.text = feature[:properties][:"Number of Floors"] # DLM need to map this?
  facility.add_element(floors_above_grade)
  
  floors_below_grade = REXML::Element.new("auc:FloorsBelowGrade")
  floors_below_grade.text = 0 # DLM need to map this?
  facility.add_element(floors_below_grade)
  
  floor_areas = REXML::Element.new("auc:FloorAreas")
  
  floor_area = REXML::Element.new("auc:FloorArea")
  floor_area_type = REXML::Element.new("auc:FloorAreaType")
  floor_area_type.text = 'Gross'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new("auc:FloorAreaValue")
  floor_area_value.text = convert(feature[:properties][:"Gross Floor Area"], 'ft2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  floor_area = REXML::Element.new("auc:FloorArea")
  floor_area_type = REXML::Element.new("auc:FloorAreaType")
  floor_area_type.text = 'Footprint'
  floor_area.add_element(floor_area_type)
  floor_area_value = REXML::Element.new("auc:FloorAreaValue")
  floor_area_value.text = convert(feature[:properties][:"Building Footprint Floor Area"], 'm2', 'ft2')
  floor_area.add_element(floor_area_value)
  floor_areas.add_element(floor_area)
  
  facility.add_element(floor_areas)
  
  # aspect ratio and perimeter
  if ar = calculate_aspect_ratio(feature)
    aspect_ratio = REXML::Element.new("auc:AspectRatio")
    aspect_ratio.text = ar
    facility.add_element(aspect_ratio)
  end
  
  perimeter = REXML::Element.new("auc:Perimeter")
  perimeter.text = convert(feature[:properties][:"Building Perimeter"], 'm', 'ft').to_i # DLM: BS thinks this is an int
  facility.add_element(perimeter)
  
  # year of construction and modified
  year_of_construction = REXML::Element.new("auc:YearOfConstruction")
  year_of_construction.text = feature[:properties][:"Completed Construction Status Date"]
  facility.add_element(year_of_construction)
  
  if md = /^(\d\d\d\d).*/.match(feature[:properties][:"Last Modified Date"].to_s)
    year_of_last_major_remodel = REXML::Element.new("auc:YearOfLastMajorRemodel")
    year_of_last_major_remodel.text = md[1]
    facility.add_element(year_of_last_major_remodel)
  end
  
  facilities.add_element(facility)
  site.add_element(facilities)
  
  return site
end

def convert_feature(feature)
  source =  %q(
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
        <auc:MVCost>1000</auc:MVCost>
        <auc:MeasureTotalFirstCost>10000</auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost>8000</auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost>1000</auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
      </auc:Measure>
      <auc:Measure ID="Measure2">
        <auc:SystemCategoryAffected>Domestic Hot Water</auc:SystemCategoryAffected>
        <auc:PremisesAffected>
          <auc:PremiseAffected IDref="FACILITY_ID"/>
        </auc:PremisesAffected>
        <auc:TechnologyCategories>
          <auc:TechnologyCategory>
            <auc:ChilledWaterHotWaterAndSteamDistributionSystems>
              <auc:MeasureName>Replace or upgrade water heater</auc:MeasureName>
            </auc:ChilledWaterHotWaterAndSteamDistributionSystems>
          </auc:TechnologyCategory>
        </auc:TechnologyCategories>
        <auc:MeasureScaleOfApplication>Entire facility</auc:MeasureScaleOfApplication>
        <auc:MVCost>1000</auc:MVCost>
        <auc:MeasureTotalFirstCost>10000</auc:MeasureTotalFirstCost>
        <auc:MeasureInstallationCost>8000</auc:MeasureInstallationCost>
        <auc:MeasureMaterialCost>1000</auc:MeasureMaterialCost>
        <auc:Recommended>true</auc:Recommended>
        <auc:ImplementationStatus>Proposed</auc:ImplementationStatus>
      </auc:Measure>
    </auc:Measures>
    <auc:Report>
      <auc:Scenarios>
        <auc:Scenario>
          <auc:ScenarioName>Baseline</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:MeasureIDs>
                <auc:MeasureID/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Lighting Only</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure1"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Hot Water Only</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure2"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
        <auc:Scenario>
          <auc:ScenarioName>Max Tech</auc:ScenarioName>
          <auc:ScenarioType>
            <auc:PackageOfMeasures>
              <auc:MeasureIDs>
                <auc:MeasureID IDref="Measure1"/>
                <auc:MeasureID IDref="Measure2"/>
              </auc:MeasureIDs>
            </auc:PackageOfMeasures>
          </auc:ScenarioType>
        </auc:Scenario>
      </auc:Scenarios>
    </auc:Report>
	</auc:Audit>
</auc:Audits>
  )
  id = feature[:properties][:"Building Identifier"]
  source.gsub!('FACILITY_ID', "Building#{id}")

  doc = REXML::Document.new(source)
  sites =  doc.elements["*/*/auc:Sites"]
  site = create_site(feature)
  sites.add_element(site)
  
  return doc
end

geojson = nil
File.open(ARGV[0], 'r') do |file|
  geojson = JSON::parse(file.read, :symbolize_names => true)
end

outdir = "./bs_output"
FileUtils.mkdir_p(outdir) if !File.exists?(outdir)

geojson[:features].each do |feature|
  id = feature[:properties][:"Building Identifier"]
  puts "id = #{id}"
  doc = convert_feature(feature)
  
  filename = File.join(outdir, "#{id}.xml")
  File.open(filename, 'w') do |file|
    doc.write(file)
  end
  
end