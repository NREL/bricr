require 'rexml/document'
require 'tempfile'

# return line index of element
def line_index(file, list)
  tag = Hash.new

  # find line number of <auc:Address> and </auc:Ownership>
  File.foreach(file).with_index(1) do |line, index|
    (0...list.size).each do |i|
      if line.include?list[i]
        tag[list[i]] = index
      end
    end
  end
  return tag
end

# modify a generated bs file:
def modify_existing_bs_file()

  outdir = './bs_output/'
  if(File.exist?(outdir))
    Dir.glob(File.join(outdir, "*.xml")).each do |file|
      puts file
      content = ""
      
      xml = REXML::Document.new File.new(file)
      xml_addr = REXML::XPath.first(xml, "//auc:Address")
      xml_czt = REXML::XPath.first(xml, "//auc:ClimateZoneType")
      xml_wdsId = REXML::XPath.first(xml, "//auc:WeatherDataStationID")
      xml_wsn = REXML::XPath.first(xml, "//auc:WeatherStationName")
      xml_long = REXML::XPath.first(xml, "//auc:Longitude")
      xml_lat = REXML::XPath.first(xml, "//auc:Latitude")
      xml_owner = REXML::XPath.first(xml, "//auc:Ownership")
      xml_pid = REXML::XPath.first(xml, "//auc:PremisesIdentifiers")

      xml_pid.next_sibling = xml_addr
      xml_addr = REXML::XPath.first(xml, "//auc:Address")
      xml_addr.next_sibling = xml_czt
      xml_czt = REXML::XPath.first(xml, "//auc:ClimateZoneType")
      xml_czt.next_sibling = xml_wdsId
      xml_wdsId = REXML::XPath.first(xml, "//auc:WeatherDataStationID")
      xml_wdsId.next_sibling = xml_wsn
      xml_wsn = REXML::XPath.first(xml, "//auc:WeatherStationName")
      xml_wsn.next_sibling = xml_long
      xml_long = REXML::XPath.first(xml, "//auc:Longitude")
      xml_long.next_sibling = xml_lat
      xml_lat = REXML::XPath.first(xml, "//auc:Latitude")
      xml_lat.next_sibling = xml_owner
      xml.write(File.open(file, 'w'))

      # Remove all start and end timestamp. Standard xml for JSON
      REXML::XPath.each(xml, "//auc:StartTimeStamp") do |e|
        e.name = "auc:StartTimestamp"
      end
      REXML::XPath.each(xml, "//auc:EndTimeStamp") do |e|
        e.name = "auc:EndTimestamp"
      end
      xml.context[:attribute_quote] = :quote
      xml.write(File.open(file, "w"))

      # insert new properties before </auc:Report>
      xml_fields = ""
      if (REXML::XPath.first(xml, "//auc:LinkedPremisesOrSystem")).nil?
        building_id = REXML::XPath.first(xml, "//auc:LinkedBuildingID").attributes["IDref"]
        xml_fields = REXML::CData.new("<auc:LinkedPremisesOrSystem>
            <auc:Building>
            <auc:LinkedBuildingID IDref='#{building_id}'/>
            </auc:Building>
          </auc:LinkedPremisesOrSystem>
          <auc:UserDefinedFields>
            <auc:UserDefinedField>
              <auc:FieldName>Audit Template Report Type</auc:FieldName>
              <auc:FieldValue>San Francisco Report</auc:FieldValue>
            </auc:UserDefinedField>
          </auc:UserDefinedFields>", raw = "true")
      end
      xml.write(File.open(file, 'w'))
      REXML::XPath.first(xml, "//auc:Report").add_text(xml_fields.value)
      xml.write(File.open(file, 'w'))
    end
  end

  return
  
end

modify_existing_bs_file()