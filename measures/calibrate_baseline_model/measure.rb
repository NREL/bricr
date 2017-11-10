# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class CalibrateBaselineModel < OpenStudio::Ruleset::ModelUserScript

  require 'openstudio-standards'
  require 'rubygems'
  require 'json'

  # require all .rb files in resources folder
  Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }
  @@calibrate_factors = JSON.parse(File.read(File.dirname(__FILE__) + '/resources/calibrate_factors.json'))

  # resource file modules
  include OsLib_HelperMethods
  include OsLib_ModelGeneration

  # human readable name
  def name
    return 'Calibrate Baseline Model'
  end

  # human readable description
  def description
    return 'This measure is used to calibrate the BRICR baseline model.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure is used to calibrate the BRICR baseline model.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    # see if building name contains any template values

    # Make argument for template
    template = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('template', get_templates, true)
    template.setDisplayName('Target Standard')
    template.setDefaultValue('CEC T24 2008')
    args << template

    # Make an argument for the bldg_type_a
    bldg_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('bldg_type', get_building_types, true)
    bldg_type.setDisplayName('Primary Building Type')
    bldg_type.setDefaultValue('MediumOffice')
    args << bldg_type

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    template = runner.getStringArgumentValue("template",user_arguments)
    bldg_type = runner.getStringArgumentValue("bldg_type",user_arguments)

    lpd_change_rate = @@calibrate_factors[template][bldg_type]['lpd_change_rate']
    epd_change_rate = @@calibrate_factors[template][bldg_type]['epd_change_rate']
    occupant_density_change_rate = @@calibrate_factors[template][bldg_type]['occupant_density_change_rate']
    cop_change_rate = @@calibrate_factors[template][bldg_type]['cop_change_rate']
    heating_efficiency_change_rate = @@calibrate_factors[template][bldg_type]['heating_efficiency_change_rate']

    #setup OpenStudio units that we will need
    unit_lpd_si = OpenStudio::createUnit("W/m^2").get

    #report initial condition
    building = model.getBuilding
    building_start_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    building_start_epd_si = OpenStudio::Quantity.new(building.electricEquipmentPowerPerFloorArea, unit_lpd_si)
    building_start_occupancy_si = building.peoplePerFloorArea # people/m^2

    initial_condition = "The model's template: #{template}, building type: #{bldg_type},"
    initial_condition += "lpd_change_rate: #{lpd_change_rate},"
    initial_condition += "epd_change_rate: #{epd_change_rate},"
    initial_condition += "occupant_density_change_rate: #{occupant_density_change_rate},"
    initial_condition += "cop_change_rate: #{cop_change_rate},"
    initial_condition += "heating_efficiency_change_rate: #{heating_efficiency_change_rate},"
    initial_condition += "initial LPD: #{building_start_lpd_si} #{unit_lpd_si},"
    initial_condition += "initial EPD: #{building_start_epd_si} #{unit_lpd_si}."
    initial_condition += "initial Occupancy: #{building_start_occupancy_si} people/m^2."

    runner.registerInitialCondition(initial_condition)

    space_types = model.getSpaceTypes
    # loop through space types
    space_types.each do |space_type|
      # Update lighting power density
      space_type.lights.each do |light|
        light_def = light.lightsDefinition
        unless light_def.lightingLevel.empty?
          light_def.setLightingLevel((1 + lpd_change_rate) * light_def.lightingLevel.get)
        end

        unless light_def.wattsperSpaceFloorArea .empty?
          light_def.setWattsperSpaceFloorArea((1 + lpd_change_rate) * light_def.wattsperSpaceFloorArea.get)
        end

        unless light_def.wattsperPerson.empty?
          light_def.setWattsperPerson((1 + lpd_change_rate) * light_def.wattsperPerson.get)
        end
      end

      # Update the equipment power density
      space_type.electricEquipment .each do |equip|
        equip_def = equip.electricEquipmentDefinition
        unless equip_def.designLevel.empty?
          equip_def.setDesignLevel((1 + epd_change_rate) * equip_def.designLevel.get)
        end

        unless equip_def.wattsperSpaceFloorArea .empty?
          equip_def.setWattsperSpaceFloorArea((1 + epd_change_rate) * equip_def.wattsperSpaceFloorArea.get)
        end

        unless equip_def.wattsperPerson.empty?
          equip_def.setWattsperPerson((1 + epd_change_rate) * equip_def.wattsperPerson.get)
        end
      end

      # Update the occupancy density
      space_type.people.each do |people|
        people_def = people.peopleDefinition
        unless people_def.numberofPeople.empty?
          people_def.setNumberofPeople((1 + occupant_density_change_rate) * people_def.numberofPeople.get)
        end

        unless people_def.peopleperSpaceFloorArea.empty?
          people_def.setPeopleperSpaceFloorArea((1 + occupant_density_change_rate) * people_def.peopleperSpaceFloorArea.get)
        end

        unless people_def.spaceFloorAreaperPerson.empty?
          people_def.setSpaceFloorAreaperPerson(people_def.spaceFloorAreaperPerson.get/(1 + occupant_density_change_rate))
        end
      end
    end

    # Update HVAC systems
    air_loops = model.getAirLoopHVACs


    # loop through air loops
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents

      find_cooling = false
      find_heating = false

      # find single speed dx units on loop
      supply_components.each do |supply_component|
        hvac_component = supply_component.to_CoilCoolingDXSingleSpeed
        unless hvac_component.empty?
          hvac_component = hvac_component.get

          # change and report high speed cop
          initial_cop = hvac_component.ratedCOP
          if initial_cop.empty?
            raise "Fail to find the Rated COP for single speed dx unit '#{hvac_component.name}' on air loop '#{air_loop.name}'"
          else
            after_cop = initial_cop.get * (1 + cop_change_rate)
            runner.registerInfo("Changing the Rated COP from #{initial_cop.get} to #{after_cop} for single speed dx unit '#{hvac_component.name}' on air loop '#{air_loop.name}'")
            double_after_cop = OpenStudio::OptionalDouble.new(after_cop)
            hvac_component.setRatedCOP(double_after_cop)
            find_cooling = true
          end
        end

        hvac_component = supply_component.to_CoilHeatingGas
        unless hvac_component.empty?
          hvac_component = hvac_component.get

          # change and report high speed eff
          initial_eff = hvac_component.gasBurnerEfficiency
          eff = initial_eff * (1 + heating_efficiency_change_rate)
          # check the user_name for reasonableness
          if eff <= 0 or eff > 0.99
            runner.registerError("Wromg burner efficiency of #{eff}.")
            return false
          end

          runner.registerInfo("Changing the burner efficiency from #{initial_eff} to #{eff} for gas heating units '#{hvac_component.name}' on air loop '#{air_loop.name}'")
          hvac_component.setGasBurnerEfficiency(eff)
          find_heating = true
        end
      end

      raise "Fail to find the cooling system for air lop '#{air_loop.name}'" unless find_cooling
      raise "Fail to find the heating system for air lop '#{air_loop.name}'" unless find_heating
    end

    # report final condition
    building_final_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    building_final_epd_si = OpenStudio::Quantity.new(building.electricEquipmentPowerPerFloorArea, unit_lpd_si)
    building_finish_occupancy_si = building.peoplePerFloorArea # people/m^2

    finish_condition = "Your model's final LPD: #{building_final_lpd_si} #{unit_lpd_si}, "
    finish_condition += "EPD: #{building_final_epd_si} #{unit_lpd_si}, "
    finish_condition += "Occupancy: #{building_finish_occupancy_si} people/m^2."

    runner.registerFinalCondition(finish_condition)

    return true
  end
end

# register the measure to be used by the application
CalibrateBaselineModel.new.registerWithApplication
