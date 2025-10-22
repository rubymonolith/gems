require_relative "lib/monolith/version"

Gem::Specification.new do |spec|
  spec.name        = "rubymonolith"
  spec.version     = Monolith::VERSION
  spec.authors     = ["Brad Gessler"]
  spec.email       = ["bradgessler@gmail.com"]
  spec.homepage    = "https://rubymonolith.org/"
  spec.summary     = "CLI used to create Rails monoliths by Rocketship for quickly building applications."
  spec.description = spec.summary
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 2.6.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rubymonolith/gems"
  spec.metadata["changelog_uri"] = "https://github.com/rubymonolith/gems/tags"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib,exe}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rails", ">= 7.0.0"
  spec.add_dependency "thor", "~> 1.0"
end
