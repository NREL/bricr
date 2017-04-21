# BRICR Gem

## Installation

Install dependencies:

```
bundle install
bundle update
```

## Usage

TBD 

## Testing

Configure locations to OpenStudio by copying `config.rb.in` to `config.rb` and updating.

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
