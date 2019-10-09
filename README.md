# BRICR Gem

[![Build Status](https://travis-ci.org/NREL/bricr.svg?branch=develop)](https://travis-ci.org/NREL/bricr)

## Prerequisites
In order to run the BRICR gem, OpenStudio and Ruby are required.  Follow the guidelines as specified in the [openstudio-extension-gem](https://github.com/NREL/openstudio-extension-gem#installation).  The following is added as additional helpful information based on troubles encountered.  It has been tested on Windows 10 installs:
1. The devkit link will download a zip file.  This needs to be extracted (doesn't matter where, can remain in Downloads).

    1. After extracting, edit the `config.yml` file, adding the drive location for where ruby is installed (likely as stated below).  Include the `-` at the beginning, as follows:

        ```
        # config.yml
        - C:/Ruby22-x64
        ```
    2. Then, run the devkit scripts:

        ```
        $ ruby dk.rb init
        $ ruby dk.rb install
        ```
1. If an error occurs on `gem install bundler -v 17.1`, try `gem install bundler -v 17.1.1`.  If you are getting an SSL error (`Unable to download data from https://rubygems.org/ - SSL_connect returned=1...`), try the following:

    1. Add a `.gemrc` file to your home directory (C:/Users/my_user/.gemrc) with the following:
        ```
        :sources:
        - http://rubygems.org
        :ssl_verify_mode: 0
        ```

1. You MUST use [OpenStudio-2.8.1](https://github.com/NREL/OpenStudio/releases/tag/v2.8.1)
1. Make sure when adding this file: `C:\ruby-2.2.4-x64-mingw32\lib\ruby\site_ruby\openstudio.rb`, you use the correct OpenStudio version, i.e. `require 'C:\openstudio-2.8.1\Ruby\openstudio.rb'`
1. Make sure to verify the OpenStudio and Ruby configuration.

If all the above steps completed successfully, you should be able to move onto Installation.

## Deployment & Installation

Follow this [dockerfile](https://github.com/NREL/docker-openstudio/blob/develop/Dockerfile), lines 36 - 80.  Additionally, add the following to the '.bashrc':
```
export RUBY_VERSION=2.2.4
export RUBY_SHA=6914d4f590
export RUBY_SHA=31203696adbfdda6f2874a2de31f7c5a1f3bcb6628f4d1a241de21b158cd5c76
export OS_BUNDLER_VERSION=1.17.1
export OPENSTUDIO_VERSION=2.8.1
export OPENSTUDIO_SHA=6914d4f590
export RUBY_SHA=b6eff568b48e0fda76e5a36333175df049b204e91217aa32a65153cc0cdcb761
```

Check to make sure correct Bundler version is installed:
```
sudo gem uninstall bundler
sudo gem install bundler -v 1.17.1
```

Clone this repo.

Configure locations to instance of SEED by copying `config.rb.in` to `config.rb` and updating.  The following fields need to be specified:
```ruby
  ENV['BRICR_SEED_HOST']
  ENV['BRICR_SEED_USERNAME']
  ENV['BRICR_SEED_API_KEY']
  
  ENV['BRICR_SEED_ORGANIZATION']
  ENV['BRICR_SEED_CYCLE']
  ENV['BRICR_SEED_SEARCH_PROFILE']
```
Changing these will allow you to run the scripts by pointing at different instances of SEED.

### Bundling
Due to the fact that there is a Ruby version included as part of the OpenStudio SDK, as well as a Ruby version used for the BRICR Gem, two Gemfiles are required to run the main analysis script (`monitor_seed.rb`).  The requirements from the two different Gemfiles must be installed separately as follows:
```ruby
bundle install --gemfile Gemfile --path .bundle/install # Gemfileused for OpenStudio
bundle install --gemfile Gemfile-bricr --path .bundle/install # Gemfile used for BRICR
```

## Usage
Service to monitor SEED, and basically perform the exact same thing as `run_seed_buildingsyncs.rb`.  Only difference is that this is an 'active server' type application, which pings seed every once in a while to see if new buildings have been uploaded.

- `nohup` tells the terminal not to hang up, even when the parent terminal is closed
- `&` tells the terminal to send the process to the background
```
$ BUNDLE_GEMFILE=Gemfile-bricr nohup bundle exec ruby ./bin/monitor_seed.rb ./config.rb &
```
___
___
### **CAUTION** - everything in this section has not been tested with two Gemfiles

To convert all geojson to buildingsync files.  Outputs will be added to ‘bs_output’ in root bricr dir
```
$ bundle exec geojson_to_buildingsync.rb ./data/my.geojson
```

Upload BuildingSync xml file (4.xml) to SEED (as specified in `config.rg`).  Defines the ‘Analysis State’ as not started.
```
$ bundle exec ruby bin/upload_seed_buildingsync.rb ./config.rb bs_output/4.xml 'Not Started’
```

Pulls from SEED all properties with 'Analysis State' == 'Not Started'.  Converts BuildingSync XML to an OS Model and creates OS Workflow.  Runs baseline simulation and measures / scenarios.  Converts back to BuildingSync XML and then reuploads to SEED, hopefully with an analysis state of 'Completed'.
```
$ bundle exec ruby ./bin/run_seed_buildingsyncs.rb ./config.rb
```
___
___

### Locally

Run all tests:

```
bundle exec rspec
```

Run a specific test (LINE = line number for the test):

```
bundle exec rspec spec\tests\translator_spec.rb:LINE
```

## Contributing

1. Fork it ( https://github.com/NREL/bricr/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
