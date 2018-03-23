# usage: bundle exec ruby run_buildingsync.rb /path/to/config.rb /path/to/buildingsync.xml

require 'bricr'

config_path = ARGV[0]
require(config_path)

xml_path = ARGV[1]
if xml_path.nil? || !File.exist?(xml_path)
  puts 'usage: bundle exec ruby run_buildingsync.rb /path/to/buildingsync.xml'
  exit(1)
end

BRICR.run_buildingsync(xml_path)
