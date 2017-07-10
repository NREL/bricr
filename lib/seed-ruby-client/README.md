# SEED Ruby Client

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'seed-ruby-client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install seed-ruby-client

## Usage

It is recommended that you set your SEED username and password in the environment variables

```bash
export BRICR_SEED_USERNAME=user@domain.com
export BRICR_SEED_API_KEY=super-secret-key
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

