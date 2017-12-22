source 'http://rubygems.org'
ruby '~>2.2'

# Specify your gem's dependencies in bricr.gemspec
gemspec

gem 'parallel'
gem 'json'

gem 'seed_ruby_client', path: '../seed_ruby-client'
#gem 'seed_ruby_client', github: 'SEED-platform/ruby-client', branch: 'develop'

#gem 'openstudio-standards', path: '../openstudio-standards'
gem 'openstudio-standards', github: 'NREL/OpenStudio-standards', branch: 'BRICR_LBNL'

group :test do
  gem 'rake'
  # gem 'coveralls', require: false # requires json gem
  gem 'ruby-prof', '0.15.8'
  gem 'rspec', '~> 3.3'
  gem 'ci_reporter_rspec'
  gem 'rubocop'
  gem 'rubocop-checkstyle_formatter'
end
