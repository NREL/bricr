require 'simplecov'
require 'coveralls'

SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter 'spec/files'
end

# try to load configuration, use defaults if doesn't exist
begin
  require_relative '../config'
rescue LoadError
  module BRICR

    # location of openstudio CLI
    OPENSTUDIO_EXE = 'openstudio'
    
    # one or more measure paths
    OPENSTUDIO_MEASURES = []

    # one or more file paths
    OPENSTUDIO_FILES = []

    # max number of datapoints to run
    MAX_DATAPOINTS = Float::INFINITY
    #MAX_DATAPOINTS = 2
    
    # number of parallel jobs
    NUM_PARALLEL = 7
  end
end

# for all testing
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'bricr'

RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate
end
