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
      $bricr_template = nil
      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility') do |facility_element|
        built_year = facility_element.elements['auc:YearOfConstruction'].text.to_f
        
        if facility_element.elements['auc:YearOfLastMajorRemodel']
          major_remodel_year = facility_element.elements['auc:YearOfLastMajorRemodel'].text.to_f
          built_year = major_remodel_year if major_remodel_year > built_year
        end

        if built_year < 1978
          $bricr_template = "CEC Pre-1978"
        elsif built_year >= 1978 && built_year < 1992
          $bricr_template = "CEC T24 1978"
        elsif built_year >= 1992 && built_year < 2001
          $bricr_template = "CEC T24 1992"
        elsif built_year >= 2001 && built_year < 2005
          $bricr_template = "CEC T24 2001"
        elsif built_year >= 2005 && built_year < 2008
          $bricr_template = "CEC T24 2005"
        else
          $bricr_template = "CEC T24 2008"
        end
		
		#$bricr_template = "90.1-2004"

      end

      # For measure: create_bar_from_building_type_ratios 
	  $bricr_bldg_type = nil
	  bar_division_method = nil
	  num_stories_above_grade = nil
      num_stories_below_grade = nil
      ns_to_ew_ratio = nil
      building_rotation = nil # TBD
      floor_height = nil # TBD
      wwr = nil # TBD
	  # For measure: create_typical_building_from_model
	  $bricr_system_type = nil

      @doc.elements.each('/auc:Audits/auc:Audit/auc:Sites/auc:Site/auc:Facilities/auc:Facility') do |facility_element|
        $bricr_occupancy_type = facility_element.elements['auc:OccupancyClassification'].text
        if $bricr_occupancy_type == 'Retail'
          $bricr_bldg_type = 'RetailStandalone'
          bar_division_method = 'Multiple Space Types - Individual Stories Sliced'
		  $bricr_system_type = 'PSZ-AC with gas coil heat'
        elsif $bricr_occupancy_type == 'Office'
          bar_division_method = 'Single Space Type - Core and Perimeter'
          if floor_area > 0 && floor_area < 20000
            $bricr_bldg_type = 'SmallOffice'
			$bricr_system_type = 'PSZ-AC with gas coil heat'
          elsif floor_area >= 20000 && floor_area < 75000
            $bricr_bldg_type = 'MediumOffice'
			$bricr_system_type = 'PVAV with reheat'
          else
            raise "Office building size is beyond BRICR scope"
          end
        else
          raise "Building type is beyond BRICR scope"
        end
		
		if facility_element.elements['auc:FloorsAboveGrade']
          num_stories_above_grade = facility_element.elements['auc:FloorsAboveGrade'].text.to_f
        end
        if num_stories_above_grade == 0.0
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
      # For measure: create_bar_from_building_type_ratios 
	  set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'total_bldg_floor_area', floor_area)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'template', $bricr_template)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_a', $bricr_bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_b', $bricr_bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_c', $bricr_bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bldg_type_d', $bricr_bldg_type)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'floor_height', floor_height)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_above_grade', num_stories_above_grade)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'num_stories_below_grade', num_stories_below_grade)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'building_rotation', building_rotation)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'ns_to_ew_ratio', ns_to_ew_ratio)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'wwr', wwr)
      set_measure_argument(osw, 'create_bar_from_building_type_ratios', 'bar_division_method', bar_division_method)
      # For measure: create_typical_building_from_model
	  set_measure_argument(osw, 'create_typical_building_from_model', 'template', $bricr_template)
	  set_measure_argument(osw, 'create_typical_building_from_model', 'system_type', $bricr_system_type)
	  # Calibration
	  set_measure_argument(osw, 'calibrate_baseline_model', 'template', $bricr_template)
      set_measure_argument(osw, 'calibrate_baseline_model', 'bldg_type', $bricr_bldg_type)
      if defined?(BRICR::DO_MODEL_CALIBRATION) and BRICR::DO_MODEL_CALIBRATION
        set_measure_argument(osw, 'calibrate_baseline_model', '__SKIP__', false)
      end
    end

    def configureForScenario(osw, scenario)
      measure_ids = []
      scenario.elements.each('auc:ScenarioType/auc:PackageOfMeasures/auc:MeasureIDs/auc:MeasureID') do |measure_id|
        measure_ids << measure_id.attributes['IDref']
      end

	  measure_ids.each do |measure_id|
        @doc.elements.each("//auc:Measure[@ID='#{measure_id}']") do |measure|
          measure_category = measure.elements['auc:SystemCategoryAffected'].text
		  
          # Lighting
		  if measure_category == "Lighting" 
			# Lighting / LightingImprovements
			lighting_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:LightingImprovements/auc:MeasureName'].text	
			# Lighting / LightingImprovements / Retrofit with light emitting diode technologies
			if lighting_measure_name == "Retrofit with light emitting diode technologies"
				set_measure_argument(osw, 'SetLightingLoadsByLPD', '__SKIP__', false)
				set_measure_argument(osw, 'SetLightingLoadsByLPD', 'lpd', 0.6)
			end
			# Lighting / LightingImprovements / Add daylight controls
			if lighting_measure_name == "Add daylight controls"
				set_measure_argument(osw, 'AddDaylightSensors', '__SKIP__', false)
				if $bricr_bldg_type == "SmallOffice"
					set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Office WholeBuilding - Sm Office - #{$bricr_template}")
				elsif $bricr_bldg_type == "MediumOffice"
					set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Office WholeBuilding - Md Office - #{$bricr_template}")
				elsif $bricr_bldg_type == "RetailStandalone"
					set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Retail Retail - #{$bricr_template}")
				end
			end
          end
          
		  # Plug Load
		  if measure_category == "Plug Load"
			# Plug Load / PlugLoadReductions
			plugload_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:PlugLoadReductions/auc:MeasureName'].text	
			# Plug Load / PlugLoadReductions / Replace with ENERGY STAR rated
			if plugload_measure_name == "Replace with ENERGY STAR rated"
				set_measure_argument(osw, 'tenant_star_internal_loads', '__SKIP__', false)
				set_measure_argument(osw, 'tenant_star_internal_loads', 'epd', 0.6) # W/ft^2
			end
			# Plug Load / PlugLoadReductions / Install plug load controls
			if plugload_measure_name == "Install plug load controls"
				set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', 'elecequip_power_reduction_percent', 20.0)
			end
          end
          
		  # Wall
		  if measure_category == "Wall"
			# Wall / BuildingEnvelopeModifications
			wall_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BuildingEnvelopeModifications/auc:MeasureName'].text
			# Wall / BuildingEnvelopeModifications / Air seal envelope
			if  wall_measure_name == "Air seal envelope"
				set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', 'space_infiltration_reduction_percent', 30.0)
			end
			# Wall / BuildingEnvelopeModifications / Increase wall insulation
			if  wall_measure_name == "Increase wall insulation"
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWalls', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWalls', 'r_value', 25) # R-value
			end
			# Wall / BuildingEnvelopeModifications / Insulate thermal bypasses
			if  wall_measure_name == "Insulate thermal bypasses"
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWallsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWallsByPercentage', 'r_value', 20) # R-value increase percentage
			end
		  end
		  
		  # Roof / Ceiling
		  if measure_category == "Roof / Ceiling"
			# Roof / Ceiling / BuildingEnvelopeModifications
			roof_ceiling_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BuildingEnvelopeModifications/auc:MeasureName'].text
			# Roof / Ceiling / BuildingEnvelopeModifications / Increase roof insulation
			if  roof_ceiling_measure_name == "Increase roof insulation"
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', 'r_value', 30) # R-value
			end
			# Roof / Ceiling / BuildingEnvelopeModifications / Increase ceiling insulation
			if  roof_ceiling_measure_name == "Increase ceiling insulation"
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofsByPercentage', 'r_value', 20) # R-value increase percentage
			end
		  end
          
		  # Heating System
		  if measure_category == "Heating System"
			# Heating System / OtherHVAC
			heatingsystem_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text		
			# Heating System / OtherHVAC / Replace burner
			if heatingsystem_measure_name == "Replace burner"
				# furnace system
				if $bricr_system_type == "PSZ-AC with gas coil heat"
					set_measure_argument(osw, 'SetGasBurnerEfficiency', '__SKIP__', false)
					set_measure_argument(osw, 'SetGasBurnerEfficiency', 'eff', 0.93)
				end
			end
			# Heating System / BoilerPlantImprovements
			heatingsystem_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BoilerPlantImprovements/auc:MeasureName'].text	
			# Heating System / BoilerPlantImprovements / Replace boiler
			if heatingsystem_measure_name == "Replace boiler"
				# Boiler system for medium office
				if $bricr_system_type == "PVAV with reheat"
					set_measure_argument(osw, 'set_boiler_thermal_efficiency', '__SKIP__', false)
					set_measure_argument(osw, 'set_boiler_thermal_efficiency', 'input_option_manual', true)
					set_measure_argument(osw, 'set_boiler_thermal_efficiency', 'boiler_thermal_efficiency', 0.93)
				end
			end
          end
          
		  # Cooling System
		  if measure_category == "Cooling System"
			# Cooling System / OtherHVAC
			coolingsystem_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
		    # Cooling System / OtherHVAC / Replace package units
			if coolingsystem_measure_name == "Replace package units"
				if $bricr_system_type == "PSZ-AC with gas coil heat"
					set_measure_argument(osw, 'SetCOPforSingleSpeedDXCoolingUnits', '__SKIP__', false)
					set_measure_argument(osw, 'SetCOPforSingleSpeedDXCoolingUnits', 'cop', 4.1)
				elsif $bricr_system_type == "PVAV with reheat"
					set_measure_argument(osw, 'SetCOPforTwoSpeedDXCoolingUnits', '__SKIP__', false)
					set_measure_argument(osw, 'SetCOPforTwoSpeedDXCoolingUnits', 'cop_high', 4.1)
					set_measure_argument(osw, 'SetCOPforTwoSpeedDXCoolingUnits', 'cop_low', 4.1)
				end
			end
		  end
			
		  # Other HVAC
		  if measure_category == "Other HVAC"
			# Other HVAC / OtherHVAC
			otherhvac_measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
			# Other HVAC / OtherHVAC / Replace HVAC system type to VRF 
			if otherhvac_measure_name == "Replace HVAC system type to VRF"
				set_measure_argument(osw, 'vr_fwith_doas', '__SKIP__', false)
				if $bricr_bldg_type == "SmallOffice"
					set_measure_argument(osw, 'vr_fwith_doas', "Office WholeBuilding - Sm Office - #{$bricr_template}", true)
				elsif $bricr_bldg_type == "MediumOffice"
					set_measure_argument(osw, 'vr_fwith_doas', "Office WholeBuilding - Md Office - #{$bricr_template}", true)
				elsif $bricr_bldg_type == "RetailStandalone"
					set_measure_argument(osw, 'vr_fwith_doas', "Retail Retail - #{$bricr_template}", true)
					set_measure_argument(osw, 'vr_fwith_doas', "Retail Point_of_Sale - #{$bricr_template}", true)
					set_measure_argument(osw, 'vr_fwith_doas', "Retail Entry - #{$bricr_template}", true)
					set_measure_argument(osw, 'vr_fwith_doas', "Retail Back_Space - #{$bricr_template}", true)
				end
			end
			# Other HVAC / OtherHVAC / Replace HVAC with GSHP and DOAS 
			if otherhvac_measure_name == "Replace HVAC with GSHP and DOAS"
				set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', '__SKIP__', false)
				if $bricr_bldg_type == "SmallOffice"
					set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Office WholeBuilding - Sm Office - #{$bricr_template}", true)
				elsif $bricr_bldg_type == "MediumOffice"
					set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Office WholeBuilding - Md Office - #{$bricr_template}", true)
				elsif $bricr_bldg_type == "RetailStandalone"
					set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Retail - #{$bricr_template}", true)
					set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Point_of_Sale - #{$bricr_template}", true)
					set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Entry - #{$bricr_template}", true)
					set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Back_Space - #{$bricr_template}", true)
				end
			end
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
        next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

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
        next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

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
        next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

        package_of_measures = scenario.elements['auc:ScenarioType'].elements['auc:PackageOfMeasures']

        result = results[scenario_name]
        baseline = results['Baseline']

        # Check out.osw "openstudio_results" for output variables
		    total_site_energy = getMeasureResult(result, 'openstudio_results', 'total_site_energy') # in kBtu
        baseline_total_site_energy = getMeasureResult(baseline, 'openstudio_results', 'total_site_energy') # in kBtu
        fuel_electricity = getMeasureResult(result, 'openstudio_results', 'fuel_electricity') # in kBtu
        fuel_natural_gas = getMeasureResult(result, 'openstudio_results', 'fuel_natural_gas') # in kBtu
        annual_utility_cost = getMeasureResult(result, 'openstudio_results', 'annual_utility_cost') # in $
        baseline_annual_utility_cost = getMeasureResult(baseline, 'openstudio_results', 'annual_utility_cost') # in $
		

        total_site_energy_savings = 0
		    total_energy_cost_savings = 0
        if baseline_total_site_energy && total_site_energy
          total_site_energy_savings = baseline_total_site_energy - total_site_energy
		      total_energy_cost_savings = baseline_annual_utility_cost - annual_utility_cost
        end
        
        annual_savings_site_energy = REXML::Element.new('auc:AnnualSavingsSiteEnergy')
		    annual_site_energy = REXML::Element.new('auc:AnnualSiteEnergy')
        annual_electricity = REXML::Element.new('auc:AnnualElectricity')
        annual_natural_gas = REXML::Element.new('auc:AnnualNaturalGas')
        annual_savings_energy_cost = REXML::Element.new('auc:AnnualSavingsEnergyCost')

        annual_savings_site_energy.text = total_site_energy_savings
        annual_site_energy.text = total_site_energy
        annual_electricity.text = fuel_electricity
        annual_natural_gas.text = fuel_natural_gas
        annual_savings_energy_cost.text = total_energy_cost_savings

        package_of_measures.add_element(annual_savings_site_energy)
        package_of_measures.add_element(annual_site_energy)
        package_of_measures.add_element(annual_electricity)
        package_of_measures.add_element(annual_natural_gas)
        package_of_measures.add_element(annual_savings_energy_cost)
      end
    end
  end
end
