module BRICR
  # base class for objects that will configure workflows based on building sync files
  class PhaseZeroWorkflowMaker < WorkflowMaker
    

    
    def initialize(doc)
      super

      # load the workflow
      @workflow = nil
      
      # select base osw for standalone, smalloffice, mediumoffice 
      occupancy_type = nil
      baseosw = nil
      floor_area_type = nil
      floor_area = nil
      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility') do |facility_element|
        occupancy_type = facility_element.elements['auc:OccupancyClassification'].text
        if occupancy_type == 'Retail'
          baseosw = "phase_zero_standaloneretail.osw"
        elsif occupancy_type == 'Office'
          floor_area_type = facility_element.elements['auc:FloorAreas/auc:FloorArea/auc:FloorAreaType'].text
          if floor_area_type == 'Gross'
            floor_area = facility_element.elements['auc:FloorAreas/auc:FloorArea/auc:FloorAreaValue'].text.to_f
            print floor_area
            if floor_area > 0 && floor_area < 20000
              baseosw = "phase_zero_smalloffice.osw"
            elsif floor_area >= 20000 && floor_area < 75000
              baseosw = "phase_zero_mediumoffice.osw"
            else
              raise "Office building size is beyond BRICR scope"
            end
          end
        else
          raise "Building type is beyond BRICR scope"
        end
      end
      
      
      workflow_path = File.join(File.dirname(__FILE__), baseosw)
      raise "File '#{workflow_path}' does not exist" unless File.exist?(workflow_path)

      File.open(workflow_path, 'r') do |file|
        @workflow = JSON.parse(file.read)
      end
      
      if BRICR::OPENSTUDIO_MEASURES
        @workflow['measure_paths'] = BRICR::OPENSTUDIO_MEASURES
      end

      if BRICR::OPENSTUDIO_FILES
        @workflow['file_paths'] = BRICR::OPENSTUDIO_FILES
      end

      # configure the workflow based on properties in the xml
      configureForDoc(@workflow)
    end

    def configureForDoc(osw)

      # get the floor area
      floor_area = nil
      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility/auc:FloorAreas/auc:FloorArea') do |floor_area_element|
        floor_area_type = floor_area_element.elements['auc:FloorAreaType'].text
        if floor_area_type == 'Gross'
		      # SHL- How about multiple space types?
		      floor_area = floor_area_element.elements['auc:FloorAreaValue'].text.to_f
		      # SHL-Check whether we get floor area or not.
		      if floor_area == nil
		        raise "Can not find the floor area"
		      end
        end
      end
      
      # SHL- get the template (vintage)
      built_year = nil
      major_remodel_year = nil
      template = nil
      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility') do |facility_element|
        built_year = facility_element.elements['auc:YearOfConstruction'].text.to_f
        if built_year < 1978
          # template = "90.1-2004"
          template = "CEC Pre-1978"
        elsif built_year >= 1978 && built_year < 1992
          template = "CEC T24 1978"
        elsif built_year >= 1992 && built_year < 2001
          template = "CEC T24 1992"
        elsif built_year >= 2001 && built_year < 2005
          template = "CEC T24 2001"
        elsif built_year >= 2005 && built_year < 2008
          template = "CEC T24 2005"
        else
          template = "CEC T24 2008"
        end
        
        major_remodel_year = facility_element.elements['auc:YearOfLastMajorRemodel'].text.to_f
        if major_remodel_year > built_year
          if built_year < 1978
            # template = "90.1-2004"
            template = "CEC Pre-1978"
          elsif major_remodel_year >= 1978 && major_remodel_year < 1992
            template = "CEC T24 1978"
          elsif major_remodel_year >= 1992 && major_remodel_year < 2001
            template = "CEC T24 1992"
          elsif major_remodel_year >= 2001 && major_remodel_year < 2005
            template = "CEC T24 2001"
          elsif major_remodel_year >= 2005 && major_remodel_year < 2008
            template = "CEC T24 2005"
          else
            template = "CEC T24 2008"
          end
        end
      
      end
      
      # set this value in the osw
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'total_bldg_floor_area', floor_area)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'template', template)
      set_measure_argument(osw, 'create_typical_building_from_model', 'template', template)
    end
	
    def configureForScenario(osw, scenario)
      measure_ids = []
      scenario.elements.each('auc:ScenarioType/auc:PackageOfMeasures/auc:MeasureIDs/auc:MeasureID') do |measure_id|
        measure_ids << measure_id.attributes['IDref']
      end

      measure_ids.each do |measure_id|
        @doc.elements.each("//auc:Measure[@ID='#{measure_id}']") do |measure|
          measure_category = measure.elements['auc:SystemCategoryAffected'].text
          if /Lighting Fixture/.match(measure_category)
            set_measure_argument(osw, 'ReduceLightingLoadsByPercentage', '__SKIP__', false)
          end
          if /Exterior Wall R-Value/.match(measure_category)
            set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWalls', '__SKIP__', false)
          end
          if /Roof R-Value/.match(measure_category)
            set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', '__SKIP__', false)
          end
          if /HVAC Efficiency/.match(measure_category)
            set_measure_argument(osw, 'AdjustSystemEfficiencies', '__SKIP__', false)
          end
        end
      end
    end

    def writeOSWs(dir)
      super

      # write an osw for each scenario
      @doc.elements.each('auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario') do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements['auc:ScenarioName'].text

        # deep clone
        osw = JSON.load(JSON.generate(@workflow))

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
          if step[:result] && step[:result][:step_values]
            step[:result][:step_values].each do |step_value|
              if step_value[:name] == result_name
                return step_value[:value]
              end
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
      @doc.elements.each('auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario') do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements['auc:ScenarioName'].text

        # dir for the osw
        osw_dir = File.join(dir, scenario_name)

        # find the osw
        path = File.join(osw_dir, 'out.osw')
        workflow = nil
        File.open(path, 'r') do |file|
          results[scenario_name] = JSON.parse(file.read, symbolize_names: true)
        end
      end

      @doc.elements.each('auc:Audits/auc:Audit/auc:Report/auc:Scenarios/auc:Scenario') do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements['auc:ScenarioName'].text
        package_of_measures = scenario.elements['auc:ScenarioType'].elements['auc:PackageOfMeasures']

        result = results[scenario_name]
        baseline = results['Baseline']

        total_site_energy = getMeasureResult(result, 'openstudio_results', 'total_site_energy')
        baseline_total_site_energy = getMeasureResult(baseline, 'openstudio_results', 'total_site_energy')

        total_site_energy_savings = baseline_total_site_energy - total_site_energy

        annual_savings_site_energy = REXML::Element.new('auc:AnnualSavingsSiteEnergy')
        annual_savings_site_energy.text = total_site_energy_savings
        package_of_measures.add_element(annual_savings_site_energy)
      end
    end
  end
end
