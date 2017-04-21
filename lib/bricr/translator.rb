require "rexml/document"

require_relative "workflow_maker"

module BRICR
  class Translator
  
    # load the building sync file and chooses the correct workflow
    def initialize(path)
      @doc = nil
      @workflow_maker = nil
      
      # parse the xml
      raise "File '#{path}' does not exist" if !File.exists?(path)
      File.open(path, 'r') do |file|
        @doc = REXML::Document.new(file)
      end
      
      # validate the doc
      audits = []
      @doc.elements.each("auc:Audits/auc:Audit/") {|audit| audits << audit}
      raise "BuildingSync file must have exactly 1 audit" if audits.size != 1
      
      # choose the correct workflow maker based on xml
      chooseWorkflowMaker
    
    end
   
    
    def writeOSWs(dir)
      @workflow_maker.writeOSWs(dir)
    end
  
  private
  
    def chooseWorkflowMaker
      
      # for now there is only one workflow maker
      @workflow_maker = PhaseZeroWorkflowMaker.new(@doc)
      
    end
  
  end
end