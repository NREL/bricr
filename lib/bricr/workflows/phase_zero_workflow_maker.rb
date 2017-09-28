module BRICR
  # base class for objects that will configure workflows based on building sync files
  class PhaseZeroWorkflowMaker < WorkflowMaker
    def initialize(doc)
      super

      # load the workflow
      @workflow = nil

      # select base osw for standalone, small office, medium office
      base_osw = 'phase_zero_base.osw'

      workflow_path = File.join(File.dirname(__FILE__), base_osw)
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

      # phase 0 parameters
      # get the floor area
      floor_area = nil # square feet
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
      template = nil
      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility') do |facility_element|
        built_year = facility_element.elements['auc:YearOfConstruction'].text.to_f
        
        # SHL- select the template based on the major remodel year 
        if facility_element.elements['auc:YearOfLastMajorRemodel']
          major_remodel_year = facility_element.elements['auc:YearOfLastMajorRemodel'].text.to_f
          built_year = major_remodel_year if major_remodel_year > built_year
        end

        if built_year < 1978
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
          
      end

      bldg_type = nil
      bar_division_method = nil
      hot_water_per_occ_per_day_gal = nil
      
      num_stories_above_grade = nil
      num_stories_below_grade = nil
      ns_to_ew_ratio = nil
      
      building_rotation = nil # TBD
      floor_height = nil # TBD
      wwr = nil # TBD

      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility') do |facility_element|
        occupancy_type = facility_element.elements['auc:OccupancyClassification'].text
        if occupancy_type == 'Retail'
          bldg_type = 'RetailStandalone'
          bar_division_method = 'Multiple Space Types - Individual Stories Sliced'
          hot_water_per_occ_per_day_gal = 0.3 # hot water usage gallon per occupant per day
        elsif occupancy_type == 'Office'
          bar_division_method = 'Single Space Type - Core and Perimeter'
          hot_water_per_occ_per_day_gal = 1.0 # hot water usage gallon per occupant per day
          if floor_area > 0 && floor_area < 20000
            bldg_type = 'SmallOffice'
          elsif floor_area >= 20000 && floor_area < 75000
            bldg_type = 'MediumOffice'
          else
            raise "Office building size is beyond BRICR scope"
          end
        else
          raise "Building type is beyond BRICR scope"
        end
        
        if facility_element.elements['auc:FloorsAboveGrade']
          num_stories_above_grade = facility_element.elements['auc:FloorsAboveGrade'].text.to_f
        else
          num_stories_above_grade = 1.0 # setDefaultValue
        end
        
        if facility_element.elements['auc:FloorsBelowGrade']
          num_stories_below_grade = facility_element.elements['auc:FloorsBelowGrade'].text.to_f
        else 
          num_stories_below_grade = 0.0 # setDefaultValue
        end
        
        if facility_element.elements['auc:AspectRatio']
          ns_to_ew_ratio = facility_element.elements['auc:AspectRatio'].text.to_f
        else
          ns_to_ew_ratio = 0.0 # setDefaultValue
        end
        
        building_rotation = 0.0 # setDefaultValue
        floor_height = 0.0 # setDefaultValue in ft
        wwr = 0.0 # setDefaultValue in fraction
      end

      # set this value in the osw
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'total_bldg_floor_area', floor_area)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'template', template)
      set_measure_argument(osw, 'create_typical_building_from_model', 'template', template)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b', bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c', bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d', bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'floor_height', floor_height)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_above_grade', num_stories_above_grade)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_below_grade', num_stories_below_grade)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'building_rotation', building_rotation)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'ns_to_ew_ratio', ns_to_ew_ratio)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'wwr', wwr)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bar_division_method', bar_division_method)
      set_measure_argument(osw, 'AddServiceWaterHeating', 'hot_water_per_occ_per_day_gal', hot_water_per_occ_per_day_gal)
    end

    def configureForScenario(osw, scenario)
      measure_ids = []
      scenario.elements.each('auc:ScenarioType/auc:PackageOfMeasures/auc:MeasureIDs/auc:MeasureID') do |measure_id|
        measure_ids << measure_id.attributes['IDref']
      end

      measure_ids.each do |measure_id|
        @doc.elements.each("//auc:Measure[@ID='#{measure_id}']") do |measure|
          measure_category = measure.elements['auc:SystemCategoryAffected'].text
          if /Lighting/.match(measure_category)
            set_measure_argument(osw, 'SetLightingLoadsByLPD', '__SKIP__', false)
            set_measure_argument(osw, 'SetLightingLoadsByLPD', 'lpd', 0.6)
          end
          #if /Domestic Hot Water/.match(measure_category)
          #  set_measure_argument(osw, 'AddServiceWaterHeating', 'hot_water_per_occ_per_day_gal', 1)
          #  set_measure_argument(osw, 'SetWaterHeaterEfficiencyHeatLossandPeakWaterFlowRate', '__SKIP__', false)
          #  set_measure_argument(osw, 'SetWaterHeaterEfficiencyHeatLossandPeakWaterFlowRate', 'heater_thermal_efficiency', 0.9)
          #end
          #if /Electric Appliance/.match(measure_category)
          #  set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', '__SKIP__', false)
          #  set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', 'elecequip_power_reduction_percent', 30.0)
          #end
          #if /Infiltration/.match(measure_category)
          #  set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', '__SKIP__', false)
          #  set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', 'space_infiltration_reduction_percent', 30.0)
          #end
          #if /Heating System Efficiency/.match(measure_category)
          #  set_measure_argument(osw, 'SetGasBurnerEfficiency', '__SKIP__', false)
          #  set_measure_argument(osw, 'SetGasBurnerEfficiency', 'eff', 0.93)
          #end
          #if /Cooling System Efficiency/.match(measure_category)
          #  set_measure_argument(osw, 'SetCOPforSingleSpeedDXCoolingUnits', '__SKIP__', false)
          #  set_measure_argument(osw, 'SetCOPforSingleSpeedDXCoolingUnits', 'cop', 4.1)
          #end
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

        total_site_energy_savings = 0
        if baseline_total_site_energy && total_site_energy
          total_site_energy_savings = baseline_total_site_energy - total_site_energy
        end
        
        annual_savings_site_energy = REXML::Element.new('auc:AnnualSavingsSiteEnergy')
        annual_savings_site_energy.text = total_site_energy_savings
        package_of_measures.add_element(annual_savings_site_energy)
      end
    end
  end
end
