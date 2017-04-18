# BRICR Gem

## Installation

The BRICR Gem has the following dependencies:

* Ruby '> 2.0.0'
* OpenStudio '> 2.1.0'

Install dependencies:

```
bundle install
bundle update
```

## Usage

TBD 

## Testing

Configure locations to OpenStudio by copying `config.rb.in` to `config.rb` and updating.

The preferred way for testing is to run rspec either natively or via docker.

### Locally

```
bundle exec rspec spec/
```

## Contributing

1. Fork it ( https://github.com/NREL/bricr/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
