module Monolith
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
  end
end
