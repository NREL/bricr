require 'json'
require 'rexml/document'

def create_site(feature)
  site = REXML::Element.new("auc:Site")
  
  # address
  address = REXML::Element.new("auc:Address")
  street_address_detail = REXML::Element.new("auc:StreetAddressDetail")
  simplified = REXML::Element.new("auc:Simplified") 
  street_address = REXML::Element.new("auc:StreetAddress") 
  street_address.text = "#{feature[:properties][:"From Street Number"]} #{feature[:properties][:"Street Name"]} #{feature[:properties][:"Street Name Post Type"]}"
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
  facility_classification.text = 'Commercial' # DLM need to map this
  facility.add_element(facility_classification)
  
  occupancy_classification = REXML::Element.new("auc:OccupancyClassification")
  occupancy_classification.text = feature[:properties][:"Occupancy Classification"] # DLM need to map this
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
  floor_area_value.text = feature[:properties][:"Gross Floor Area"]
  floor_area.add_element(floor_area_value)
  
  floor_areas.add_element(floor_area)
  facility.add_element(floor_areas)

  year_of_construction = REXML::Element.new("auc:YearOfConstruction")
  year_of_construction.text = feature[:properties][:"Completed Construction Status Date"]
  facility.add_element(year_of_construction)
  
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
	</auc:Audit>
</auc:Audits>
  )

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