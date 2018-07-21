# require 'simplecov'
# require 'coveralls'

# SimpleCov.formatter = Coveralls::SimpleCov::Formatter
# SimpleCov.start do
#  add_filter 'spec/files'
# end

# try to load configuration, use defaults if doesn't exist
begin
  require_relative '../config'
rescue LoadError, StandardError
  module BRICR
    # location of openstudio CLI
    OPENSTUDIO_EXE = 'openstudio'.freeze

    # one or more measure paths
    OPENSTUDIO_MEASURES = [].freeze

    # one or more file paths
    OPENSTUDIO_FILES = [].freeze

    # max number of datapoints to run
    MAX_DATAPOINTS = Float::INFINITY
    # MAX_DATAPOINTS = 2

    # number of parallel jobs
    NUM_PARALLEL = 7

    # do simulations
    DO_SIMULATIONS = false
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

  if File.exist? 'seed.json'
    puts "Found seed.json which contains the SEED user credentials, overriding environment variables"
    j = JSON.parse(File.read('seed.json'), symbolize_names: true)
    ENV['BRICR_SEED_HOST'] = j[:host]
    ENV['BRICR_SEED_USERNAME'] = j[:username]
    ENV['BRICR_SEED_API_KEY'] = j[:api_key]
  end
end
