require 'fileutils'
require 'json'

module BRICR
  # base class for objects that will configure workflows based on building sync files
  class WorkflowMaker
    def initialize(doc)
      @doc = doc
    end

    def writeOSWs(dir)
      FileUtils.mkdir_p(dir)
    end

    def gatherResults(dir); end

    def saveXML(filename)
      File.open(filename, 'w') do |file|
        @doc.write(file)
      end
    end

    def set_measure_argument(osw, measure_dir_name, argument_name, argument_value)
      result = false
      osw['steps'].each do |step|
        if step['measure_dir_name'] == measure_dir_name
          step['arguments'][argument_name] = argument_value
          result = true
        end
      end

      return result
    end
  end
end
