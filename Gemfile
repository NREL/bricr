source 'http://rubygems.org'
ruby '~>2.2'

# Specify your gem's dependencies in bricr.gemspec
gemspec

group :openstudio_no_cli do
  #gem 'seed_ruby_client', path: '../ruby-client'
  gem 'seed_ruby_client', github: 'SEED-platform/ruby-client', branch: 'develop'
end

#gem 'openstudio-standards', path: '../openstudio-standards'
#gem 'openstudio-standards', github: 'NREL/OpenStudio-standards', branch: 'bricr'

gem 'openstudio-workflow'

if File.exists?('../OpenStudio-extension-gem')
  # gem 'openstudio-extension', github: 'NREL/OpenStudio-extension-gem', branch: 'develop'
  gem 'openstudio-extension', path: '../OpenStudio-extension-gem'
else
  gem 'openstudio-extension', github: 'NREL/OpenStudio-extension-gem', branch: 'develop'
end

if File.exists?('../openstudio-common-measures-gem')
  # gem 'openstudio-common-measures', github: 'NREL/openstudio-common-measures-gem', branch: 'develop'
  gem 'openstudio-common-measures', path: '../openstudio-common-measures-gem'
else
  gem 'openstudio-common-measures', github: 'NREL/openstudio-common-measures-gem', branch: 'develop'
end

if File.exists?('../openstudio-model-articulation-gem')
  # gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', branch: 'develop'
  gem 'openstudio-model-articulation', path: '../openstudio-model-articulation-gem'
else
  gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', branch: 'develop'
end

# simplecov has an unneccesary dependency on native json gem, use fork that does not require this
gem 'simplecov', github: 'NREL/simplecov'

group :test do
  gem 'rake'
  # gem 'coveralls', require: false # requires json gem
  # gem 'ruby-prof', '0.15.8'
  gem 'rspec', '~> 3.3'
  gem 'ci_reporter_rspec'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
