
require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class ChangeLightingScheduleBySpaceType_Test < Test::Unit::TestCase

  # Description of test models:
  
  # School_hvac.osm is a .
  # it has a 2 speed DX cooling coil on 1 airloop
  # test should result in a new condenser type for the 2 speed DX coil on "Air Loop HVAC 1" 

  def test_school_hvac
     
    # Create an instance of the measure
    measure = ChangeLightingScheduleBySpaceType.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/School_hvac.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)

    # Create an empty argument map (this measure has no arguments)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new    

    count = -1
    
    space_type_object = arguments[count += 1].clone
    assert(space_type_object.setValue("DOE Ref 2004 - PriSchl - Classroom"))
    argument_map["space_type_object"] = space_type_object

    schedule_object = arguments[count += 1].clone
    assert(schedule_object.setValue("New Lights Schedule"))
    argument_map["schedule_object"] = schedule_object

    cost_increase = arguments[count += 1].clone
    assert(cost_increase.setValue(5000))
    argument_map["cost_increase"] = cost_increase

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")

    # Make sure that schedules changed as expected
    # TODO: write this section
    
  end
 
end
