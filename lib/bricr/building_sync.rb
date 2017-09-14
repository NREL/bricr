require 'fileutils'
require 'json'

module BRICR
  # accessor for building sync files
  class BuildingSync
    def initialize(doc)
    
      if doc.is_a?(REXML::Document)
        @doc = doc
      else
        # parse the xml
        raise "File '#{doc}' does not exist" unless File.exist?(doc)
        File.open(doc, 'r') do |file|
          @doc = REXML::Document.new(file)
        end
      end
    end
    
    # custom id is used to identify file in SEED
    def customId
      result = nil
      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility/auc:PremisesIdentifiers/auc:PremisesIdentifier') do |identifier|
        name = identifier.elements['auc:IdentifierCustomName']
        if name && name.text == "Custom ID"
          result = identifier.elements['auc:IdentifierValue'].text
          break
        end
      end
      return result
    end

    
  end
end
