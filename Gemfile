source 'http://rubygems.org'
ruby '~>2.2'

# Specify your gem's dependencies in bricr.gemspec

allow_local_gems = false

if allow_local_gems && File.exists?('../openstudio-extension-gem')
  # gem 'openstudio-extension', github: 'NREL/openstudio-extension-gem', branch: 'develop'
  gem 'openstudio-extension', path: '../openstudio-extension-gem'
else
  gem 'openstudio-extension', github: 'NREL/openstudio-extension-gem', branch: 'develop'
end

if allow_local_gems && File.exists?('../openstudio-common-measures-gem')
  gem 'openstudio-common-measures', github: 'NREL/openstudio-common-measures-gem', branch: 'develop'
  #gem 'openstudio-common-measures', path: '../openstudio-common-measures-gem'
else
  gem 'openstudio-common-measures', github: 'NREL/openstudio-common-measures-gem', branch: 'develop'
end

if allow_local_gems && File.exists?('../openstudio-model-articulation-gem')
  gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', branch: 'develop'
  #gem 'openstudio-model-articulation', path: '../openstudio-model-articulation-gem'
else
  gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', branch: 'develop'
end

if allow_local_gems && File.exists?('../openstudio-standards-gem')
  gem 'openstudio-standards', '0.2.9'
  #gem 'openstudio-standards', path: '../openstudio-standards'
else
  gem 'openstudio-standards', '0.2.9'
end

# no specific version of workflow required
gem 'openstudio-workflow'

# simplecov has an unneccesary dependency on native json gem, use fork that does not require this
gem 'simplecov', github: 'NREL/simplecov'

