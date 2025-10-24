# Monolith

A quick way to spin up a [Monlithic Rails](https://rubymonolith.org) application. [Rocketship](https://rocketship.io/) uses Monolith when building new SaaS applications.

Monolith includes a Rails engine with development tools for inspecting your application:
- Email previews
- Database table browser
- Installed gems viewer
- Route inspector
- Model inspector
- Rails generators interface

The engine automatically mounts at `http://localhost:3000/monolith` in development mode.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ gem install rubymonolith

## Usage

Run the CLI utility to create a monolith:

    $ monolith new my-rad-project

Monolith creates a new Rails project with the dependencies needed to be productive.

## Existing Rails applications

Add to your Gemfile:

```ruby
gem 'rubymonolith'
```

Run `bundle install` and the engine automatically mounts at `http://localhost:3000/monolith` in development.

To see available generators, run `rails generate --help`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Tailwind CSS Development

The engine includes a pre-compiled Tailwind CSS file committed to the repo. When developing the gem:

```bash
bin/build                       # Build CSS once
rake monolith:tailwind:watch    # Watch and rebuild on changes
```

The engine uses Tailwind v4 with CSS-based configuration in `app/assets/stylesheets/monolith/application.tailwind.css`. The compiled CSS is committed so users don't need Tailwind installed.

### Releasing

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rubymonolith/monolith.
