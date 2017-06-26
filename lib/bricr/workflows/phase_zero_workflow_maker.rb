module BRICR
  # base class for objects that will configure workflows based on building sync files
  class PhaseZeroWorkflowMaker < WorkflowMaker
  
    def initialize(doc)
      super
      
      # load the workflow
      @workflow = nil
      
      workflow_path = File.join(File.dirname(__FILE__), '/phase_zero.osw')
      raise "File '#{workflow_path}' does not exist" if !File.exists?(workflow_path)
      
      File.open(workflow_path, 'r') do |file|
        @workflow = JSON::parse(file.read)
      end      
      
      if BRICR::OPENSTUDIO_MEASURES
        @workflow["measure_paths"] = BRICR::OPENSTUDIO_MEASURES
      end
      
      if BRICR::OPENSTUDIO_FILES
        @workflow["file_paths"] = BRICR::OPENSTUDIO_FILES
      end
  
      # configure the workflow based on properties in the xml
      configureForDoc(@workflow)
    end
  
    def configureForDoc(osw)
      # get the floor area
      floor_area = nil
      @doc.elements.each("/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility/auc:FloorAreas/auc:FloorArea") do |floor_area_element|
        floor_area_type = floor_area_element.elements["auc:FloorAreaType"].text
        if (floor_area_type == "Gross")
          floor_area = floor_area_element.elements["auc:FloorAreaValue"].text.to_f
        end
      end
      
      # set this value in the osw
      set_measure_argument(osw, "create_bar_from_building_type_ratios", "total_bldg_floor_area", floor_area)
      
    end
        
    def configureForScenario(osw, scenario)
      measure_ids = []
      scenario.elements.each("auc:ScenarioType/auc:PackageOfMeasures/auc:MeasureIDs/auc:MeasureID") do |measure_id|
        measure_ids << measure_id.attributes["IDref"]
      end
      
      measure_ids.each do |measure_id|
        @doc.elements.each("//auc:Measure[@ID='#{measure_id}']") do |measure|
          measure_category = measure.elements["auc:SystemCategoryAffected"].text
          if /Lighting/.match(measure_category)
            set_measure_argument(osw, "AedgK12InteriorLightingControls", "__SKIP__", false)
          end
        end
      end
    end
    
    def writeOSWs(dir)
      super

      # write an osw for each scenario
      @doc.elements.each("auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario") do |scenario|
      
        # get information about the scenario
        scenario_name = scenario.elements["auc:ScenarioName"].text

        # deep clone
        osw = JSON::load(JSON.generate(@workflow))
        
        # configure the workflow based on measures in this scenario
        configureForScenario(osw, scenario)
        
        # dir for the osw
        osw_dir = File.join(dir, scenario_name)
        FileUtils.mkdir_p(osw_dir)
        
        # write the osw
        path = File.join(osw_dir, 'in.osw')
        File.open(path, 'w') do |file|
          file << JSON.generate(osw)
        end
      end

    end
    
    def getMeasureResult(result, measure_dir_name, result_name)
      result[:steps].each do |step|
        if step[:measure_dir_name] == measure_dir_name
          puts "found step"
          step[:result][:step_values].each do |step_value|
            if step_value[:name] == result_name
              puts "found value"
              return step_value[:value]
            end
          end
        end
      end
      
      return nil
    end
    
    def gatherResults(dir)
      super
      
      results = {}

      # write an osw for each scenario
      @doc.elements.each("auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario") do |scenario|
      
        # get information about the scenario
        scenario_name = scenario.elements["auc:ScenarioName"].text
        
        # dir for the osw
        osw_dir = File.join(dir, scenario_name)
        
        # find the osw
        path = File.join(osw_dir, 'out.osw')
        workflow = nil
        File.open(path, 'r') do |file|
          results[scenario_name] = JSON::parse(file.read, :symbolize_names=>true)
        end
      end

      @doc.elements.each("auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario") do |scenario|
      
        # get information about the scenario
        scenario_name = scenario.elements["auc:ScenarioName"].text
        package_of_measures = scenario.elements["auc:ScenarioType"].elements["auc:PackageOfMeasures"]
         
        result = results[scenario_name]
        baseline = results["Baseline"]
         
        total_site_energy = getMeasureResult(result, 'openstudio_results', 'total_site_energy')
        baseline_total_site_energy = getMeasureResult(baseline, 'openstudio_results', 'total_site_energy')
        
        total_site_energy_savings = baseline_total_site_energy - total_site_energy

        annual_savings_site_energy = REXML::Element.new("auc:AnnualSavingsSiteEnergy")
        annual_savings_site_energy.text = total_site_energy_savings
        package_of_measures.add_element(annual_savings_site_energy)
      end
    
    end
    
  end
end