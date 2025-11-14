require "thor"
require "foreman"
require "foreman/engine"
require "foreman/engine/cli"
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

    desc "dev", "Runs a monolith application via Procfile.dev"
    def dev
      procfile = "Procfile.dev"

      unless File.exist?(procfile)
        puts "Error: #{procfile} not found in current directory"
        exit 1
      end

      engine = Foreman::Engine::CLI.new(procfile: procfile)
      engine.load_procfile(procfile)
      engine.start
    rescue Interrupt
      puts "\nShutting down..."
    end
  end
end
