require "thor"
require "monolith/version"

module Monolith
  class CLI < Thor
    include Thor::Actions

    DEFAULT_PATH = "server".freeze

    desc "new [PROJECT_NAME]", "create a new Rails monolith"
    def new(path = DEFAULT_PATH)
      template_path = File.join File.expand_path(__dir__), "cli/template.rb"
      run "rails new #{path} --template #{template_path} --css tailwind --skip-test --skip-system-test --skip-solid"
    end

    desc "version", "prints version of monolith"
    def version
      puts Monolith::VERSION
    end

    desc "server", "Runs a monolith application"
    def server
      puts Monolith::VERSION
    end
  end
end
