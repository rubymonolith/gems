module Monolith
  module Views
  end

  module Components
    extend Phlex::Kit
  end

  class Engine < ::Rails::Engine
    isolate_namespace Monolith

    initializer "monolith.assets" do |app|
      app.config.assets.paths << root.join("app/assets/builds")
    end

    initializer "monolith.mount", after: :load_config_initializers do |app|
      if Rails.env.development?
        app.routes.prepend do
          mount Monolith::Engine => "/monolith"
        end
      end
    end

    initializer "monolith.autoloaders" do
      Rails.autoloaders.main.push_dir(
        root.join("app/views/monolith"), namespace: Monolith::Views
      )

      Rails.autoloaders.main.push_dir(
        root.join("app/components/monolith"), namespace: Monolith::Components
      )
    end
  end
end
