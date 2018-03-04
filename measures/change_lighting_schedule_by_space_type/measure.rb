#start the measure
class ChangeLightingScheduleBySpaceType < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see
  def name
    return "Change Lighting Schedule by SpaceType"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make arrays of space type names and handles
    space_type_handles = OpenStudio::StringVector.new
    space_type_display_names = OpenStudio::StringVector.new
    model.getSpaceTypes.each do |space_type|
      # Only include if space type is used in the model
      if space_type.spaces.size > 0
        space_type_handles << space_type.handle.to_s
        space_type_display_names << space_type.name.to_s
      end
    end
    
    # Make a choice argument for space type or entire building
    space_type_object = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space_type_object", space_type_handles, space_type_display_names,true)
    space_type_object.setDisplayName("Apply the Measure to a Specific Space Type")
    args << space_type_object
	
    # Make arrays of schedule names and handles
    schedule_handles = OpenStudio::StringVector.new
    schedule_display_names = OpenStudio::StringVector.new    
    model.getSchedules.each do |schedule|
      schedule_handles << schedule.handle.to_s
      schedule_display_names << schedule.name.to_s
    end
    
    # Make a choice argument for lighting schedule
    schedule_object = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("schedule_object", schedule_handles, schedule_display_names,true)
    schedule_object.setDisplayName("Replace the lighting schedule in the space type with the following schedule")
    args << schedule_object

    # Make an argument for material and installation cost
    cost_increase = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("cost_increase",true)
    cost_increase.setDisplayName("Increase in Material and Installation Costs ($).")
    cost_increase.setDefaultValue(0.0)
    args << cost_increase
    
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Assign the user inputs to variables
    space_type_object = runner.getOptionalWorkspaceObjectChoiceValue("space_type_object",user_arguments,model)
    schedule_object = runner.getOptionalWorkspaceObjectChoiceValue("schedule_object",user_arguments,model)
    cost_increase = runner.getDoubleArgumentValue("cost_increase",user_arguments)
    
    # Get the selected space type
    space_type = nil
    if space_type_object.is_initialized
      if space_type_object.get.to_SpaceType.is_initialized
        space_type = space_type_object.get.to_SpaceType.get
      else
        runner.registerError("Script Error - argument not showing up as space type.")
        return false
      end
    else
      handle = runner.getStringArgumentValue("space_type_object",user_arguments)
      if handle.empty?
        runner.registerError("No space type was chosen.")
      else
        runner.registerError("The selected space type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    end    

    # Get the selected schedule
    schedule = nil
    if schedule_object.is_initialized
      if schedule_object.get.to_Schedule.is_initialized
        schedule = schedule_object.get.to_Schedule.get
      else
        runner.registerError("Script Error - argument not showing up as schedule.")
        return false
      end
    else
      handle = runner.getStringArgumentValue("schedule_object",user_arguments)
      if handle.empty?
        runner.registerError("No schedule was chosen.")
      else
        runner.registerError("The selected schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    end 

    # Record how many lights currently use the selected schedule
    initial_lights_using_sch = []
    model.getLightss.each do |light|
      if light.schedule.is_initialized
        if light.schedule.get == schedule
          initial_lights_using_sch << light
        end
      end
    end
    runner.registerInitialCondition("Model has #{initial_lights_using_sch.size} lights with the schedule '#{schedule.name}'.")    
    
    # Get the lights from the selected space type
    # and then set the sch for them.
    modified_lights = []
    space_type.lights.each do |space_type_ltg|
      old_sch = space_type_ltg.schedule
      if old_sch.is_initialized
        old_sch = old_sch.get
        # Skip lights that already use this schedule
        next if old_sch == schedule
        # Set the lights schedule
        space_type_ltg.setSchedule(schedule)
        runner.registerInfo("Changed schedule for '#{space_type_ltg.name}' from '#{old_sch.name}' to '#{schedule.name}'.")
        modified_lights << space_type_ltg
      else
        # Set the lights schedule
        space_type_ltg.setSchedule(schedule)
        runner.registerInfo("Changed schedule for '#{space_type_ltg.name}' from no schedule to '#{schedule.name}'.")
        modified_lights << space_type_ltg      
      end
	  end
    
    # Get the lights that exist directly in spaces
    # of the selected space type and set their schedules.
    space_type.spaces.each do |space|
      space.lights.each do |space_ltg|
        old_sch = space_ltg.schedule
        if old_sch.is_initialized
          old_sch = old_sch.get
          # Skip lights that already use this schedule          
          next if old_sch == schedule
          # Set the lights schedule
          space_ltg.setSchedule(schedule)
          runner.registerInfo("Changed schedule for '#{space_ltg.name}' from '#{old_sch.name}' to '#{schedule.name}'.")
          modified_lights << space_ltg
        else
          # Set the lights schedule
          space_ltg.setSchedule(schedule)
          runner.registerInfo("Changed schedule for '#{space_ltg.name}' from no schedule to '#{schedule.name}'.")
          modified_lights << space_ltg
        end
      end
    end

    # Not Applicable if no lighting schedules were changed
    if modified_lights.size == 0
      runner.registerAsNotApplicable("Not Applicable - No lights had their schedules changed.")
      return true
    end    

    # Add the cost of the measure
    building = model.getBuilding
    lcc = OpenStudio::Model::LifeCycleCost.new(building)
    lcc.setCost(cost_increase)    
    
    # Record how many lights now use the selected schedule
    final_lights_using_sch = []
    model.getLightss.each do |light|
      if light.schedule.is_initialized
        if light.schedule.get == schedule
          final_lights_using_sch << light
        end
      end
    end
    runner.registerFinalCondition("#{modified_lights.size} lights were changed to use the schedule '#{schedule.name}' at a cost of $#{lcc.cost}.  Model now has #{final_lights_using_sch.size} lights with the schedule '#{schedule.name}'.")      
    
    
    return true
       
  end #end the run method

end #end the measure

#this allows the measure to be used by the application
ChangeLightingScheduleBySpaceType.new.registerWithApplication
