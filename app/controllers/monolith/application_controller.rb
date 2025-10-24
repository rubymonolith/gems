require 'superview'

class Monolith::ApplicationController < ActionController::Base
  layout false

  include Superview::Actions
  # # include Superform::Rails::StrongParameters
  # include ExceptionHandler

  private

  def unprocessable(view)
    render component(view), status: :unprocessable_entity
  end

  def processed(model, form: self.class::Form)
    save form.new model
  end

  # =======================
  # Basic HTML View (no navigation)
  # =======================
  class BaseView < Phlex::HTML
    include Phlex::Rails::Helpers::URLFor
    include Phlex::Rails::Helpers::FormAuthenticityToken
    include Phlex::Rails::Helpers::AssetPath
    include Phlex::Rails::Layout
    include Phlex::Rails::Helpers::TurboFrameTag

    def around_template(&)
      html do
        head do
          title { @title }
          meta name: "viewport", content: "width=device-width,initial-scale=1"
          meta charset: "utf-8"
          meta name: "apple-mobile-web-app-capable", content: "yes"
          meta name: "apple-mobile-web-app-status-bar-style", content: "black-translucent"
          csp_meta_tag
          csrf_meta_tags
          stylesheet_link_tag "monolith/tailwind", data_turbo_track: "reload"
          javascript_importmap_tags
          render @opengraph
        end

        body(&)
      end
    end

    def view_template
      yield self if block_given?
    end
  end

  # =======================
  # View with Navigation
  # =======================
  class View < BaseView
    def around_template
      super do
        div(class: "flex min-h-screen") do
          render_sidebar
          div(class: "flex-1 p-6") do
            yield self if block_given?
          end
        end
      end
    end

    def render_sidebar
      aside(class: "w-64 bg-base-200 p-4") do
        div(class: "mb-6") do
          a(href: url_for(controller: "/monolith/home", action: :show)) do
            img(src: asset_path("monolith/logo.svg"), alt: "Monolith", class: "h-12")
          end
        end

        ul(class: "menu bg-base-200 rounded-box w-full") do
          li { nav_link "Emails", controller: "/monolith/emails", action: :index }
          li { nav_link "Tables", controller: "/monolith/tables", action: :index }
          li { nav_link "Gems", controller: "/monolith/gems", action: :index }
          li { nav_link "Routes", controller: "/monolith/routes", action: :index }
          li { nav_link "Models", controller: "/monolith/models", action: :index }
          li { nav_link "Generators", controller: "/monolith/generators", action: :index }
        end
      end
    end

    def nav_link(text, **to)
      a(href: url_for(to)) { text }
    end

    def ext_link(href, text = nil)
      return em { "—" } if href.nil?
      a(href:, target: "_blank", rel: "noopener") { text || href }
    end
  end
end
