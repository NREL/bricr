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
        #puts "Command completed successfully"
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

end