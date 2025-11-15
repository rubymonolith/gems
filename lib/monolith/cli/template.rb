# High-performance async web server built on fibers for better concurrency
gem "falcon"

# Remove puma (Rails default)
gsub_file "Gemfile", /^gem ["']puma["'].*$/, ""

after_bundle do
  # Remove Puma configuration file
  remove_file "config/puma.rb"
end

# Fast, object-oriented view components as an alternative to ERB templates
gem "phlex-rails"

after_bundle do
  generate "phlex:install"
end

# Phlex components for views in controllers
gem "superview"

# A better way to handle forms with Phlex components
gem "superform"

after_bundle do
  generate "superform:install"
end

# Component-based email templates using Phlex
gem "supermail"

after_bundle do
  generate "supermail:install"
end

after_bundle do
  # Install DaisyUI and Tailwind plugins
  run "npm init -y"
  run "npm install daisyui@latest @tailwindcss/typography@latest"

  # Add node_modules to .gitignore
  append_to_file '.gitignore', <<~GITIGNORE

    # Node modules
    /node_modules/*
  GITIGNORE

  # Add sources and plugins to Tailwind CSS
  append_to_file 'app/assets/tailwind/application.css', <<~CSS

    @source "app/content/**/*";
    @source "app/components/**/*";
    @source "app/views/**/*";
    @source "app/controllers/**/*";
    @source "lib/**/*";

    @plugin "@tailwindcss/typography";
    @plugin "daisyui";
  CSS

  # Add Superview and Superform includes to ApplicationController
  inject_into_class "app/controllers/application_controller.rb", "ApplicationController", <<~RUBY
    include Superview::Actions
    include Superform::Rails::StrongParameters
  RUBY
end

# File-based content management system for static pages and markdown content
gem "sitepress-rails"

after_bundle do
  generate "sitepress:install"
  # Sitepress includes markdown_rails, so we must install it.
  generate "markdown_rails:install"
end

# Behavior-driven development framework for testing Rails applications
gem "rspec-rails"

after_bundle do
  generate "rspec:install"
end

# Patch the development environment configuration file.
after_bundle do
  # Configure development environment to log to stdout
  inject_into_file "config/environments/development.rb", after: "Rails.application.configure do\n" do
    <<~RUBY
      # Send logs to stdout
      config.logger = ActiveSupport::Logger.new(STDOUT)

    RUBY
  end
end
