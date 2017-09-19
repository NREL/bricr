class OpenStudio::Model::Model

  # Adds the HVAC system as derived from the combinations of
  # CBECS 2012 MAINHT and MAINCL fields.
  # Mapping between combinations and HVAC systems per
  # http://www.nrel.gov/docs/fy08osti/41956.pdf
  # Table C-31
  def add_cbecs_hvac_system(template, system_type, zones)

    case system_type
    when 'PTAC with hot water heat'
      add_hvac_system(template, 'PTAC', ht='NaturalGas', znht=nil, cl='Electricity', zones)

    when 'PTAC with gas coil heat'
      add_hvac_system(template, 'PTAC', ht=nil, znht='NaturalGas', cl='Electricity', zones)

    when 'PTAC with electric baseboard heat'
      add_hvac_system(template, 'PTAC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'PTAC with no heat'
      add_hvac_system(template, 'PTAC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'PTAC with district hot water heat'
      add_hvac_system(template, 'PTAC', ht='DistrictHeating', znht=nil, cl='Electricity', zones)

    when 'PTHP'
      add_hvac_system(template, 'PTHP', ht='Electricity', znht=nil, cl='Electricity', zones)

    when 'PSZ-AC with gas coil heat'
      add_hvac_system(template, 'PSZ-AC', ht='NaturalGas', znht=nil, cl='Electricity', zones)

    when 'PSZ-AC with electric baseboard heat'
      add_hvac_system(template, 'PSZ-AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'PSZ-AC with no heat'
      add_hvac_system(template, 'PSZ-AC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'PSZ-AC with district hot water heat'
      add_hvac_system(template, 'PSZ-AC', ht='DistrictHeating', znht=nil, cl='Electricity', zones)

    when 'PSZ-HP'
      add_hvac_system(template, 'PSZ-HP', ht='Electricity', znht=nil, cl='Electricity', zones)

    when 'Fan coil district chilled water with no heat'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='DistrictCooling', zones)

    when 'Fan coil district chilled water and boiler'
      add_hvac_system(template, 'Fan Coil', ht='NaturalGas', znht=nil, cl='DistrictCooling', zones)

    when 'Fan coil district chilled water unit heaters'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='DistrictCooling', zones)
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Fan coil district chilled water electric baseboard heat'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='DistrictCooling', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'Fan coil district hot and chilled water'
      add_hvac_system(template, 'Fan Coil', ht='DistrictHeating', znht=nil, cl='DistrictCooling', zones)

    when 'Fan coil district hot water and chiller'
      add_hvac_system(template, 'Fan Coil', ht='DistrictHeating', znht=nil, cl='Electricity', zones)

    when 'Fan coil chiller with no heat'
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Baseboard district hot water heat'
      add_hvac_system(template, 'Baseboards', ht='DistrictHeating', znht=nil, cl=nil, zones)

    when 'Baseboard district hot water heat with direct evap coolers'
      add_hvac_system(template, 'Baseboards', ht='DistrictHeating', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Baseboard electric heat'
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'Baseboard electric heat with direct evap coolers'
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Baseboard hot water heat'
      add_hvac_system(template, 'Baseboards', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Baseboard hot water heat with direct evap coolers'
      add_hvac_system(template, 'Baseboards', ht='NaturalGas', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Window AC with no heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Window AC with forced air furnace'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Forced Air Furnace', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Window AC with district hot water baseboard heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='DistrictHeating', znht=nil, cl=nil, zones)

    when 'Window AC with hot water baseboard heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Window AC with electric baseboard heat'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'Window AC with unit heaters'
      add_hvac_system(template, 'Window AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Direct evap coolers'
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Direct evap coolers with unit heaters'
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Unit heaters'
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Heat pump heat with no cooling'
      add_hvac_system(template, 'Residential Air Source Heat Pump', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Heat pump heat with direct evap cooler'
      # add_hvac_system(template, 'Residential Air Source Heat Pump', ht=nil, znht=nil, cl='Electricity', zones)
      # Using PTHP to represent zone heat pump for this configuration
      # because only one airloop may be connected to each thermal zone.
      add_hvac_system(template, 'PTHP', ht='Electricity', znht=nil, cl='Electricity', zones)
      # disable the cooling coils in all the PTHPs
      getZoneHVACPackagedTerminalHeatPumps.each do |pthp|
        clg_coil = pthp.heatingCoil.to_CoilHeatingDXSingleSpeed.get
        clg_coil.setAvailabilitySchedule(alwaysOffDiscreteSchedule)
      end
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'VAV with reheat'
      add_hvac_system(template, 'VAV Reheat', ht='NaturalGas', znht='NaturalGas', cl='Electricity', zones)

    when 'VAV with PFP boxes'
      add_hvac_system(template, 'VAV PFP Boxes', ht='NaturalGas', znht='NaturalGas', cl='Electricity', zones)

    when 'VAV with gas reheat'
      add_hvac_system(template, 'VAV Gas Reheat', ht='NaturalGas', ht='NaturalGas', cl='Electricity', zones)

    when 'VAV with zone unit heaters'
      add_hvac_system(template, 'VAV No Reheat', ht='NaturalGas', znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'VAV with electric baseboard heat'
      add_hvac_system(template, 'VAV No Reheat', ht='NaturalGas', znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    when 'VAV cool with zone heat pump heat'
      add_hvac_system(template, 'VAV No Reheat', ht='NaturalGas', znht=nil, cl='Electricity', zones)
      # add_hvac_system(template, 'Residential Air Source Heat Pump', ht=nil, znht=nil, cl='Electricity', zones)
      # Using PTHP to represent zone heat pump for this configuration
      # because only one airloop may be connected to each thermal zone.
      add_hvac_system(template, 'PTHP', ht='Electricity', znht=nil, cl='Electricity', zones)
      # disable the cooling coils in all the PTHPs
      getZoneHVACPackagedTerminalHeatPumps.each do |pthp|
        clg_coil = pthp.heatingCoil.to_CoilHeatingDXSingleSpeed.get
        clg_coil.setAvailabilitySchedule(alwaysOffDiscreteSchedule)
      end

    when 'PVAV with reheat', 'Packaged VAV Air Loop with Boiler' # second enumeration for backwards compatibility with Tenant Star project
      add_hvac_system(template, 'PVAV Reheat', ht='NaturalGas', znht='NaturalGas', cl='Electricity', zones)

    when 'PVAV with PFP boxes'
      add_hvac_system(template, 'PVAV PFP Boxes', ht='Electricity', znht='Electricity', cl='Electricity', zones)

    when 'Residential forced air'
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Residential forced air cooling hot water baseboard heat'
      add_hvac_system(template, 'Residential AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Residential forced air with district hot water'
      add_hvac_system(template, 'Residential AC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Residential heat pump'
      add_hvac_system(template, 'Residential Air Source Heat Pump', ht='Electricity', znht=nil, cl='Electricity', zones)

    when 'Forced air furnace'
      add_hvac_system(template, 'Forced Air Furnace', ht='NaturalGas', znht=nil, cl=nil, zones)

    when 'Forced air furnace district chilled water fan coil'
      add_hvac_system(template, 'Forced Air Furnace', ht='NaturalGas', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Fan Coil', ht=nil, znht=nil, cl='DistrictCooling', zones)

    when 'Forced air furnace direct evap cooler'
      # add_hvac_system(template, 'Forced Air Furnace', ht='NaturalGas', znht=nil, cl=nil, zones)
      # Using unit heater to represent forced air furnace for this configuration
      # because only one airloop may be connected to each thermal zone.
      add_hvac_system(template, 'Unit Heaters', ht='NaturalGas', znht=nil, cl=nil, zones)
      add_hvac_system(template, 'Evaporative Cooler', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Residential AC with no heat'
      add_hvac_system(template, 'Residential AC', ht=nil, znht=nil, cl='Electricity', zones)

    when 'Residential AC with electric baseboard heat'    
      add_hvac_system(template, 'Residential AC', ht=nil, znht=nil, cl='Electricity', zones)
      add_hvac_system(template, 'Baseboards', ht='Electricity', znht=nil, cl=nil, zones)

    else
      puts "HVAC system type '#{system_type}' not recognized"

    end

  end

end
