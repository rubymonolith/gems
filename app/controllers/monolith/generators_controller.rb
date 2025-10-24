# app/controllers/monolith/generators_controller.rb
module Monolith
  class GeneratorsController < Monolith::ApplicationController
    def index
      render Index.new.tap { _1.generators = Generator.all }
    end

    def show
      generator = Generator.find(params[:id].to_s)
      return render plain: "Generator not found", status: :not_found unless generator

      render Show.new.tap { |v| v.generator = generator }
    end

    def create
      generator = Generator.find(params[:id].to_s)
      return render plain: "Generator not found", status: :not_found unless generator

      args = params[:args].to_s.split
      options = params[:options].to_h.reject { |k, v| v.blank? }

      result = generator.invoke(args, options)

      render Create.new.tap { |v|
        v.generator = generator
        v.result = result
        v.args = args
        v.options = options
      }
    rescue => e
      render plain: "Error: #{e.message}\n\n#{e.backtrace.join("\n")}", status: :unprocessable_entity
    end

    # =======================
    # Inline ActiveModel-like object
    # =======================
    class Generator
      attr_reader :name, :namespace, :klass

      def self.all
        Rails.application.load_generators

        # Get all generator namespaces
        namespaces = Rails::Generators.hidden_namespaces + Rails::Generators.public_namespaces
        namespaces = namespaces.uniq.sort

        # Find and instantiate each generator
        generators = namespaces.map do |namespace|
          begin
            klass = Rails::Generators.find_by_namespace(namespace)
            klass && !klass.name.nil? ? new(klass) : nil
          rescue
            nil
          end
        end.compact

        generators
      end

      def self.find(namespace)
        Rails.application.load_generators

        klass = Rails::Generators.find_by_namespace(namespace)
        klass && new(klass)
      end

      def initialize(klass)
        @klass = klass
        @namespace = klass.namespace
        @name = @namespace.split(':').last
      end

      def to_param
        namespace
      end

      def description
        klass.desc rescue nil
      end

      def arguments
        return [] unless klass.respond_to?(:arguments)

        klass.arguments.map do |arg|
          {
            name: arg.name,
            type: arg.type,
            required: arg.required?,
            description: arg.description,
            default: arg.default
          }
        end
      rescue
        []
      end

      def class_options
        return {} unless klass.respond_to?(:class_options)

        klass.class_options.transform_values do |option|
          {
            type: option.type,
            default: option.default,
            description: option.description,
            aliases: option.aliases,
            banner: option.banner
          }
        end
      rescue
        {}
      end

      def source_location
        return nil unless klass.respond_to?(:instance_methods)

        method = klass.instance_method(:initialize) rescue nil
        return nil unless method

        file, line = method.source_location
        file
      rescue
        nil
      end

      def invoke(args, options = {})
        require 'stringio'

        # Capture output
        output = StringIO.new
        original_stdout = $stdout
        original_stderr = $stderr
        $stdout = output
        $stderr = output

        begin
          # Convert options hash to array format Thor expects
          thor_args = args.dup
          options.each do |key, value|
            next if value.blank?
            thor_args << "--#{key}=#{value}"
          end

          # Invoke the generator
          Rails::Generators.invoke(namespace, thor_args, behavior: :invoke, destination_root: Rails.root)

          {
            success: true,
            output: output.string,
            error: nil
          }
        rescue => e
          {
            success: false,
            output: output.string,
            error: "#{e.class}: #{e.message}"
          }
        ensure
          $stdout = original_stdout
          $stderr = original_stderr
        end
      end
    end

    # =======================
    # Phlex views
    # =======================
    class Index < View
      attr_writer :generators

      def view_template
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "Generators" }
          p(class: "text-sm") { "#{@generators.size} Rails generators available." }

          Table @generators do
            it.row("Generator") {
              nav_link it.name, controller: "/monolith/generators", action: :show, id: it.to_param
            }
            it.row("Namespace") { |g|
              code { g.namespace }
            }
            it.row("Description") {
              it.description || em { "—" }
            }
          end
        end
      end
    end

    class Show < View
      attr_writer :generator

      def view_template
        g = @generator

        div(class: "p-6 space-y-6") do
          h1(class: "text-2xl font-bold") { g.name }
          p { code { "rails generate #{g.namespace}" } }

          if g.description
            p { g.description }
          end

          # Arguments
          section do
            h2(class: "text-xl font-bold mb-2") { "Arguments" }
            if g.arguments.any?
              ul(class: "list-disc pl-6 space-y-1") do
                g.arguments.each do |arg|
                  li do
                    code { arg[:name] }
                    plain " (#{arg[:type]}"
                    plain ", required" if arg[:required]
                    plain ")"
                    if arg[:description]
                      plain " - #{arg[:description]}"
                    end
                    if arg[:default]
                      plain " [default: #{arg[:default]}]"
                    end
                  end
                end
              end
            else
              p { em { "No arguments" } }
            end
          end

          # Options
          section do
            h2(class: "text-xl font-bold mb-2") { "Options" }
            if g.class_options.any?
              ul(class: "list-disc pl-6 space-y-1") do
                g.class_options.each do |name, option|
                  li do
                    code { "--#{name}" }
                    if option[:aliases]&.any?
                      plain " ("
                      code { option[:aliases].join(", ") }
                      plain ")"
                    end
                    plain " - #{option[:type]}"
                    if option[:description]
                      plain " - #{option[:description]}"
                    end
                    if option[:default]
                      plain " [default: #{option[:default]}]"
                    end
                  end
                end
              end
            else
              p { em { "No options" } }
            end
          end

          # Invoke Form
          section do
            h2(class: "text-xl font-bold mb-2") { "Run Generator" }
            form(method: "post", action: url_for(controller: "/monolith/generators", action: :create, id: g.to_param)) do
              div(class: "space-y-3") do
                # CSRF token
                input(type: "hidden", name: "authenticity_token", value: form_authenticity_token)

                # Arguments input
                div do
                  label(class: "block font-semibold mb-1") { "Arguments (space-separated)" }
                  input(
                    type: "text",
                    name: "args",
                    placeholder: g.arguments.map { |a| a[:name] }.join(" "),
                    class: "w-full border px-3 py-2"
                  )
                  if g.arguments.any?
                    p(class: "text-sm mt-1") do
                      plain "Expected: "
                      g.arguments.each_with_index do |arg, idx|
                        plain " " if idx > 0
                        code { arg[:name] }
                      end
                    end
                  end
                end

                # Options
                if g.class_options.any?
                  div do
                    label(class: "block font-semibold mb-2") { "Options" }
                    div(class: "space-y-2") do
                      g.class_options.each do |name, option|
                        div(class: "flex items-center gap-2") do
                          label(class: "w-48") {
                            code { "--#{name}" }
                          }
                          case option[:type]
                          when :boolean
                            input(type: "checkbox", name: "options[#{name}]", value: "true")
                          else
                            input(
                              type: "text",
                              name: "options[#{name}]",
                              placeholder: option[:default]&.to_s || option[:banner]&.to_s,
                              class: "flex-1 border px-2 py-1"
                            )
                          end
                        end
                      end
                    end
                  end
                end

                # Submit button
                div do
                  button(
                    type: "submit",
                    class: "px-4 py-2 border font-semibold hover:bg-gray-100"
                  ) { "Generate" }
                end
              end
            end
          end

          # Source location
          if g.source_location
            section do
              h2(class: "text-xl font-bold mb-2") { "Source" }
              p { code { g.source_location } }
            end
          end

          div(class: "pt-4") { nav_link "← All generators", controller: "/monolith/generators", action: :index }
        end
      end
    end

    class Create < View
      attr_writer :generator, :result, :args, :options

      def view_template
        g = @generator
        r = @result

        div(class: "p-6 space-y-6") do
          h1(class: "text-2xl font-bold") { "Generator Result: #{g.name}" }

          if r[:success]
            div(class: "border border-green-600 p-4") do
              h2(class: "font-bold text-green-600 mb-2") { "✓ Success" }
              p do
                plain "Invoked: "
                code { "rails generate #{g.namespace} #{@args.join(' ')}" }
              end
            end
          else
            div(class: "border border-red-600 p-4") do
              h2(class: "font-bold text-red-600 mb-2") { "✗ Error" }
              p { r[:error] }
            end
          end

          # Output
          section do
            h2(class: "text-xl font-bold mb-2") { "Output" }
            pre(class: "border p-4 overflow-x-auto text-xs") do
              code { r[:output] }
            end
          end

          div(class: "pt-4 space-x-4") do
            nav_link "← Back to generator", controller: "/monolith/generators", action: :show, id: g.to_param
            nav_link "All generators", controller: "/monolith/generators", action: :index
          end
        end
      end
    end
  end
end
