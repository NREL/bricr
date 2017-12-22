require 'bricr/version'
require 'bricr/bricr_methods'
require 'bricr/building_sync'
require 'bricr/seed_methods'
require 'bricr/translator'
require 'bricr/workflow_maker'
require 'bricr/workflows/phase_zero_workflow_maker'

module BRICR
  DIRECTORY = File.realpath(File.dirname(__FILE__)).freeze
end