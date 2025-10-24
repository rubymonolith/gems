class Monolith::ApplicationController < ActionController::Base
  layout false

  # # include Superview::Actions
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
          stylesheet_link_tag "tailwind", data_turbo_track: "reload"
          javascript_importmap_tags
          render @opengraph
        end

        body(&)
      end
    end

    def view_template
      render_content
    end

    def render_content
      # Override in subclasses
    end
  end

  # =======================
  # View with Navigation
  # =======================
  class View < BaseView
    def view_template
      div(class: "min-h-screen") do
        render_nav
        div(class: "container mx-auto") do
          render_content
        end
      end
    end

    def render_nav
      nav(class: "border-b mb-6") do
        div(class: "container mx-auto px-6 py-4") do
          div(class: "flex items-center gap-6") do
            span(class: "font-bold text-lg") { "Monolith" }
            nav_link "Emails", controller: "/monolith/emails", action: :index
            nav_link "Tables", controller: "/monolith/tables", action: :index
            nav_link "Gems", controller: "/monolith/gems", action: :index
            nav_link "Routes", controller: "/monolith/routes", action: :index
            nav_link "Models", controller: "/monolith/models", action: :index
            nav_link "Generators", controller: "/monolith/generators", action: :index
          end
        end
      end
    end

    def nav_link(text, **to)
      a(href: url_for(to), class: "underline hover:no-underline") { text }
    end

    def ext_link(href, text = nil)
      return em { "—" } if href.nil?
      a(href:, target: "_blank", rel: "noopener") { text || href }
    end
  end
end
