########################################################################################################################
#  BRICR, Copyright (c) 2019, Alliance for Sustainable Energy, LLC and The Regents of the University of California, through Lawrence 
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

# modify a seed generated bs file for audit template compatibility:
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

      # *TimeStamp -> *Timestamp:
      REXML::XPath.each(xml, "//auc:StartTimeStamp") do |e|
        e.name = "auc:StartTimestamp"
      end
      REXML::XPath.each(xml, "//auc:EndTimeStamp") do |e|
        e.name = "auc:EndTimestamp"
      end

      # insert new properties after 'Scenarios'
      xml_fields = ""
      building_id = nil
      if (REXML::XPath.first(xml, "//auc:LinkedPremisesOrSystem")).nil?
        REXML::XPath.match(xml, "//*[@IDref]").each do |e|
          if(!e.attributes["IDref"].match(/^Building*/).nil?)
            building_id = REXML::Attribute.class_eval(%q^%Q["#{e.attributes["IDref"]}"]^)
            break
          end
        end

        xml_fields = REXML::Text.new(             
          "<auc:LinkedPremisesOrSystem>
          <auc:Building>
          <auc:LinkedBuildingID IDref=#{building_id}/>
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
