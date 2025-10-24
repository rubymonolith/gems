# app/controllers/monolith/routes_controller.rb
module Monolith
  class RoutesController < Monolith::ApplicationController
    def index
      render Index.new.tap { _1.routes = Route.all }
    end

    def show
      route = Route.find(params[:id].to_s)
      return render plain: "Route not found", status: :not_found unless route

      render Show.new.tap { |v| v.route = route }
    end

    # =======================
    # Inline ActiveModel-like object
    # =======================
    class Route
      attr_reader :name, :verb, :path, :controller, :action, :constraints, :defaults, :required_parts

      def self.all
        Rails.application.routes.routes.map.with_index { |route, idx| from_route(route, idx) }.compact.sort_by(&:display_name)
      end

      def self.find(id)
        all.find { |r| r.to_param == id }
      end

      def self.from_route(route, idx)
        name = route.name.to_s
        verb = route.verb.to_s
        path = route.path.spec.to_s

        # Extract controller and action
        defaults = route.defaults
        controller = defaults[:controller]
        action = defaults[:action]

        # Skip routes without controller/action or internal Rails routes
        return nil if controller.nil? || action.nil?
        return nil if controller.to_s.start_with?("rails/")

        new(
          name: name.empty? ? nil : name,
          verb: verb,
          path: path,
          controller: controller,
          action: action,
          constraints: route.constraints.except(:request_method),
          defaults: defaults.except(:controller, :action),
          required_parts: route.required_parts,
          id: idx
        )
      end

      def initialize(name:, verb:, path:, controller:, action:, constraints:, defaults:, required_parts:, id:)
        @name = name
        @verb = verb
        @path = path
        @controller = controller
        @action = action
        @constraints = constraints
        @defaults = defaults
        @required_parts = required_parts
        @id = id
      end

      def to_param
        @id.to_s
      end

      def display_name
        name || "#{controller}##{action}"
      end

      def full_controller_action
        "#{controller}##{action}"
      end
    end

    # =======================
    # Phlex views
    # =======================
    class Index < View
      attr_writer :routes

      def view_template
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "Routes" }
          p(class: "text-sm") { "#{@routes.size} routes in your Rails application." }

          Table @routes do
            it.row("Name") {
              nav_link it.display_name, controller: "/monolith/routes", action: :show, id: it.to_param
            }
            it.row("Verb") { |r|
              code { r.verb }
            }
            it.row("Path") { |r|
              code { r.path }
            }
            it.row("Controller#Action") {
              it.full_controller_action
            }
          end
        end
      end
    end

    class Show < View
      attr_writer :route

      def view_template
        r = @route

        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { r.display_name }
          p { code { "#{r.verb} #{r.path}" } }

          dl(class: "grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-2") do
            dt(class: "font-semibold") { "Name" }
            dd { r.name || em { "—" } }

            dt(class: "font-semibold") { "Verb" }
            dd { code { r.verb } }

            dt(class: "font-semibold") { "Path" }
            dd { code { r.path } }

            dt(class: "font-semibold") { "Controller" }
            dd { r.controller }

            dt(class: "font-semibold") { "Action" }
            dd { r.action }

            if r.required_parts.any?
              dt(class: "font-semibold") { "Required Parts" }
              dd { r.required_parts.join(", ") }
            end

            if r.defaults.any?
              dt(class: "font-semibold") { "Defaults" }
              dd { code { r.defaults.inspect } }
            end

            if r.constraints.any?
              dt(class: "font-semibold") { "Constraints" }
              dd { code { r.constraints.inspect } }
            end
          end

          div(class: "pt-4") { nav_link "← All routes", controller: "/monolith/routes", action: :index }
        end
      end
    end
  end
end
