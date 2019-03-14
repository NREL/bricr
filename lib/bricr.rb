########################################################################################################################
#  BRICR, Copyright (c) 2017, Alliance for Sustainable Energy, LLC and The Regents of the University of California, through Lawrence 
#  Berkeley National Laboratory (subject to receipt of any required approvals from the U.S. Dept. of Energy). All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions 
#  are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in 
#  the documentation and/or other materials provided with the distribution.
#
#  (3) The name of the copyright holder(s), any contributors, the United States Government, the United States Department of Energy, or 
#  any of their employees may not be used to endorse or promote products derived from this software without specific prior written 
#  permission from the respective party.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
#  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
#  THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR 
#  EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
#  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
#  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
########################################################################################################################

require_relative 'bricr/version'
require_relative 'bricr/bricr_methods'
require_relative 'bricr/building_sync'
#require_relative 'bricr/seed_methods'
require_relative 'bricr/translator'
require_relative 'bricr/workflow_maker'
require_relative 'bricr/workflows/phase_zero_workflow_maker'

require 'openstudio/extension'

module BRICR
  DIRECTORY = File.realpath(File.dirname(__FILE__)).freeze
  
  class Bricr < OpenStudio::Extension::Extension
    
    # Return the version of the OpenStudio Extension Gem
    def version
      BRICR::VERSION
    end

    # Base method
    # Return the absolute path of the measures or nil if there is none, can be used when configuring OSWs
    def measures_dir
      return File.absolute_path(File.join(root_dir, 'measures'))
    end
    
    # Base method
    # Return the absolute path of the measures resources dir or nil if there is none
    # Measure resources are library files which are copied into measure resource folders when building standalone measures
    # Measure resources will be copied into the resources folder for measures which have files of the same name
    # Measure resources are copied from dependent gems so file names must be unique across all gems
    def measure_resources_dir
      return nil
    end
    
    # Base method
    # Return the absolute path of the measures files dir or nil if there is none
    # Measure files are common files like copyright files which are used to update measures
    # Measure files will only be applied to measures in the current repository
    def measure_files_dir
      return nil
    end

    # Base method
    # Relevant files such as weather data, design days, etc.
    # return the absolute path of the files or nil if there is none, can be used when configuring OSWs
    def files_dir
      return File.absolute_path(File.join(root_dir, 'weather'))
    end
    
    # Base method
    # return the absolute path of root of this gem
    def root_dir
      return File.absolute_path(File.join(File.dirname(__FILE__), '../'))
    end

  end
end