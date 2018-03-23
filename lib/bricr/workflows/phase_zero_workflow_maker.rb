########################################################################################################################
#  BRICR, Copyright (c) 2017, Alliance for Sustainable Energy, LLC and The Regents of the University of California, through Lawrence 
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
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:LightingImprovements/auc:MeasureName'].text
			# Lighting / LightingImprovements / Retrofit with light emitting diode technologies
			if measure_name == "Retrofit with light emitting diode technologies"
				set_measure_argument(osw, 'SetLightingLoadsByLPD', '__SKIP__', false)
				set_measure_argument(osw, 'SetLightingLoadsByLPD', 'lpd', 0.6)
			end
			# Lighting / LightingImprovements / Add daylight controls
			if measure_name == "Add daylight controls"
				set_measure_argument(osw, 'AddDaylightSensors', '__SKIP__', false)
				if $bricr_bldg_type == "SmallOffice"
					set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Office WholeBuilding - Sm Office - #{$bricr_template}")
				elsif $bricr_bldg_type == "MediumOffice"
					set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Office WholeBuilding - Md Office - #{$bricr_template}")
				elsif $bricr_bldg_type == "RetailStandalone"
					set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Retail Retail - #{$bricr_template}")
				end
			end
			# Lighting / LightingImprovements / Add occupancy sensors
			if measure_name == "Add occupancy sensors"
				set_measure_argument(osw, 'ReduceLightingLoadsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'ReduceLightingLoadsByPercentage', 'lighting_power_reduction_percent', 5)
			end
          end
          
		  # Plug Load
		  if measure_category == "Plug Load"
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:PlugLoadReductions/auc:MeasureName'].text
			# Plug Load / PlugLoadReductions / Replace with ENERGY STAR rated
			if measure_name == "Replace with ENERGY STAR rated"
				set_measure_argument(osw, 'tenant_star_internal_loads', '__SKIP__', false)
				set_measure_argument(osw, 'tenant_star_internal_loads', 'epd', 0.6) # W/ft^2
			end
			# Plug Load / PlugLoadReductions / Install plug load controls
			if measure_name == "Install plug load controls"
				set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', 'elecequip_power_reduction_percent', 20.0)
			end
			# Plug Load / PlugLoadReductions / Replace ice_refrigeration equipment with high efficiency units
			if measure_name == "Replace ice_refrigeration equipment with high efficiency units"
				set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', 'elecequip_power_reduction_percent', 5)
			end
          end
          
		  # Wall
		  if measure_category == "Wall"
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BuildingEnvelopeModifications/auc:MeasureName'].text
			# Wall / BuildingEnvelopeModifications / Air seal envelope
			if measure_name == "Air seal envelope"
				set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', 'space_infiltration_reduction_percent', 30.0)
			end
			# Wall / BuildingEnvelopeModifications / Increase wall insulation
			if  measure_name == "Increase wall insulation"
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWalls', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWalls', 'r_value', 25) # R-value
			end
			# Wall / BuildingEnvelopeModifications / Insulate thermal bypasses
			if  measure_name == "Insulate thermal bypasses"
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWallsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWallsByPercentage', 'r_value', 20) # R-value increase percentage
			end
		  end
		  
		  # Roof / Ceiling
		  if measure_category == "Roof / Ceiling"
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BuildingEnvelopeModifications/auc:MeasureName'].text
			# Roof / Ceiling / BuildingEnvelopeModifications / Increase roof insulation
			if measure_name == "Increase roof insulation"
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', 'r_value', 30) # R-value
			end
			# Roof / Ceiling / BuildingEnvelopeModifications / Increase ceiling insulation
			if measure_name == "Increase ceiling insulation"
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofsByPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'IncreaseInsulationRValueForRoofsByPercentage', 'r_value', 20) # R-value increase percentage
			end
		  end
		  
		  # Fenestration
		  if measure_category == "Fenestration"
			# Fenestration / BuildingEnvelopeModifications
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BuildingEnvelopeModifications/auc:MeasureName'].text
			# Fenestration / BuildingEnvelopeModifications / Replace windows
			if measure_name == "Replace windows"
				set_measure_argument(osw, 'replace_simple_glazing', '__SKIP__', false)
				set_measure_argument(osw, 'replace_simple_glazing', 'u_value', 1.65) # W/Km2
				set_measure_argument(osw, 'replace_simple_glazing', 'shgc', 0.2)
				set_measure_argument(osw, 'replace_simple_glazing', 'vt', 0.81)
			end

			# Fenestration / BuildingEnvelopeModifications / Add window films
			if measure_name == "Add window films"
				set_measure_argument(osw, 'improve_simple_glazing_by_percentage', '__SKIP__', false)
				set_measure_argument(osw, 'improve_simple_glazing_by_percentage', 'u_value_improvement_percent', 10)
				set_measure_argument(osw, 'improve_simple_glazing_by_percentage', 'shgc_improvement_percent', 30)
			end
		  end
          
		  # Heating System
		  if measure_category == "Heating System"
			# Heating System / OtherHVAC
			if defined? (measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text)
				measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text
				# Heating System / OtherHVAC / Replace burner
				if measure_name == "Replace burner"
					# furnace system
					if $bricr_system_type == "PSZ-AC with gas coil heat"
						set_measure_argument(osw, 'SetGasBurnerEfficiency', '__SKIP__', false)
						set_measure_argument(osw, 'SetGasBurnerEfficiency', 'eff', 0.93)
					end
				end
			end 
			
			# Heating System / BoilerPlantImprovements
			if defined? (measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BoilerPlantImprovements/auc:MeasureName'].text)
				measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:BoilerPlantImprovements/auc:MeasureName'].text
				# Heating System / BoilerPlantImprovements / Replace boiler
				if measure_name == "Replace boiler"
					# Boiler system for medium office
					if $bricr_system_type == "PVAV with reheat"
						set_measure_argument(osw, 'set_boiler_thermal_efficiency', '__SKIP__', false)
						set_measure_argument(osw, 'set_boiler_thermal_efficiency', 'input_option_manual', true)
						set_measure_argument(osw, 'set_boiler_thermal_efficiency', 'boiler_thermal_efficiency', 0.93)
					end
				end
			end
		  end
          
		  # Cooling System
		  if measure_category == "Cooling System"
			# Cooling System / OtherHVAC
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
		    # Cooling System / OtherHVAC / Replace package units
			if measure_name == "Replace package units"
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
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
			# Other HVAC / OtherHVAC / Replace HVAC system type to VRF 
			if measure_name == "Replace HVAC system type to VRF"
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
				set_measure_argument(osw, 'vr_fwith_doas', 'vrfCoolCOP', 6.0)
				set_measure_argument(osw, 'vr_fwith_doas', 'vrfHeatCOP', 6.0)
				set_measure_argument(osw, 'vr_fwith_doas', 'doasDXEER', 14)
			end
			# Other HVAC / OtherHVAC / Replace HVAC with GSHP and DOAS 
			if measure_name == "Replace HVAC with GSHP and DOAS"
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
			# Other HVAC / OtherHVAC / Replace HVAC system type to PZHP 
			if measure_name == "Replace HVAC system type to PZHP"
				set_measure_argument(osw, 'add_apszhp_to_each_zone', '__SKIP__', false)
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'delete_existing', true)
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'cop_cooling', 3.1)
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'cop_heating', 3.1)
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'has_electric_coil', true)
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'has_dcv', false)
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'fan_type', "Constant Volume (default)") # Options: "Constant Volume (default)", "Variable Volume (VFD)"
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'fan_pressure_rise', 0)
				set_measure_argument(osw, 'add_apszhp_to_each_zone', 'filter_type', "By Space Type")
				if $bricr_bldg_type == "SmallOffice"
					set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Office WholeBuilding - Sm Office - #{$bricr_template}")
				elsif $bricr_bldg_type == "MediumOffice"
					set_measure_argument(osw, 'create_typical_building_from_model', 'system_type', "PSZ-AC with gas coil heat")
					set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Office WholeBuilding - Md Office - #{$bricr_template}")
				elsif $bricr_bldg_type == "RetailStandalone"
					set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Retail - #{$bricr_template}")
					set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Point_of_Sale - #{$bricr_template}")
					set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Entry - #{$bricr_template}")
					set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Back_Space - #{$bricr_template}")
				end
			end
					
          end
		  
		  # General Controls and Operations
		  if measure_category == "General Controls and Operations"
			# General Controls and Operations / OtherHVAC
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
			# General Controls and Operations / OtherHVAC / Upgrade operating protocols, calibration, and_or sequencing 
			if measure_name == "Upgrade operating protocols, calibration, and_or sequencing"
				set_measure_argument(osw, 'AdjustThermostatSetpointsByDegrees', '__SKIP__', false)
				set_measure_argument(osw, 'AdjustThermostatSetpointsByDegrees', 'cooling_adjustment', 1.0)
				set_measure_argument(osw, 'AdjustThermostatSetpointsByDegrees', 'heating_adjustment', -1.0)
			end
		  end
		
		  # Fan
		  if measure_category == "Fan"
			# Fan / ElectricMotorsAndDrives
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:ElectricMotorsAndDrives/auc:MeasureName'].text	
		    # Fan / ElectricMotorsAndDrives / Replace with higher efficiency
			if measure_name == "Replace with higher efficiency"
				set_measure_argument(osw, 'ReplaceFanTotalEfficiency', '__SKIP__', false)
				set_measure_argument(osw, 'ReplaceFanTotalEfficiency', 'motor_eff', 80.0) # New efficiency
			end
		  end
		  
		  # Air Distribution
		  if measure_category == "Air Distribution"
			# Air Distribution / OtherHVAC
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
		    # Air Distribution / OtherHVAC / Improve ventilation fans
			if measure_name == "Improve ventilation fans"
				set_measure_argument(osw, 'ImproveFanTotalEfficiencybyPercentage', '__SKIP__', false)
				set_measure_argument(osw, 'ImproveFanTotalEfficiencybyPercentage', 'motor_eff', 10) # Efficiency improvement
			end
			
			# Air Distribution / OtherHVAC
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
		    # Air Distribution / OtherHVAC / Enable Demand Controlled Ventilation
			if measure_name == "Enable Demand Controlled Ventilation"
				set_measure_argument(osw, 'EnableDemandControlledVentilation', '__SKIP__', false)
				set_measure_argument(osw, 'EnableDemandControlledVentilation', 'dcv_type', "EnableDCV")
			end
			
			# Air Distribution / OtherHVAC
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
		    # Air Distribution / OtherHVAC / Add or repair economizer
			if measure_name == "Add or repair economizer"
				set_measure_argument(osw, 'EnableEconomizerControl', '__SKIP__', false)
				set_measure_argument(osw, 'EnableEconomizerControl', 'economizer_type', "FixedDryBulb")
			end
		  end
		  
		  # Heat Recovery
		  if measure_category == "Heat Recovery"
			# Heat Recovery / OtherHVAC
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:OtherHVAC/auc:MeasureName'].text	
		    # Heat Recovery / OtherHVAC / Add energy recovery
			if measure_name == "Add energy recovery"
				set_measure_argument(osw, 'add_energy_recovery_ventilator', '__SKIP__', false)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'sensible_eff_at_100_heating', 0)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'latent_eff_at_100_heating', 0)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'sensible_eff_at_75_heating', 0)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'latent_eff_at_75_heating', 0)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'sensible_eff_at_100_cooling', 1)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'latent_eff_at_100_cooling', 1)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'sensible_eff_at_75_cooling', 1)
				set_measure_argument(osw, 'add_energy_recovery_ventilator', 'latent_eff_at_75_cooling', 1)
			end
		  end
		  
		  # Domestic Hot Water
		  if measure_category == "Domestic Hot Water"
			# Domestic Hot Water / ChilledWaterHotWaterAndSteamDistributionSystems
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:ChilledWaterHotWaterAndSteamDistributionSystems/auc:MeasureName'].text	
		    # Domestic Hot Water / ChilledWaterHotWaterAndSteamDistributionSystems / Replace or upgrade water heater
			if measure_name == "Replace or upgrade water heater"
				set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', '__SKIP__', false)
				set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'heater_fuel_type_widget', "NaturalGas")
				set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'heater_thermal_efficiency', 0.88)
			end
			
			# Domestic Hot Water / ChilledWaterHotWaterAndSteamDistributionSystems / Add pipe insulation
			if measure_name == "Add pipe insulation"
				set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', '__SKIP__', false)
				set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'onoff_cycle_loss_coefficient_to_ambient_temperature', 0.25)
			end
			
			# Domestic Hot Water / ChilledWaterHotWaterAndSteamDistributionSystems / Add recirculating pumps
			if measure_name == "Add recirculating pumps"
				set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', '__SKIP__', false)
				set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'onoff_cycle_loss_coefficient_to_ambient_temperature', 0.1)
			end
			
		  end
		  
		  # Water Use
		  if measure_category == "Water Use"
			# Domestic Hot Water / WaterAndSewerConservationSystems
			measure_name = measure.elements['auc:TechnologyCategories/auc:TechnologyCategory/auc:WaterAndSewerConservationSystems/auc:MeasureName'].text	
			# Domestic Hot Water / WaterAndSewerConservationSystems / Install low-flow faucets and showerheads
			if measure_name == "Install low-flow faucets and showerheads"
				set_measure_argument(osw, 'reduce_water_use_by_percentage', '__SKIP__', false)
				set_measure_argument(osw, 'reduce_water_use_by_percentage', 'water_use_reduction_percent', 50)
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
