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
    def initialize(doc, ns)
      super

      # load the workflow
      @workflow = nil
      
      # log failed scenarios
      @failed_scenarios = []

      # select base osw for standalone, small office, medium office
      base_osw = 'phase_zero_base.osw'

      workflow_path = File.join(File.dirname(__FILE__), base_osw)
      raise "File '#{workflow_path}' does not exist" unless File.exist?(workflow_path)

      File.open(workflow_path, 'r') do |file|
        @workflow = JSON.parse(file.read)
      end
      
      @facility = {}
      @subsections = []

      # configure the workflow based on properties in the xml
      configureForDoc(@workflow)
    end

    def configureForDoc(osw)

      # get the facility floor areas
      @facility['gross_floor_area'] = nil
      @facility['heated_and_cooled_floor_area'] = nil
      @facility['footprint_floor_area'] = nil
      @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings/#{@ns}:Building/#{@ns}:FloorAreas/#{@ns}:FloorArea") do |floor_area_element|
        floor_area = floor_area_element.elements["#{@ns}:FloorAreaValue"].text.to_f
        next if floor_area.nil?
        
        floor_area_type = floor_area_element.elements["#{@ns}:FloorAreaType"].text
        if floor_area_type == 'Gross'
          @facility['gross_floor_area'] = floor_area
        elsif floor_area_type == 'Heated and Cooled'
          @facility['heated_and_cooled_floor_area'] = floor_area
        elsif floor_area_type == 'Footprint'
          @facility['footprint_floor_area'] = floor_area
        end
      end

      # SHL- get the template (vintage)
      @facility['template'] = nil
      @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings/#{@ns}:Building") do |facility_element|
        built_year = facility_element.elements["#{@ns}:YearOfConstruction"].text.to_f
        
        if facility_element.elements["#{@ns}:YearOfLastMajorRemodel"]
          major_remodel_year = facility_element.elements["#{@ns}:YearOfLastMajorRemodel"].text.to_f
          built_year = major_remodel_year if major_remodel_year > built_year
        end

        if built_year < 1978
          @facility['template'] = "CBES Pre-1978"
        elsif built_year >= 1978 && built_year < 1992
          @facility['template'] = "CBES T24 1978"
        elsif built_year >= 1992 && built_year < 2001
          @facility['template'] = "CBES T24 1992"
        elsif built_year >= 2001 && built_year < 2005
          @facility['template'] = "CBES T24 2001"
        elsif built_year >= 2005 && built_year < 2008
          @facility['template'] = "CBES T24 2005"
        else
          @facility['template'] = "CBES T24 2008"
        end

      end

      @facility['num_stories_above_grade'] = nil
      @facility['num_stories_below_grade'] = nil
      @facility['ns_to_ew_ratio'] = nil
      @facility['building_rotation'] = nil # TBD
      @facility['floor_height'] = nil # TBD
      @facility['wwr'] = nil # TBD

      @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings/#{@ns}:Building") do |facility_element|

        if facility_element.elements["#{@ns}:FloorsAboveGrade"]
          @facility['num_stories_above_grade'] = facility_element.elements["#{@ns}:FloorsAboveGrade"].text.to_f
		  if @facility['num_stories_above_grade'] == 0
			@facility['num_stories_above_grade'] = 1.0
		  end
        else
          @facility['num_stories_above_grade'] = 1.0 # setDefaultValue
        end
	       
        if facility_element.elements["#{@ns}:FloorsBelowGrade"]
          @facility['num_stories_below_grade'] = facility_element.elements["#{@ns}:FloorsBelowGrade"].text.to_f
        else 
          @facility['num_stories_below_grade'] = 0.0 # setDefaultValue
        end
        
        if facility_element.elements["#{@ns}:AspectRatio"]
          @facility['ns_to_ew_ratio'] = facility_element.elements["#{@ns}:AspectRatio"].text.to_f
        else
          @facility['ns_to_ew_ratio'] = 0.0 # setDefaultValue
        end
        
        @facility['building_rotation'] = 0.0 # setDefaultValue
        @facility['floor_height'] = 0.0 # setDefaultValue in ft
        @facility['wwr'] = 0.0 # setDefaultValue in fraction
      
        subsections = []
        facility_element.elements.each("#{@ns}:Sections/#{@ns}:Section") do |subsection_element|
          subsection = {'gross_floor_area' => nil, 'heated_and_cooled_floor_area' => nil, 'footprint_floor_area' => nil, 'occupancy_type' => nil, 'bldg_type' => nil, 'bar_division_method' => nil, 'system_type' => nil}
          
          subsection_element.elements.each("#{@ns}:FloorAreas/#{@ns}:FloorArea") do |floor_area_element|
            
            floor_area = floor_area_element.elements["#{@ns}:FloorAreaValue"].text.to_f
            next if floor_area.nil?
            
            floor_area_type = floor_area_element.elements["#{@ns}:FloorAreaType"].text
            if floor_area_type == 'Gross'
              subsection['gross_floor_area'] = floor_area
            elsif floor_area_type == 'Heated and Cooled'
              subsection['heated_and_cooled_floor_area'] = floor_area
            elsif floor_area_type == 'Footprint'
              subsection['footprint_floor_area'] = floor_area
            end
          end

          #puts subsection_element
          subsection['occupancy_type'] = subsection_element.elements["#{@ns}:OccupancyClassification"].text
          if subsection['occupancy_type'] == 'Retail'
            subsection['bldg_type'] = 'RetailStandalone'
            subsection['bar_division_method'] = 'Multiple Space Types - Individual Stories Sliced'
            subsection['system_type'] = 'PSZ-AC with gas coil heat'
          elsif subsection['occupancy_type']  == 'Office'
            subsection['bar_division_method'] = 'Single Space Type - Core and Perimeter'
            if subsection['gross_floor_area'] > 0 && subsection['gross_floor_area'] < 20000
              subsection['bldg_type'] = 'SmallOffice'
              subsection['system_type'] = 'PSZ-AC with gas coil heat'
            elsif subsection['gross_floor_area'] >= 20000 && subsection['gross_floor_area'] < 75000
              subsection['bldg_type'] = 'MediumOffice'
              subsection['system_type'] = 'PVAV with reheat'
            else
              raise "Office building size is beyond BRICR scope"
            end
          else
            raise "Building type '#{subsection['occupancy_type']}' is beyond BRICR scope"
          end
          
          raise "Subsection does not define gross floor area" if subsection['gross_floor_area'].nil?
          
          subsections << subsection
        end
        
        # sort subsections from largest to smallest
        @subsections = subsections.sort{|x,y| y['gross_floor_area'] <=> x['gross_floor_area']}
        
        raise "No subsections defined" if @subsections.empty?
        
        subsection_total_gross_area = 0
        @subsections.each {|ss| subsection_total_gross_area += ss['gross_floor_area']}
        
        raise "Zero total subsection gross area" if subsection_total_gross_area < 1.0
        
        @subsections.each {|ss| ss['fract_bldg_area'] = ss['gross_floor_area'] / subsection_total_gross_area}

        @facility['bar_division_method'] = @subsections[0]['bar_division_method']
        @facility['system_type'] = @subsections[0]['system_type']
        @facility['bldg_type'] = @subsections[0]['bldg_type']
      end
      
    
      # set this value in the osw
      # For measure: create_bar_from_building_type_ratios 
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'total_bldg_floor_area', @facility['gross_floor_area'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'template', @facility['template'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_a', @subsections[0]['bldg_type'])
      if @subsections.size > 1
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_b', @subsections[1]['bldg_type'])
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_b_fract_bldg_area', @subsections[1]['fract_bldg_area'])
      else
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_b', @facility['bldg_type'])
      end
      if @subsections.size > 2
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_c', @subsections[2]['bldg_type'])
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_c_fract_bldg_area', @subsections[2]['fract_bldg_area'])      
      else
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_c', @facility['bldg_type'])
      end
      if @subsections.size > 3
         set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_d', @subsections[3]['bldg_type'])
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_d_fract_bldg_area', @subsections[3]['fract_bldg_area'])          
      else
        set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bldg_type_d', @facility['bldg_type'])
      end
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'floor_height', @facility['floor_height'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'num_stories_above_grade', @facility['num_stories_above_grade'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'num_stories_below_grade', @facility['num_stories_below_grade'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'building_rotation', @facility['building_rotation'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'ns_to_ew_ratio', @facility['ns_to_ew_ratio'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'wwr', @facility['wwr'])
      set_measure_argument(osw, 'create_bar_from_building_type_ratios_bricr', 'bar_division_method', @facility['bar_division_method'])
      
      # For measure: create_typical_building_from_model
      set_measure_argument(osw, 'create_typical_building_from_model_bricr', 'template', @facility['template'])
      set_measure_argument(osw, 'create_typical_building_from_model_bricr', 'system_type', @facility['system_type'] )
      # Calibration
      set_measure_argument(osw, 'calibrate_baseline_model', 'template', @facility['template'])
      set_measure_argument(osw, 'calibrate_baseline_model', 'bldg_type', @facility['bldg_type'])
      if defined?(BRICR::DO_MODEL_CALIBRATION) and BRICR::DO_MODEL_CALIBRATION
        set_measure_argument(osw, 'calibrate_baseline_model', '__SKIP__', false)
      end
    end

    def configureForScenario(osw, scenario)
      measure_ids = []
      scenario.elements.each("#{@ns}:ScenarioType/#{@ns}:PackageOfMeasures/#{@ns}:MeasureIDs/#{@ns}:MeasureID") do |measure_id|
        measure_ids << measure_id.attributes['IDref']
      end

      num_measures = 0
      measure_ids.each do |measure_id|
        @doc.elements.each("//#{@ns}:Measure[@ID='#{measure_id}']") do |measure|
          measure_category = measure.elements["#{@ns}:SystemCategoryAffected"].text

          # Lighting
          if measure_category == "Lighting"
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:LightingImprovements/#{@ns}:MeasureName"].text
            # Lighting / LightingImprovements / Retrofit with light emitting diode technologies
            if measure_name == "Retrofit with light emitting diode technologies"
              num_measures += 1
              set_measure_argument(osw, 'SetLightingLoadsByLPD', '__SKIP__', false)
              set_measure_argument(osw, 'SetLightingLoadsByLPD', 'lpd', 0.6)
            end
            # Lighting / LightingImprovements / Add daylight controls
            if measure_name == "Add daylight controls"
              num_measures += 1
              set_measure_argument(osw, 'AddDaylightSensors', '__SKIP__', false)
              if @facility['bldg_type'] == "SmallOffice"
                set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Office WholeBuilding - Sm Office - #{@facility['template']}")
              elsif @facility['bldg_type'] == "MediumOffice"
                set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Office WholeBuilding - Md Office - #{@facility['template']}")
              elsif @facility['bldg_type'] == "RetailStandalone"
                set_measure_argument(osw, 'AddDaylightSensors', 'space_type', "Retail Retail - #{@facility['template']}")
              end
            end
            # Lighting / LightingImprovements / Add occupancy sensors
            if measure_name == "Add occupancy sensors"
              num_measures += 1
              set_measure_argument(osw, 'ReduceLightingLoadsByPercentage', '__SKIP__', false)
              set_measure_argument(osw, 'ReduceLightingLoadsByPercentage', 'lighting_power_reduction_percent', 5)
            end
          end
          
          # Plug Load
          if measure_category == "Plug Load"
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:PlugLoadReductions/#{@ns}:MeasureName"].text
            # Plug Load / PlugLoadReductions / Replace with ENERGY STAR rated
            if measure_name == "Replace with ENERGY STAR rated"
              num_measures += 1
              set_measure_argument(osw, 'tenant_star_internal_loads', '__SKIP__', false)
              set_measure_argument(osw, 'tenant_star_internal_loads', 'epd', 0.6) # W/ft^2
            end
            # Plug Load / PlugLoadReductions / Install plug load controls
            if measure_name == "Install plug load controls"
              num_measures += 1
              set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', '__SKIP__', false)
              set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', 'elecequip_power_reduction_percent', 20.0)
            end
          end
		  
          # Refrigeration
          if measure_category == "Refrigeration"
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:Refrigeration/#{@ns}:MeasureName"].text
            # Refrigeration / Refrigeration / Replace ice/refrigeration equipment with high efficiency units
            if measure_name == "Replace ice/refrigeration equipment with high efficiency units"
              num_measures += 1
              set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', '__SKIP__', false)
              set_measure_argument(osw, 'ReduceElectricEquipmentLoadsByPercentage', 'elecequip_power_reduction_percent', 5)
            end
          end
          
          # Wall
          if measure_category == "Wall"
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BuildingEnvelopeModifications/#{@ns}:MeasureName"].text
            # Wall / BuildingEnvelopeModifications / Air seal envelope
            if measure_name == "Air seal envelope"
              num_measures += 1
              set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', '__SKIP__', false)
              set_measure_argument(osw, 'ReduceSpaceInfiltrationByPercentage', 'space_infiltration_reduction_percent', 30.0)
            end
            # Wall / BuildingEnvelopeModifications / Increase wall insulation
            if  measure_name == "Increase wall insulation"
              num_measures += 1
              set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWalls', '__SKIP__', false)
              set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWalls', 'r_value', 25) # R-value
            end
            # Wall / BuildingEnvelopeModifications / Insulate thermal bypasses
            if  measure_name == "Insulate thermal bypasses"
              num_measures += 1
              set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWallsByPercentage', '__SKIP__', false)
              set_measure_argument(osw, 'IncreaseInsulationRValueForExteriorWallsByPercentage', 'r_value', 20) # R-value increase percentage
            end
          end
      
          # Roof
          if measure_category == "Roof"
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BuildingEnvelopeModifications/#{@ns}:MeasureName"].text
            # Roof / BuildingEnvelopeModifications / Increase roof insulation
            if measure_name == "Increase roof insulation"
              num_measures += 1
              set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', '__SKIP__', false)
              set_measure_argument(osw, 'IncreaseInsulationRValueForRoofs', 'r_value', 30) # R-value
            end
          end
		  
          # Ceiling
          if measure_category == "Ceiling"
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BuildingEnvelopeModifications/#{@ns}:MeasureName"].text
            # Ceiling / BuildingEnvelopeModifications / Increase ceiling insulation
            if measure_name == "Increase ceiling insulation"
              num_measures += 1
              set_measure_argument(osw, 'IncreaseInsulationRValueForRoofsByPercentage', '__SKIP__', false)
              set_measure_argument(osw, 'IncreaseInsulationRValueForRoofsByPercentage', 'r_value', 20) # R-value increase percentage
            end
          end
      
          # Fenestration
          if measure_category == "Fenestration"
            # Fenestration / BuildingEnvelopeModifications
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BuildingEnvelopeModifications/#{@ns}:MeasureName"].text
            # Fenestration / BuildingEnvelopeModifications / Replace windows
            if measure_name == "Replace windows"
              num_measures += 1
              set_measure_argument(osw, 'replace_simple_glazing', '__SKIP__', false)
              set_measure_argument(osw, 'replace_simple_glazing', 'u_value', 1.65) # W/Km2
              set_measure_argument(osw, 'replace_simple_glazing', 'shgc', 0.2)
              set_measure_argument(osw, 'replace_simple_glazing', 'vt', 0.81)
            end

            # Fenestration / BuildingEnvelopeModifications / Add window films
            if measure_name == "Add window films"
              num_measures += 1
              set_measure_argument(osw, 'improve_simple_glazing_by_percentage', '__SKIP__', false)
              set_measure_argument(osw, 'improve_simple_glazing_by_percentage', 'u_value_improvement_percent', 10)
              set_measure_argument(osw, 'improve_simple_glazing_by_percentage', 'shgc_improvement_percent', 30)
            end
          end
          
          # Heating System
          if measure_category == "Heating System"
            # Heating System / OtherHVAC
            if defined? (measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text)
              measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text
              # Heating System / OtherHVAC / Replace burner
              if measure_name == "Replace burner"
                # furnace system
                if @facility['system_type'] == "PSZ-AC with gas coil heat"
                  num_measures += 1
                  set_measure_argument(osw, 'SetGasBurnerEfficiency', '__SKIP__', false)
                  set_measure_argument(osw, 'SetGasBurnerEfficiency', 'eff', 0.93)
                else
                  # measure is NA
                  num_measures += 1                
                end
              end
            end 
        
            # Heating System / BoilerPlantImprovements
            if defined? (measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BoilerPlantImprovements/#{@ns}:MeasureName"].text)
              measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BoilerPlantImprovements/#{@ns}:MeasureName"].text
              # Heating System / BoilerPlantImprovements / Replace boiler
              if measure_name == "Replace boiler"
                # Boiler system for medium office
                if @facility['system_type'] == "PVAV with reheat"
                  num_measures += 1
                  set_measure_argument(osw, 'set_boiler_thermal_efficiency', '__SKIP__', false)
                  set_measure_argument(osw, 'set_boiler_thermal_efficiency', 'input_option_manual', true)
                  set_measure_argument(osw, 'set_boiler_thermal_efficiency', 'boiler_thermal_efficiency', 0.93)
                else
                  # measure is NA
                  num_measures += 1
                end
              end
            end
          end
          
          # Cooling System
          if measure_category == "Cooling System"
            # Cooling System / OtherHVAC
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text 
            # Cooling System / OtherHVAC / Replace package units
            if measure_name == "Replace package units"
              if @facility['system_type'] == "PSZ-AC with gas coil heat"
                num_measures += 1
                set_measure_argument(osw, 'SetCOPforSingleSpeedDXCoolingUnits', '__SKIP__', false)
                set_measure_argument(osw, 'SetCOPforSingleSpeedDXCoolingUnits', 'cop', 4.1)
              elsif @facility['system_type'] == "PVAV with reheat"
                num_measures += 1
                set_measure_argument(osw, 'SetCOPforTwoSpeedDXCoolingUnits', '__SKIP__', false)
                set_measure_argument(osw, 'SetCOPforTwoSpeedDXCoolingUnits', 'cop_high', 4.1)
                set_measure_argument(osw, 'SetCOPforTwoSpeedDXCoolingUnits', 'cop_low', 4.1)
              end
            end
          end
      
          # Other HVAC
          if measure_category == "Other HVAC"
          
            # Other HVAC / OtherHVAC
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text 
            
            # DLM: somme measures don't have a direct BuildingSync equivalent, use UserDefinedField 'OpenStudioMeasureName' for now
            if measure_name == 'Other'
              # measure.elements.each("#{@ns}:UserDefinedFields/#{@ns}:UserDefinedField") do |user_defined_field|
              #   field_name = user_defined_field.elements["#{@ns}:FieldName"].text 
              #   if field_name == 'OpenStudioMeasureName'
              #     measure_name = user_defined_field.elements["#{@ns}:FieldValue"].text 
              #   end
              # end

              # new v2.0 field: CustomMeasureName
              measure_name = measure.elements["#{@ns}:CustomMeasureName"].text 
            end
            
            # Other HVAC / OtherHVAC / Replace HVAC system type to VRF 
            if measure_name == "Replace HVAC system type to VRF"
              num_measures += 1
              set_measure_argument(osw, 'vr_fwith_doas', '__SKIP__', false)
              if @facility['bldg_type'] == "SmallOffice"
                set_measure_argument(osw, 'vr_fwith_doas', "Office WholeBuilding - Sm Office - #{@facility['template']}", true)
              elsif @facility['bldg_type'] == "MediumOffice"
                set_measure_argument(osw, 'vr_fwith_doas', "Office WholeBuilding - Md Office - #{@facility['template']}", true)
              elsif @facility['bldg_type'] == "RetailStandalone"
                set_measure_argument(osw, 'vr_fwith_doas', "Retail Retail - #{@facility['template']}", true)
                set_measure_argument(osw, 'vr_fwith_doas', "Retail Point_of_Sale - #{@facility['template']}", true)
                set_measure_argument(osw, 'vr_fwith_doas', "Retail Entry - #{@facility['template']}", true)
                set_measure_argument(osw, 'vr_fwith_doas', "Retail Back_Space - #{@facility['template']}", true)
              end
              set_measure_argument(osw, 'vr_fwith_doas', 'vrfCoolCOP', 6.0)
              set_measure_argument(osw, 'vr_fwith_doas', 'vrfHeatCOP', 6.0)
              set_measure_argument(osw, 'vr_fwith_doas', 'doasDXEER', 14)
            end
      
            # Other HVAC / OtherHVAC / Replace HVAC with GSHP and DOAS 
            if measure_name == "Replace HVAC with GSHP and DOAS" || measure_name == "Replace AC and heating units with ground coupled heat pump systems"
              num_measures += 1
              set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', '__SKIP__', false)
              if @facility['bldg_type'] == "SmallOffice"
                set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Office WholeBuilding - Sm Office - #{@facility['template']}", true)
              elsif @facility['bldg_type'] == "MediumOffice"
                set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Office WholeBuilding - Md Office - #{@facility['template']}", true)
              elsif @facility['bldg_type'] == "RetailStandalone"
                set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Retail - #{@facility['template']}", true)
                set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Point_of_Sale - #{@facility['template']}", true)
                set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Entry - #{@facility['template']}", true)
                set_measure_argument(osw, 'replace_hvac_with_gshp_and_doas', "Retail Back_Space - #{@facility['template']}", true)
              end
            end
            
            # Other HVAC / OtherHVAC / Replace HVAC system type to PZHP 
            if measure_name == "Replace HVAC system type to PZHP"
              num_measures += 1
              set_measure_argument(osw, 'add_apszhp_to_each_zone', '__SKIP__', false)
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'delete_existing', true)
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'cop_cooling', 3.1)
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'cop_heating', 3.1)
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'has_electric_coil', true)
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'has_dcv', false)
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'fan_type', "Constant Volume (default)") # Options: "Constant Volume (default)", "Variable Volume (VFD)"
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'fan_pressure_rise', 0)
              set_measure_argument(osw, 'add_apszhp_to_each_zone', 'filter_type', "By Space Type")
              if @facility['bldg_type'] == "SmallOffice"
                set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Office WholeBuilding - Sm Office - #{@facility['template']}")
              elsif @facility['bldg_type'] == "MediumOffice"
                set_measure_argument(osw, 'create_typical_building_from_model', 'system_type', "PSZ-AC with gas coil heat")
                set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Office WholeBuilding - Md Office - #{@facility['template']}")
              elsif @facility['bldg_type'] == "RetailStandalone"
                set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Retail - #{@facility['template']}")
                set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Point_of_Sale - #{@facility['template']}")
                set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Entry - #{@facility['template']}")
                set_measure_argument(osw, 'add_apszhp_to_each_zone', 'space_type', "Retail Back_Space - #{@facility['template']}")
              end
            end
          end
      
          # General Controls and Operations
          if measure_category == "General Controls and Operations"
            # General Controls and Operations / OtherHVAC
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text 
            # General Controls and Operations / OtherHVAC / Upgrade operating protocols, calibration, and/or sequencing 
            if measure_name == "Upgrade operating protocols, calibration, and/or sequencing"
              num_measures += 1
              set_measure_argument(osw, 'AdjustThermostatSetpointsByDegrees', '__SKIP__', false)
              set_measure_argument(osw, 'AdjustThermostatSetpointsByDegrees', 'cooling_adjustment', 1.0)
              set_measure_argument(osw, 'AdjustThermostatSetpointsByDegrees', 'heating_adjustment', -1.0)
            end
          end
    
          # Fan
          if measure_category == "Fan"
            # Fan / ElectricMotorsAndDrives
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherElectricMotorsAndDrives/#{@ns}:MeasureName"].text 
            # Fan / ElectricMotorsAndDrives / Replace with higher efficiency
            if measure_name == "Replace with higher efficiency"
              num_measures += 1
              set_measure_argument(osw, 'ReplaceFanTotalEfficiency', '__SKIP__', false)
              set_measure_argument(osw, 'ReplaceFanTotalEfficiency', 'motor_eff', 80.0) # New efficiency
            end
          end
      
          # Air Distribution
          if measure_category == "Air Distribution"
            # Air Distribution / OtherHVAC
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text 
            # Air Distribution / OtherHVAC / Improve ventilation fans
            if measure_name == "Improve ventilation fans"
              num_measures += 1
              set_measure_argument(osw, 'ImproveFanTotalEfficiencybyPercentage', '__SKIP__', false)
              set_measure_argument(osw, 'ImproveFanTotalEfficiencybyPercentage', 'motor_eff', 10) # Efficiency improvement
            end
            
            # Air Distribution / OtherHVAC
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text 
            # Air Distribution / OtherHVAC / Install demand control ventilation
            if measure_name == "Install demand control ventilation"
              num_measures += 1
              set_measure_argument(osw, 'EnableDemandControlledVentilation', '__SKIP__', false)
              set_measure_argument(osw, 'EnableDemandControlledVentilation', 'dcv_type', "EnableDCV")
            end
            
            # Air Distribution / OtherHVAC
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text 
            # Air Distribution / OtherHVAC / Add or repair economizer
            if measure_name == "Add or repair economizer"
              num_measures += 1
              set_measure_argument(osw, 'EnableEconomizerControl', '__SKIP__', false)
              set_measure_argument(osw, 'EnableEconomizerControl', 'economizer_type', "FixedDryBulb")
            end
          end
      
          # Heat Recovery
          if measure_category == "Heat Recovery"
            # Heat Recovery / OtherHVAC
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text 
            # Heat Recovery / OtherHVAC / Add energy recovery
            if measure_name == "Add energy recovery"
              num_measures += 1
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
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:ChilledWaterHotWaterAndSteamDistributionSystems/#{@ns}:MeasureName"].text 
            # Domestic Hot Water / ChilledWaterHotWaterAndSteamDistributionSystems / Replace or upgrade water heater
            if measure_name == "Replace or upgrade water heater"
              num_measures += 1
              set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', '__SKIP__', false)
              set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'heater_fuel_type_widget', "NaturalGas")
              set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'heater_thermal_efficiency', 0.88)
            end
            
            # Domestic Hot Water / ChilledWaterHotWaterAndSteamDistributionSystems / Add pipe insulation
            if measure_name == "Add pipe insulation"
              num_measures += 1
              set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', '__SKIP__', false)
              set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'onoff_cycle_loss_coefficient_to_ambient_temperature', 0.25)
            end
            
            # Domestic Hot Water / ChilledWaterHotWaterAndSteamDistributionSystems / Add recirculating pumps
            if measure_name == "Add recirculating pumps"
              num_measures += 1
              set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', '__SKIP__', false)
              set_measure_argument(osw, 'set_water_heater_efficiency_heat_lossand_peak_water_flow_rate', 'onoff_cycle_loss_coefficient_to_ambient_temperature', 0.1)
            end
          end
      
          # Water Use
          if measure_category == "Water Use"
            # Domestic Hot Water / WaterAndSewerConservationSystems
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:WaterAndSewerConservationSystems/#{@ns}:MeasureName"].text  
            # Domestic Hot Water / WaterAndSewerConservationSystems / Install low-flow faucets and showerheads
            if measure_name == "Install low-flow faucets and showerheads"
              num_measures += 1
              set_measure_argument(osw, 'reduce_water_use_by_percentage', '__SKIP__', false)
              set_measure_argument(osw, 'reduce_water_use_by_percentage', 'water_use_reduction_percent', 50)
            end
          end

          # OpenStudio Results (get monthly results in the JSON)
          set_measure_argument(osw, 'openstudio_results', 'reg_monthly_details', true)
        end
      end
      
      # ensure that we didn't miss any measures by accident
      if num_measures != measure_ids.size
        raise "#{measure_ids.size} measures expected, #{num_measures} found,  measure_ids = #{measure_ids}"
      end
    end

    def writeOSWs(dir)
      super
      
      #ensure there is a 'Baseline' scenario
      found_baseline = false
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        if scenario_name == 'Baseline'
          found_baseline = true
          break
        end
      end
      
      if !found_baseline
        scenarios_element = @doc.elements["#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios"]
        
        scenario_element = REXML::Element.new("#{@ns}:Scenario")
        scenario_element.attributes['ID'] = 'Baseline'
        
        scenario_name_element = REXML::Element.new("#{@ns}:ScenarioName")
        scenario_name_element.text = 'Baseline'
        scenario_element.add_element(scenario_name_element)
        
        scenario_type_element = REXML::Element.new("#{@ns}:ScenarioType")
        package_of_measures_element = REXML::Element.new("#{@ns}:PackageOfMeasures")
        reference_case_element = REXML::Element.new("#{@ns}:ReferenceCase")
        reference_case_element.attributes['IDref'] = 'Baseline'
        package_of_measures_element.add_element(reference_case_element)
        scenario_type_element.add_element(package_of_measures_element)
        scenario_element.add_element(scenario_type_element)

        scenarios_element.add_element(scenario_element)
      end
      
      found_baseline = false
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        if scenario_name == 'Baseline'
          found_baseline = true
          break
        end
      end
      
       if !found_baseline
        puts "Cannot find or create Baseline scenario"
        exit
      end
      
      # write an osw for each scenario
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

        # deep clone
        osw = JSON.load(JSON.generate(@workflow))

        # configure the workflow based on measures in this scenario
        begin
          configureForScenario(osw, scenario)

          # dir for the osw
          osw_dir = File.join(dir, scenario_name)
          FileUtils.mkdir_p(osw_dir)

          # write the osw
          path = File.join(osw_dir, 'in.osw')
          File.open(path, 'w') do |file|
            file << JSON.generate(osw)
          end
        rescue => e
          puts "Could not configure for scenario #{scenario_name}"
          puts e.backtrace.join("\n\t")
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
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

        # dir for the osw
        osw_dir = File.join(dir, scenario_name)
  
        # cleanup large files
        path = File.join(osw_dir, 'eplusout.sql')
        FileUtils.rm_f(path) if File.exists?(path)
        
        path = File.join(osw_dir, 'data_point.zip')
        FileUtils.rm_f(path) if File.exists?(path)
        
        path = File.join(osw_dir, 'eplusout.eso')
        FileUtils.rm_f(path) if File.exists?(path)
        
        Dir.glob(File.join(osw_dir, '*create_typical_building_from_model')).each do |path|
          FileUtils.rm_rf(path) if File.exists?(path)
        end
        
        # find the osw
        path = File.join(osw_dir, 'out.osw')
        if !File.exists?(path)
          puts "Cannot load results for scenario #{scenario_name}"
          next
        end
        
        workflow = nil
        File.open(path, 'r') do |file|
          results[scenario_name] = JSON.parse(file.read, symbolize_names: true)
        end
        
       
      end

      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        next if defined?(BRICR::SIMULATE_BASELINE_ONLY) and BRICR::SIMULATE_BASELINE_ONLY and scenario_name != 'Baseline'

        package_of_measures = scenario.elements["#{@ns}:ScenarioType"].elements["#{@ns}:PackageOfMeasures"]
        
        # delete previous results
        package_of_measures.elements.delete("#{@ns}:AnnualSavingsSiteEnergy")
        package_of_measures.elements.delete("#{@ns}:AnnualSavingsCost")
        package_of_measures.elements.delete("#{@ns}:CalculationMethod")
        package_of_measures.elements.delete("#{@ns}AnnualSavingsByFuels")
        scenario.elements.delete("#{@ns}AllResourceTotals")
        scenario.elements.delete("#{@ns}RsourceUses")
        scenario.elements.delete("#{@ns}AnnualSavingsByFuels")

        
        result = results[scenario_name]
        baseline = results['Baseline']
        
        if result.nil?
          puts "Cannot load results for scenario #{scenario_name}"
          @failed_scenarios << scenario_name
          next        
        elsif baseline.nil?
          puts "Cannot load baseline results for scenario #{scenario_name}"
          @failed_scenarios << scenario_name
          next       
        end
        
        if result['completed_status'] == 'Success' || result[:completed_status] == 'Success'
          # success
        else
          @failed_scenarios << scenario_name
        end
        
        # preserve existing user defined fields if they exist
        # KAF: there should no longer be any UDFs
        user_defined_fields = scenario.elements["#{@ns}:UserDefinedFields"]
        if user_defined_fields.nil?
          user_defined_fields = REXML::Element.new("#{@ns}:UserDefinedFields")
        end
        
        # delete previous results (if using an old schema)
        to_remove = []
        user_defined_fields.elements.each("#{@ns}:UserDefinedField") do |user_defined_field|
          name_element = user_defined_field.elements["#{@ns}:FieldName"]
          if name_element.nil?
            to_remove << user_defined_field
          elsif /OpenStudio/.match(name_element.text)
            to_remove << user_defined_field
          end
        end        
        to_remove.each do |element|
          user_defined_fields.elements.delete(element)
        end
        
        # user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        # field_name = REXML::Element.new("#{@ns}:FieldName")
        # field_name.text = 'OpenStudioCompletedStatus'
        # field_value = REXML::Element.new("#{@ns}:FieldValue")
        # field_value.text = result[:completed_status]
        # user_defined_field.add_element(field_name)
        # user_defined_field.add_element(field_value)
        # user_defined_fields.add_element(user_defined_field)

        # this is now in PackageOfMeasures.CalculationMethod.Modeled.SimulationCompletionStatus
        # options are: Not Started, Started, Finished, Failed, Unknown
        calc_method = REXML::Element.new("#{@ns}:CalculationMethod")
        modeled = REXML::Element.new("#{@ns}:Modeled")
        weather_data_type = REXML::Element.new("#{@ns}:WeatherDataType")
        weather_data_type.text = 'TMY3'
        modeled.add_element(weather_data_type)
        sim_completion_status = REXML::Element.new("#{@ns}:SimulationCompletionStatus")
        sim_completion_status.text = result[:completed_status] === 'Success' ? 'Finished' : 'Failed'  # TODO: double check what these keys can be
        modeled.add_element(sim_completion_status)

        calc_method.add_element(modeled)
        package_of_measures.add_element(calc_method)

        # KAF: I don't think we are using this in new schema. you would look at the baseline scenario and check its "SimulationCompletionStatus"  
        # leaving it here for now      
        user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        field_name = REXML::Element.new("#{@ns}:FieldName")
        field_name.text = 'OpenStudioBaselineCompletedStatus'
        field_value = REXML::Element.new("#{@ns}:FieldValue")
        field_value.text = baseline[:completed_status]
        user_defined_field.add_element(field_name)
        user_defined_field.add_element(field_value)
        user_defined_fields.add_element(user_defined_field)        
        
        # Check out.osw "openstudio_results" for output variables
        total_site_energy = getMeasureResult(result, 'openstudio_results', 'total_site_energy') # in kBtu/year
        total_site_energy = total_site_energy / 1000.0 if total_site_energy # kBtu/year -> MMBtu/year
        baseline_total_site_energy = getMeasureResult(baseline, 'openstudio_results', 'total_site_energy') # in kBtu
        baseline_total_site_energy = baseline_total_site_energy / 1000.0 if baseline_total_site_energy # kBtu/year -> MMBtu/year
        fuel_electricity = getMeasureResult(result, 'openstudio_results', 'fuel_electricity') # in kBtu/year
        baseline_fuel_electricity = getMeasureResult(baseline, 'openstudio_results', 'fuel_electricity') # in kBtu/year
        #fuel_electricity = fuel_electricity * 0.2930710702 # kBtu/year -> kWh
        fuel_natural_gas = getMeasureResult(result, 'openstudio_results', 'fuel_natural_gas') # in kBtu/year
        baseline_fuel_natural_gas = getMeasureResult(baseline, 'openstudio_results', 'fuel_natural_gas') # in kBtu/year
        annual_utility_cost = getMeasureResult(result, 'openstudio_results', 'annual_utility_cost') # in $
        baseline_annual_utility_cost = getMeasureResult(baseline, 'openstudio_results', 'annual_utility_cost') # in $

        total_site_energy_savings = 0
        total_energy_cost_savings = 0
        if baseline_total_site_energy && total_site_energy
          total_site_energy_savings = baseline_total_site_energy - total_site_energy
          total_energy_cost_savings = baseline_annual_utility_cost - annual_utility_cost
        end
        
        annual_savings_site_energy = REXML::Element.new("#{@ns}:AnnualSavingsSiteEnergy")
        annual_savings_energy_cost = REXML::Element.new("#{@ns}:AnnualSavingsCost")
        
        annual_savings_site_energy.text = total_site_energy_savings
        annual_savings_energy_cost.text = total_energy_cost_savings.to_i # BuildingSync wants an integer, might be a BuildingSync bug

        package_of_measures.add_element(annual_savings_site_energy)
        package_of_measures.add_element(annual_savings_energy_cost)

        # KAF: adding annual savings by fuel
        electricity_savings = baseline_fuel_electricity - fuel_electricity
        natural_gas_savings = baseline_fuel_natural_gas - fuel_natural_gas
        annual_savings = REXML::Element.new("#{@ns}:AnnualSavingsByFuels")
        annual_saving = REXML::Element.new("#{@ns}:AnnualSavingsByFuel")
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Electricity'
        annual_saving.add_element(energy_res)
        resource_units = REXML::Element.new("#{@ns}:ResourceUnits")
        resource_units.text = 'kBtu'
        annual_saving.add_element(resource_units)
        savings_native = REXML::Element.new("#{@ns}:AnnualSavingsNativeUnits") # this is in kBtu
        savings_native.text = electricity_savings.to_s
        annual_saving.add_element(savings_native)
        annual_savings.add_element(annual_saving)

        annual_saving = REXML::Element.new("#{@ns}:AnnualSavingsByFuel")
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Natural gas'
        annual_saving.add_element(energy_res)
        resource_units = REXML::Element.new("#{@ns}:ResourceUnits")
        resource_units.text = 'kBtu'
        annual_saving.add_element(resource_units)
        savings_native = REXML::Element.new("#{@ns}:AnnualSavingsNativeUnits") # this is in kBtu
        savings_native.text = natural_gas_savings.to_s
        annual_saving.add_element(savings_native)
        annual_savings.add_element(annual_saving)

        package_of_measures.add_element(annual_savings)

        # KAF: replacing user defined fields with BuildingSync fields
               
        # user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        # field_name = REXML::Element.new("#{@ns}:FieldName")
        # field_name.text = 'OpenStudioAnnualElectricity_kBtu'
        # field_value = REXML::Element.new("#{@ns}:FieldValue")
        # field_value.text = fuel_electricity.to_s
        # user_defined_field.add_element(field_name)
        # user_defined_field.add_element(field_value)
        # user_defined_fields.add_element(user_defined_field)
        
        # user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        # field_name = REXML::Element.new("#{@ns}:FieldName")
        # field_name.text = 'OpenStudioAnnualNaturalGas_kBtu'
        # field_value = REXML::Element.new("#{@ns}:FieldValue")
        # field_value.text = fuel_natural_gas.to_s
        # user_defined_field.add_element(field_name)
        # user_defined_field.add_element(field_value)
        # user_defined_fields.add_element(user_defined_field)

        res_uses = REXML::Element.new("#{@ns}:ResourceUses")
        scenario_name_ns = scenario_name.gsub(" ", "_").gsub(/[^0-9a-z_]/i, '')
        # ELECTRICITY
        res_use = REXML::Element.new("#{@ns}:ResourceUse")
        res_use.add_attribute('ID', scenario_name_ns + "_Electricity")
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Electricity'
        res_units = REXML::Element.new("#{@ns}:ResourceUnits")
        res_units.text = 'kBtu'
        native_units = REXML::Element.new("#{@ns}:AnnualFuelUseNativeUnits")
        native_units.text = fuel_electricity.to_s
        consistent_units = REXML::Element.new("#{@ns}:AnnualFuelUseConsistentUnits")
        consistent_units.text = (fuel_electricity / 1000).to_s  # in MMBtu
        res_use.add_element(energy_res)
        res_use.add_element(res_units)
        res_use.add_element(native_units)
        res_use.add_element(consistent_units)
        res_uses.add_element(res_use)

        # NATURAL GAS
        res_use = REXML::Element.new("#{@ns}:ResourceUse")
        res_use.add_attribute('ID', scenario_name_ns + "_NaturalGas")
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Natural gas'
        res_units = REXML::Element.new("#{@ns}:ResourceUnits")
        res_units.text = 'kBtu'
        native_units = REXML::Element.new("#{@ns}:AnnualFuelUseNativeUnits")
        native_units.text = fuel_electricity.to_s
        consistent_units = REXML::Element.new("#{@ns}:AnnualFuelUseConsistentUnits")
        consistent_units.text = (fuel_electricity / 1000).to_s  # in MMBtu
        res_use.add_element(energy_res)
        res_use.add_element(res_units)
        res_use.add_element(native_units)
        res_use.add_element(consistent_units)
        res_uses.add_element(res_use)
        scenario_type = scenario.elements["#{@ns}:ScenarioType"]
        scenario.insert_after(scenario_type, res_uses)

        # KAF: prototype for adding monthly data (fake it for now)
        # already added ResourceUses above. Needed as ResourceUseID reference
        timeseriesdata = REXML::Element.new("#{@ns}:TimeSeriesData")

        # Electricity
        (1..12).each do |month|
          timeseries = REXML::Element.new("#{@ns}:TimeSeries")
          reading_type = REXML::Element.new("#{@ns}:ReadingType")
          reading_type.text = 'Total'
          timeseries.add_element(reading_type)
          ts_quantity = REXML::Element.new("#{@ns}:TimeSeriesReadingQuantity")
          ts_quantity.text = 'Energy'
          timeseries.add_element(ts_quantity)
          start_time = REXML::Element.new("#{@ns}:StartTimeStamp")
          if month < 10
            start_time.text = '2017-0' + month.to_s + '-01T00:00:00'
          else 
            start_time.text = '2017-' + month.to_s + '-01T00:00:00'
          end
          timeseries.add_element(start_time)
          end_time = REXML::Element.new("#{@ns}:EndTimeStamp")
          if month < 9
            end_time.text = '2017-0' + month.to_s + '-01T00:00:00'
          elsif month < 12
            end_time.text = '2017-' + (month+1).to_s + '-01T00:00:00'
          else
            end_time.text = '2018-01-01T00:00:00'
          end
          timeseries.add_element(end_time)
          interval_frequency = REXML::Element.new("#{@ns}:IntervalFrequency")
          interval_frequency.text = 'Month'
          timeseries.add_element(interval_frequency)
          interval_reading = REXML::Element.new("#{@ns}:IntervalReading")
          interval_reading.text = '0'
          timeseries.add_element(interval_reading)
          resource_id = REXML::Element.new("#{@ns}:ResourceUseID")
          resource_id.add_attribute('IDref', scenario_name_ns + "_Electricity")
          timeseries.add_element(resource_id)
          timeseriesdata.add_element(timeseries)
        end

        (1..12).each do |month|
          timeseries = REXML::Element.new("#{@ns}:TimeSeries")
          reading_type = REXML::Element.new("#{@ns}:ReadingType")
          reading_type.text = 'Total'
          timeseries.add_element(reading_type)
          ts_quantity = REXML::Element.new("#{@ns}:TimeSeriesReadingQuantity")
          ts_quantity.text = 'Energy'
          timeseries.add_element(ts_quantity)
          start_time = REXML::Element.new("#{@ns}:StartTimeStamp")
          if month < 10
            start_time.text = '2017-0' + month.to_s + '-01T00:00:00'
          else 
            start_time.text = '2017-' + month.to_s + '-01T00:00:00'
          end
          timeseries.add_element(start_time)
          end_time = REXML::Element.new("#{@ns}:EndTimeStamp")
          if month < 9
            end_time.text = '2017-0' + month.to_s + '-01T00:00:00'
          elsif month < 12
            end_time.text = '2017-' + (month+1).to_s + '-01T00:00:00'
          else
            end_time.text = '2018-01-01T00:00:00'
          end
          timeseries.add_element(end_time)
          interval_frequency = REXML::Element.new("#{@ns}:IntervalFrequency")
          interval_frequency.text = 'Month'
          timeseries.add_element(interval_frequency)
          interval_reading = REXML::Element.new("#{@ns}:IntervalReading")
          interval_reading.text = '0'
          timeseries.add_element(interval_reading)
          resource_id = REXML::Element.new("#{@ns}:ResourceUseID")
          resource_id.add_attribute('IDref', scenario_name_ns + "_NaturalGas")
          timeseries.add_element(resource_id)
          timeseriesdata.add_element(timeseries)
        end
        scenario.insert_after(res_uses, timeseriesdata)

        # user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        # field_name = REXML::Element.new("#{@ns}:FieldName")
        # field_name.text = 'OpenStudioAnnualSiteEnergy_MMBtu'
        # field_value = REXML::Element.new("#{@ns}:FieldValue")
        # field_value.text = total_site_energy.to_s
        # user_defined_field.add_element(field_name)
        # user_defined_field.add_element(field_value)
        # user_defined_fields.add_element(user_defined_field)
        all_res_totals = REXML::Element.new("#{@ns}:AllResourceTotals")
        all_res_total = REXML::Element.new("#{@ns}:AllResourceTotal")
        end_use = REXML::Element.new("#{@ns}:EndUse")
        end_use.text = 'All end uses'
        site_energy_use = REXML::Element.new("#{@ns}:SiteEnergyUse")
        site_energy_use.text = total_site_energy.to_s
        all_res_total.add_element(end_use)
        all_res_total.add_element(site_energy_use)
        all_res_totals.add_element(all_res_total)
        scenario.insert_after(timeseriesdata, all_res_totals)
        scenario.elements.delete("#{@ns}:UserDefinedFields")

      end
    end
    
    def failed_scenarios
      return @failed_scenarios
    end
    
  end
end
