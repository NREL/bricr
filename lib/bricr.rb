require 'bricr/version'
require 'bricr/building_sync'
require 'bricr/translator'
require 'bricr/workflow_maker'
require 'bricr/workflows/phase_zero_workflow_maker'

module BRICR
  DIRECTORY = File.realpath(File.dirname(__FILE__))
end