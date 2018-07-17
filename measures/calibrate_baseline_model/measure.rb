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
    template.setDefaultValue('CBES T24 2008')
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
    occupancy_change_rate = @@calibrate_factors[template][bldg_type]['occupancy_change_rate']
    cop_change_rate = @@calibrate_factors[template][bldg_type]['cop_change_rate']
    heating_efficiency_change_rate = @@calibrate_factors[template][bldg_type]['heating_efficiency_change_rate']

    #report initial condition
    building = model.getBuilding
    initial_lpd = building.lightingPowerPerFloorArea # W/m^2
    initial_epd = building.electricEquipmentPowerPerFloorArea # W/m^2
    initial_occupancy = building.peoplePerFloorArea # people/m^2

    runner.registerValue('lpd_change_rate', lpd_change_rate.to_s)
    runner.registerValue('epd_change_rate', epd_change_rate.to_s)
    runner.registerValue('occupancy_change_rate', occupancy_change_rate.to_s)
    runner.registerValue('cop_change_rate', cop_change_rate.to_s)
    runner.registerValue('heating_efficiency_change_rate', heating_efficiency_change_rate.to_s)
    runner.registerValue('initial_lpd', initial_lpd.round(3).to_s)
    runner.registerValue('initial_epd', initial_epd.round(3).to_s)
    runner.registerValue('initial_occupancy', initial_occupancy.round(3).to_s)

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
          people_def.setNumberofPeople((1 + occupancy_change_rate) * people_def.numberofPeople.get)
        end

        unless people_def.peopleperSpaceFloorArea.empty?
          people_def.setPeopleperSpaceFloorArea((1 + occupancy_change_rate) * people_def.peopleperSpaceFloorArea.get)
        end

        unless people_def.spaceFloorAreaperPerson.empty?
          people_def.setSpaceFloorAreaperPerson(people_def.spaceFloorAreaperPerson.get/(1 + occupancy_change_rate))
        end
      end
    end

    # Update HVAC systems
    air_loops = model.getAirLoopHVACs

    initial_cop_value = nil
    after_cop_value = nil
    double_after_cop = nil

    initial_eff_value = nil
    after_eff_value = nil

    # loop through air loops
    air_loops.each do |air_loop|
      find_cooling = false
      find_heating = false

      # find single speed dx units on loop
      air_loop.supplyComponents.each do |supply_component|
        hvac_component = supply_component.to_CoilCoolingDXSingleSpeed
        unless hvac_component.empty?
          hvac_component = hvac_component.get

          # change and report high speed cop
          initial_cop = hvac_component.ratedCOP
          if initial_cop.empty?
            raise "Fail to find the Rated COP for single speed dx unit '#{hvac_component.name}' on air loop '#{air_loop.name}'"
          else
            if initial_cop_value.nil?
              initial_cop_value = initial_cop.get
              after_cop_value = initial_cop_value * (1 + cop_change_rate)
              double_after_cop = OpenStudio::OptionalDouble.new(after_cop_value)
            elsif initial_cop_value != initial_cop.get
              raise "Multiple cop values are found: #{initial_cop_value} and #{initial_cop.get}"
            end

            hvac_component.setRatedCOP(double_after_cop)
            find_cooling = true
          end
        end

        hvac_component = supply_component.to_CoilCoolingDXTwoSpeed
        unless hvac_component.empty?
          hvac_component = hvac_component.get

          # change and report high speed cop
          initial_cop = hvac_component.ratedHighSpeedCOP
          if initial_cop.empty?
            raise "Fail to find the Rated High Speed COP for two speed dx unit '#{hvac_component.name}' on air loop '#{air_loop.name}'"
          else
            if initial_cop_value.nil?
              initial_cop_value = initial_cop.get
              after_cop_value = initial_cop_value * (1 + cop_change_rate)
              double_after_cop = OpenStudio::OptionalDouble.new(after_cop_value)
            elsif initial_cop_value != initial_cop.get
              raise "Multiple cop values are found: #{initial_cop_value} and #{initial_cop.get}"
            end
            hvac_component.setRatedHighSpeedCOP(double_after_cop)
          end

          # change and report low speed cop
          initial_cop = hvac_component.ratedLowSpeedCOP
          if initial_cop.empty?
            raise "Fail to find the Rated Low Speed COP for two speed dx unit '#{hvac_component.name}' on air loop '#{air_loop.name}'"
          else
            if initial_cop_value.nil?
              initial_cop_value = initial_cop.get
              after_cop_value = initial_cop_value * (1 + cop_change_rate)
              double_after_cop = OpenStudio::OptionalDouble.new(after_cop_value)
            elsif initial_cop_value != initial_cop.get
              raise "Multiple cop values are found: #{initial_cop_value} and #{initial_cop.get}"
            end
            hvac_component.setRatedLowSpeedCOP(double_after_cop)
          end

          find_cooling = true
        end

        hvac_component = supply_component.to_CoilHeatingGas
        unless hvac_component.empty?
          hvac_component = hvac_component.get

          if initial_eff_value.nil?
            initial_eff_value = hvac_component.gasBurnerEfficiency
            after_eff_value = initial_eff_value *  (1 + heating_efficiency_change_rate)
            # check the user_name for reasonableness
            if after_eff_value <= 0 or after_eff_value > 0.99
              raise "Wrong after heating efficiency found: initial (#{initial_eff_value}), change rate (#{heating_efficiency_change_rate}), after (#{after_eff_value})."
            end
          elsif initial_eff_value != hvac_component.gasBurnerEfficiency
            raise "Multiple heating efficiency values are found: #{initial_eff_value} and #{hvac_component.gasBurnerEfficiency}"
          end

          hvac_component.setGasBurnerEfficiency(after_eff_value)
          find_heating = true
        end
      end

      raise "Fail to find the cooling system for air lop '#{air_loop.name}'" unless find_cooling
      raise "Fail to find the heating system for air lop '#{air_loop.name}'" unless find_heating
    end

    runner.registerValue('initial_cop', initial_cop_value.round(3).to_s)
    runner.registerValue('after_cop', after_cop_value.round(3).to_s)
    runner.registerValue('initial_eff', initial_eff_value.round(3).to_s)
    runner.registerValue('after_eff', after_eff_value.round(3).to_s)

    # report final condition
    after_lpd = building.lightingPowerPerFloorArea
    after_epd = building.electricEquipmentPowerPerFloorArea
    after_occupancy = building.peoplePerFloorArea # people/m^2

    runner.registerValue('after_lpd', after_lpd.round(3).to_s)
    runner.registerValue('after_epd', after_epd.round(3).to_s)
    runner.registerValue('after_occupancy', after_occupancy.round(3).to_s)

    return true
  end
end

# register the measure to be used by the application
CalibrateBaselineModel.new.registerWithApplication
