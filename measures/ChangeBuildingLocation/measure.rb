# Authors : Nicholas Long, David Goldwasser
# Simple measure to load the EPW file and DDY file
require_relative 'resources/stat_file'
require_relative 'resources/epw'

class ChangeBuildingLocation < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    'ChangeBuildingLocation'
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    weather_file_name = OpenStudio::Ruleset::OSArgument.makeStringArgument('weather_file_name', true)
    weather_file_name.setDisplayName("Weather File Name")
    weather_file_name.setDescription("Name of the weather file to change to. This is the filename with the extension (e.g. NewWeather.epw). Optionally this can inclucde the full file path, but for most use cases should just be file name.")
    args << weather_file_name

    #make choice argument for climate zone
    choices = OpenStudio::StringVector.new
    choices << "1A"
    choices << "1B"
    choices << "2A"
    choices << "2B"
    choices << "3A"
    choices << "3B"
    choices << "3C"
    choices << "4A"
    choices << "4B"
    choices << "4C"
    choices << "5A"
    choices << "5B"
    choices << "5C"
    choices << "6A"
    choices << "6B"
    choices << "7"
    choices << "8"
    choices << "CEC1"
    choices << "CEC2"
    choices << "CEC3"
    choices << "CEC4"
    choices << "CEC5"
    choices << "CEC6"
    choices << "CEC7"
    choices << "CEC8"
    choices << "CEC9"
    choices << "CEC10"
    choices << "CEC11"
    choices << "CEC12"
    choices << "CEC13"
    choices << "CEC14"
    choices << "CEC15"
    choices << "CEC16"    
	choices << "Lookup From Stat File"
    climate_zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("climate_zone", choices,true)
    climate_zone.setDisplayName("Climate Zone.")
    climate_zone.setDefaultValue("Lookup From Stat File")
    args << climate_zone

    args
  end

  # Define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # create initial condition
    if not model.getWeatherFile.city == ''
      runner.registerInitialCondition("The initial weather file is #{model.getWeatherFile.city} and the model has #{model.getDesignDays.size} design day objects")
    else
      runner.registerInitialCondition("No weather file is set. The model has #{model.getDesignDays.size} design day objects")
    end

    # get variables
    weather_file_name = runner.getStringArgumentValue("weather_file_name", user_arguments)
    climate_zone = runner.getStringArgumentValue("climate_zone",user_arguments)

    # find weather file
    osw_file = runner.workflow.findFile(weather_file_name)
    if osw_file.is_initialized
      weather_file = osw_file.get.to_s
    else
      runner.registerError("Did not find #{weather_file_name} in paths described in OSW file.")
      return false
    end

    # Parse the EPW manually because OpenStudio can't handle multiyear weather files (or DATA PERIODS with YEARS)
    epw_file = OpenStudio::Weather::Epw.load(weather_file)

    weather_file = model.getWeatherFile
    weather_file.setCity(epw_file.city)
    weather_file.setStateProvinceRegion(epw_file.state)
    weather_file.setCountry(epw_file.country)
    weather_file.setDataSource(epw_file.data_type)
    weather_file.setWMONumber(epw_file.wmo.to_s)
    weather_file.setLatitude(epw_file.lat)
    weather_file.setLongitude(epw_file.lon)
    weather_file.setTimeZone(epw_file.gmt)
    weather_file.setElevation(epw_file.elevation)
    weather_file.setString(10, "file:///#{epw_file.filename}")

    weather_name = "#{epw_file.city}_#{epw_file.state}_#{epw_file.country}"
    weather_lat = epw_file.lat
    weather_lon = epw_file.lon
    weather_time = epw_file.gmt
    weather_elev = epw_file.elevation

    # Add or update site data
    site = model.getSite
    site.setName(weather_name)
    site.setLatitude(weather_lat)
    site.setLongitude(weather_lon)
    site.setTimeZone(weather_time)
    site.setElevation(weather_elev)

    runner.registerInfo("city is #{epw_file.city}. State is #{epw_file.state}")

	
    # Add SiteWaterMainsTemperature -- via parsing of STAT file.
    stat_file = "#{File.join(File.dirname(epw_file.filename), File.basename(epw_file.filename, '.*'))}.stat"
    unless File.exist? stat_file
      runner.registerInfo "Could not find STAT file by filename, looking in the directory"
      stat_files = Dir["#{File.dirname(epw_file.filename)}/*.stat"]
      if stat_files.size > 1
        runner.registerError("More than one stat file in the EPW directory")
        return false
      end
      if stat_files.size == 0
        runner.registerError("Cound not find the stat file in the EPW directory")
        return false
      end

      runner.registerInfo "Using STAT file: #{stat_files.first}"
      stat_file = stat_files.first
    end
    unless stat_file
      runner.registerError "Could not find stat file"
      return false
    end

    stat_model = EnergyPlus::StatFile.new(stat_file)
    water_temp = model.getSiteWaterMainsTemperature
    water_temp.setAnnualAverageOutdoorAirTemperature(stat_model.mean_dry_bulb)
    water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(stat_model.delta_dry_bulb)
    runner.registerInfo("mean dry bulb is #{stat_model.mean_dry_bulb}")

    # Remove all the Design Day objects that are in the file
    model.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each { |d| d.remove }

    # find the ddy files
    ddy_file = "#{File.join(File.dirname(epw_file.filename), File.basename(epw_file.filename, '.*'))}.ddy"
    unless File.exist? ddy_file
      ddy_files = Dir["#{File.dirname(epw_file.filename)}/*.ddy"]
      if ddy_files.size > 1
        runner.registerError("More than one ddy file in the EPW directory")
        return false
      end
      if ddy_files.size == 0
        runner.registerError("could not find the ddy file in the EPW directory")
        return false
      end

      ddy_file = ddy_files.first
    end

    unless ddy_file
      runner.registerError "Could not find DDY file for #{ddy_file}"
      return error
    end

    ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_file).get
    ddy_model.getObjectsByType("OS:SizingPeriod:DesignDay".to_IddObjectType).each do |d|
      # grab only the ones that matter
      ddy_list = /(Htg 99.6. Condns DB)|(Clg .4. Condns WB=>MDB)|(Clg .4% Condns DB=>MWB)/
      if d.name.get =~ ddy_list
        runner.registerInfo("Adding object #{d.name}")

        # add the object to the existing model
        model.addObject(d.clone)
      end
    end

    # Set climate zone
    climateZones = model.getClimateZones
    if climate_zone == "Lookup From Stat File"

      # get climate zone from stat file
      text = nil
      File.open(stat_file) do |f|
        text = f.read.force_encoding('iso-8859-1')
      end

      # Get Climate zone.
      # - Climate type "3B" (ASHRAE Standard 196-2006 Climate Zone)**
      # - Climate type "6A" (ASHRAE Standards 90.1-2004 and 90.2-2004 Climate Zone)**
      regex = /Climate type \"(.*?)\" \(ASHRAE Standards?(.*)\)\*\*/
      match_data = text.match(regex)
      if match_data.nil?
        runner.registerWarning("Can't find ASHRAE climate zone in stat file.")
      else
        climate_zone = match_data[1].to_s.strip
      end

    end
	
	# set climate zone
	if climate_zone == "1A" || climate_zone == "1B" || climate_zone == "2A" || climate_zone == "2B" || climate_zone == "3A" || climate_zone == "3B" || climate_zone == "3C" || climate_zone == "4A" || climate_zone == "4B" || climate_zone == "4C" || climate_zone == "5A" || climate_zone == "5B" || climate_zone == "5C" || climate_zone == "6A" || climate_zone == "6B" || climate_zone == "7" || climate_zone == "8"
    	climateZones.setClimateZone("ASHRAE",climate_zone)
		runner.registerInfo("Setting Climate Zone to #{climateZones.getClimateZones("ASHRAE").first.value}")
	else 
		climateZones.setClimateZone("CEC",climate_zone)
		runner.registerInfo("Setting Climate Zone to #{climate_zone}")
	end
    	
    # add final condition
    runner.registerFinalCondition("The final weather file is #{model.getWeatherFile.city} and the model has #{model.getDesignDays.size} design day objects.")

    true
  end
end

# This allows the measure to be use by the application
ChangeBuildingLocation.new.registerWithApplication