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

require 'bricr'
require 'rbconfig'
require 'parallel'

config_path = ARGV[0]
require(config_path)

xml_files = Dir.glob(File.join(ARGV[1], '*.xml'))

ruby_exe = File.join( RbConfig::CONFIG['bindir'], RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'] )
upload_seed_buildingsync_rb = File.join(File.dirname(__FILE__), "upload_seed_buildingsync.rb")

if xml_files.size > BRICR::MAX_DATAPOINTS
  xml_files = xml_files.slice(0, BRICR::MAX_DATAPOINTS)
end

uploaded = 0
failures = 0
Parallel.each(xml_files, in_threads: [BRICR::NUM_BUILDINGS_PARALLEL, BRICR::MAX_DATAPOINTS].min) do |xml_file|
#xml_files.each do |xml_file|

  uploaded += 1

  command = ['bundle', 'exec', ruby_exe, upload_seed_buildingsync_rb, ARGV[0], xml_file, 'Not Started']

  puts "Running '#{command.join(' ')}'"
  
  result = BRICR.bricr_run_command(command)

  if result
    puts "'#{xml_file}' completed successfully"     
  else
    puts "'#{xml_file}' failed"
    failures += 1
  end
  
end

puts "Attempted to upload #{uploaded} files"
puts "#{failures} failures"