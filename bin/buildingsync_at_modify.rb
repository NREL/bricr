require 'rexml/document'
require 'parallel'

def add_sibling(xml, elements)
  root_element = REXML::XPath.first(xml, elements.first)
  elements.drop(1).each do |e|
    sibling_element = REXML::XPath.first(xml, e)
    root_element.next_sibling = sibling_element
    root_element = root_element.next_sibling
  end
end

# modify a generated bs file:
def modify_existing_bs_file()

  num_total = 0
  num_bsync = 0
  num_skip = 0

  if(File.exist?(ARGV[0]))
    Parallel.each(Dir.glob(File.join(ARGV[0], "*.xml")), in_threads: 3) do |file|
      puts File.basename(file)

      xml = REXML::Document.new File.new(file)
      if(xml.root.attributes["schemaLocation"] == 'http://buildingsync.net/schemas/bedes-auc/2019 https://raw.githubusercontent.com/BuildingSync/schema/1c73127d389b779c6b74029be72c6e9ff3187113/BuildingSync.xsd')

        xml_elements = ["//auc:PremisesIdentifiers",
                        "//auc:Address",
                        "//auc:ClimateZoneType",
                        "//auc:WeatherDataStationID",
                        "//auc:WeatherStationName",
                        "//auc:Longitude",
                        "//auc:Latitude",
                        "//auc:Ownership"]
        add_sibling(xml, xml_elements)

        # Remove all start and end timestamp. Standard xml for JSON
        REXML::XPath.each(xml, "//auc:StartTimeStamp") do |e|
          e.name = "auc:StartTimestamp"
        end
        REXML::XPath.each(xml, "//auc:EndTimeStamp") do |e|
          e.name = "auc:EndTimestamp"
        end

        # insert new properties before </auc:Report>
        xml_fields = ""
        building_id = nil
        if (REXML::XPath.first(xml, "//auc:LinkedPremisesOrSystem")).nil?
          REXML::XPath.match(xml, "//*[@IDref]").each do |e|
            if(!e.attributes["IDref"].match(/^Building*/).nil?)
              building_id = e.attributes["IDref"]
              break
            end
          end

          xml_fields = REXML::Text.new(             
            "<auc:LinkedPremisesOrSystem>
            <auc:Building>
            <auc:LinkedBuildingID IDref='#{building_id}'/>
            </auc:Building>
          </auc:LinkedPremisesOrSystem>
          <auc:UserDefinedFields>
            <auc:UserDefinedField>
              <auc:FieldName>Audit Template Report Type</auc:FieldName>
              <auc:FieldValue>San Francisco Report</auc:FieldValue>
            </auc:UserDefinedField>
          </auc:UserDefinedFields>")
        end
        REXML::XPath.first(xml, "//auc:Report").add_text(xml_fields.value)

        xml.context[:attribute_quote] = :quote
        xml.write(File.open(file, 'w'))

        num_bsync += 1
      else
        num_skip += 1
      end
      num_total += 1
    end
  end
  puts "Total #{num_total} files, processed #{num_bsync}, skipped #{num_skip} due to outdated schema."
  puts "Seed BSync files modification for Audit Template tool completed."
  return
end

modify_existing_bs_file()