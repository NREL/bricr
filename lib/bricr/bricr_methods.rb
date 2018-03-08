require 'parallel'
require 'open3'


module BRICR

  # command is an array
  def self.bricr_run_command(command)
  
    # blank out bundler and gem path modifications, will be re-setup by new call
    new_env = {}
    new_env["BUNDLER_ORIG_MANPATH"] = nil
    new_env["GEM_PATH"] = nil
    new_env["GEM_HOME"] = nil
    new_env["BUNDLER_ORIG_PATH"] = nil
    new_env["BUNDLER_VERSION"] = nil
    new_env["BUNDLE_BIN_PATH"] = nil
    new_env["BUNDLE_GEMFILE"] = nil
    new_env["RUBYLIB"] = nil
    new_env["RUBYOPT"] = nil
  
    Open3.popen3(new_env, *command) do |stdin, stdout, stderr, wait_thr|
      # calling wait_thr.value blocks until command is complete
      if wait_thr.value.success?
        puts "Command completed successfully"
        #puts "stdout: #{stdout.read}"
        #puts "stderr: #{stderr.read}"
        return true
      else
        puts "Error running command: '#{command.join(' ')}'"
        puts "stdout: #{stdout.read}"
        puts "stderr: #{stderr.read}"
        return false
      end
    end
    
    return false
  end
  
  # xml_path is the path to a BSXML to run
  # path to a modified result BSXML is returned
  # exceptions are thrown on simulation error
  def self.run_buildingsync(xml_path)
      
    if defined?(BRICR::SIMULATION_OUTPUT_FOLDER) && BRICR::SIMULATION_OUTPUT_FOLDER
      unless BRICR::SIMULATION_OUTPUT_FOLDER
        FileUtils.mkdir_p(BRICR::SIMULATION_OUTPUT_FOLDER)
      end
      out_dir = File.join(BRICR::SIMULATION_OUTPUT_FOLDER, File.basename(xml_path, '.*') + '/')
    else
      out_dir = File.join(File.dirname(xml_path), File.basename(xml_path, '.*') + '/')
    end

    if BRICR::DO_SIMULATIONS
      if File.exist?(out_dir)
        FileUtils.rm_rf(out_dir)
      end
    end
    FileUtils.mkdir_p(out_dir)

    bs = BRICR::BuildingSync.new(xml_path)
    custom_id = bs.customId

    if !custom_id
      raise "BuildingSync file at '#{xml_path}' does not have a Custom ID defined"
    end

    translator = BRICR::Translator.new(xml_path)
    translator.writeOSWs(out_dir)
    osw_files = []
    Dir.glob("#{out_dir}/**/*.osw") { |osw| osw_files << osw }

    failures = []
    if BRICR::DO_SIMULATIONS
      num_sims = 0
      Parallel.each(osw_files, in_threads: BRICR::NUM_PARALLEL) do |osw|
      #osw_files.each do |osw|
      
        gem_path = ENV['GEM_PATH']
        
        # use system call or popen3
        # DLM: using popen3 here seems to result in deadlocks
        system_call = true
        
        result = nil
        if system_call
        
          out_log = osw + '.log'
          
          if Gem.win_platform?
            out_log = "nul"
          else
            out_log = "/dev/null"
          end
        
          cmd = nil
          if gem_path.nil?
            cmd = "\"#{BRICR::OPENSTUDIO_EXE}\" run -w \"#{osw}\" 2>&1 > \"#{out_log}\""
          else
            cmd = "\"#{BRICR::OPENSTUDIO_EXE}\" --gem_path \"#{gem_path}\" run -w \"#{osw}\" 2>&1 > \"#{out_log}\""
          end
          puts "Running cmd: #{cmd}\n"
          result = system(cmd)
            
        else
          
          command = nil
          if gem_path.nil?
            command = [BRICR::OPENSTUDIO_EXE, 'run', '-w', osw]
          else
            command = [BRICR::OPENSTUDIO_EXE, '--gem_path', gem_path, 'run', '-w', osw]
          end
          puts "Running '#{command.join(' ')}'"
          
          # bricr_run_command blanks out the environment
          result = BRICR.bricr_run_command(command)
          
          #Open3.popen3(*command) do |stdin, stdout, stderr, wait_thr|
          #  # calling wait_thr.value blocks until command is complete
          #  if wait_thr.value.success?
          #    #puts "Command completed successfully"
          #    #puts "stdout: #{stdout.read}"
          #    #puts "stderr: #{stderr.read}"
          #    result = true
          #  else
          #    puts "Error running command: '#{command.join(' ')}'"
          #    puts "stdout: #{stdout.read}"
          #    puts "stderr: #{stderr.read}"
          #    result = false
          #  end
          #end

        end

        if !result
          failures << "Failed to run the simulation with command: #{command}"
        end

        num_sims += 1
      end
    end

    if failures.size > 0
      failures.each {|failure| puts failure}
      raise "#{failures.size} simulations failed to run"
    end

    out_file = nil
    if BRICR::DO_GET_RESULTS
      # Read the results from the out.osw file
      translator.gatherResults(out_dir)
      
      out_file = File.join(out_dir, 'results.xml')

      # Save the results back to the BuildingSync file
      translator.saveXML(out_file)
      
      puts "Results saved to '#{out_file}'"
    end
    
    return out_file
  end

end