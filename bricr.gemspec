lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'bricr/version'

Gem::Specification.new do |s|
  s.name = 'bricr'
  s.version = BRICR::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Daniel Macumber','Yixing Chen','Sang Hoon Lee']
  s.email = ['daniel.macumber@nrel.gov']
  s.summary = 'BRICR Tools'
  s.description = 'Translate BuildingSync to OpenStudio for BRICR'
  s.homepage = 'https://github.com/NREL/bricr'
  s.license = 'BSD'
 
  s.required_ruby_version = '~> 2.2'

  s.files = Dir.glob('lib/**/*') + Dir.glob('bin/**/*') + %w[README.md COPYRIGHT.md LICENSE.md Rakefile]
  s.require_path = 'lib'
  s.bindir = 'bin'
  s.executables << 'run_buildingsync.rb'
  s.executables << 'run_multiple_buildingsyncs.rb'
  s.executables << 'run_seed_buildingsyncs.rb'
  s.executables << 'update_seed_analysis_state.rb'
  s.executables << 'upload_seed_buildingsync.rb'
  s.executables << 'upload_seed_buildingsyncs.rb'

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_runtime_dependency  'parallel', '~> 1.12'
  s.add_runtime_dependency  'seed_ruby_client'
  s.add_runtime_dependency  'openstudio-extension'
  s.add_runtime_dependency  'openstudio-standards'
  s.add_runtime_dependency  'openstudio-workflow'
  s.add_runtime_dependency  'openstudio-common-measures'
  s.add_runtime_dependency  'openstudio-model-articulation'
  s.add_runtime_dependency 'json_pure'
end
