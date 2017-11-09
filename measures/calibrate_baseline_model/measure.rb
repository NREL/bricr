# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class CalibrateBaselineModel < OpenStudio::Ruleset::ModelUserScript

  require 'openstudio-standards'

  # require all .rb files in resources folder
  Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }

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

    #setup OpenStudio units that we will need
    unit_lpd_si = OpenStudio::createUnit("W/m^2").get

    #report initial condition
    building = model.getBuilding
    building_start_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    runner.registerInitialCondition("The model's template: #{template}, building type: #{bldg_type}, initial LPD: #{building_start_lpd_si} #{unit_lpd_si}.")

    space_types = model.getSpaceTypes
    #loop through space types
    space_types.each do |space_type|
      space_type.lights.each do |light|
        light_def = light.lightsDefinition
        unless light_def.lightingLevel.empty?
          light_def.setLightingLevel(0.5 * light_def.lightingLevel.get)
        end

        unless light_def.wattsperSpaceFloorArea .empty?
          light_def.setWattsperSpaceFloorArea(0.5 * light_def.wattsperSpaceFloorArea.get)
        end

        unless light_def.wattsperPerson.empty?
          light_def.setWattsperPerson(0.5 * light_def.wattsperPerson.get)
        end
      end
    end

    #report final condition
    building_final_lpd_si = OpenStudio::Quantity.new(building.lightingPowerPerFloorArea, unit_lpd_si)
    runner.registerFinalCondition("Your model's final LPD is #{building_final_lpd_si} #{unit_lpd_si}.")

    return true
  end
end

# register the measure to be used by the application
CalibrateBaselineModel.new.registerWithApplication
