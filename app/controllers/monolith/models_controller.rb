# app/controllers/monolith/models_controller.rb
module Monolith
  class ModelsController < Monolith::ApplicationController
    def index
      render Index.new.tap { _1.models = Model.all }
    end

    def show
      model = Model.find(params[:id].to_s)
      return render plain: "Model not found", status: :not_found unless model

      render Show.new.tap { |v| v.model = model }
    end

    # =======================
    # Inline ActiveModel-like object
    # =======================
    class Model
      attr_reader :name, :klass

      def self.all
        Rails.application.eager_load!

        models = ActiveRecord::Base.descendants
          .reject(&:abstract_class?)
          .sort_by(&:name)

        models.map { |klass| new(klass) }
      end

      def self.find(name)
        Rails.application.eager_load!

        klass = ActiveRecord::Base.descendants.find { |k| k.name == name }
        klass && new(klass)
      end

      def initialize(klass)
        @klass = klass
        @name = klass.name
      end

      def to_param
        name
      end

      def table_name
        klass.table_name
      end

      def column_names
        klass.column_names
      rescue
        []
      end

      def primary_key
        klass.primary_key
      rescue
        nil
      end

      def validations
        klass.validators.map do |validator|
          {
            type: validator.class.name.demodulize.gsub(/Validator$/, ''),
            attributes: validator.attributes,
            options: validator.options
          }
        end
      rescue
        []
      end

      def associations
        klass.reflect_on_all_associations.map do |assoc|
          {
            name: assoc.name,
            type: assoc.macro,
            class_name: assoc.class_name,
            foreign_key: assoc.foreign_key,
            options: assoc.options
          }
        end
      rescue
        []
      end

      def scopes
        # Get custom scopes (not default scopes)
        scope_names = klass.respond_to?(:scopes) ? klass.scopes.keys : []
        scope_names.map(&:to_s).sort
      rescue
        []
      end

      def callbacks
        [:before_validation, :after_validation, :before_save, :after_save,
         :before_create, :after_create, :before_update, :after_update,
         :before_destroy, :after_destroy].flat_map do |callback_type|
          klass._get_callbacks(callback_type).map do |callback|
            {
              type: callback_type,
              filter: callback.filter
            }
          end
        end.compact
      rescue
        []
      end

      def source_location
        return nil unless klass.respond_to?(:instance_methods)

        # Try to find the model file
        file_path = "#{Rails.root}/app/models/#{name.underscore}.rb"
        File.exist?(file_path) ? file_path : nil
      end

      def source_code
        return nil unless source_location

        File.read(source_location)
      rescue
        nil
      end

      def instance_methods
        (klass.instance_methods - ActiveRecord::Base.instance_methods)
          .sort
          .map(&:to_s)
      rescue
        []
      end

      def class_methods
        (klass.methods - ActiveRecord::Base.methods)
          .sort
          .map(&:to_s)
      rescue
        []
      end
    end

    # =======================
    # Phlex views
    # =======================
    class Index < View
      attr_writer :models

      def view_template
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "Models" }
          p(class: "text-sm") { "#{@models.size} ActiveRecord models in your application." }

          div(class: "overflow-x-auto border") do
            table(class: "min-w-full text-sm") do
              thead do
                tr do
                  %w[Model Table Columns].each do |col|
                    th(class: "px-3 py-2 text-left font-semibold") { col }
                  end
                end
              end
              tbody do
                @models.each do |model|
                  tr do
                    td(class: "px-3 py-2") {
                      nav_link model.name, controller: "/monolith/models", action: :show, id: model.to_param
                    }
                    td(class: "px-3 py-2") { code { model.table_name } }
                    td(class: "px-3 py-2") { model.column_names.size.to_s }
                  end
                end
              end
            end
          end
        end
      end
    end

    class Show < View
      attr_writer :model

      def view_template
        m = @model

        div(class: "p-6 space-y-6") do
          h1(class: "text-2xl font-bold") { m.name }
          p { code { m.table_name } }

          # Columns
          section do
            h2(class: "text-xl font-bold mb-2") { "Columns (#{m.column_names.size})" }
            if m.column_names.any?
              ul(class: "list-disc pl-6") do
                m.column_names.each do |col|
                  li {
                    plain col
                    if col == m.primary_key
                      span(class: "text-sm") { " (primary key)" }
                    end
                  }
                end
              end
            else
              p { em { "No columns" } }
            end
          end

          # Validations
          section do
            h2(class: "text-xl font-bold mb-2") { "Validations (#{m.validations.size})" }
            if m.validations.any?
              ul(class: "list-disc pl-6 space-y-1") do
                m.validations.each do |validation|
                  li do
                    strong { validation[:type] }
                    plain " on "
                    code { validation[:attributes].join(", ") }
                    if validation[:options].any?
                      plain " "
                      code { validation[:options].inspect }
                    end
                  end
                end
              end
            else
              p { em { "No validations" } }
            end
          end

          # Associations
          section do
            h2(class: "text-xl font-bold mb-2") { "Associations (#{m.associations.size})" }
            if m.associations.any?
              ul(class: "list-disc pl-6 space-y-1") do
                m.associations.each do |assoc|
                  li do
                    strong { assoc[:type].to_s }
                    plain " :"
                    code { assoc[:name].to_s }
                    plain " → "
                    plain assoc[:class_name]
                    plain " (FK: "
                    code { assoc[:foreign_key].to_s }
                    plain ")"
                  end
                end
              end
            else
              p { em { "No associations" } }
            end
          end

          # Scopes
          if m.scopes.any?
            section do
              h2(class: "text-xl font-bold mb-2") { "Scopes (#{m.scopes.size})" }
              ul(class: "list-disc pl-6") do
                m.scopes.each do |scope_name|
                  li { code { scope_name } }
                end
              end
            end
          end

          # Callbacks
          if m.callbacks.any?
            section do
              h2(class: "text-xl font-bold mb-2") { "Callbacks (#{m.callbacks.size})" }
              ul(class: "list-disc pl-6 space-y-1") do
                m.callbacks.each do |callback|
                  li do
                    strong { callback[:type].to_s }
                    plain " → "
                    code { callback[:filter].to_s }
                  end
                end
              end
            end
          end

          # Instance Methods
          if m.instance_methods.any?
            section do
              h2(class: "text-xl font-bold mb-2") { "Instance Methods (#{m.instance_methods.size})" }
              details do
                summary(class: "cursor-pointer") { "Show methods" }
                ul(class: "list-disc pl-6 mt-2 grid grid-cols-2 md:grid-cols-3 gap-1") do
                  m.instance_methods.each do |method_name|
                    li { code { method_name } }
                  end
                end
              end
            end
          end

          # Class Methods
          if m.class_methods.any?
            section do
              h2(class: "text-xl font-bold mb-2") { "Class Methods (#{m.class_methods.size})" }
              details do
                summary(class: "cursor-pointer") { "Show methods" }
                ul(class: "list-disc pl-6 mt-2 grid grid-cols-2 md:grid-cols-3 gap-1") do
                  m.class_methods.each do |method_name|
                    li { code { method_name } }
                  end
                end
              end
            end
          end

          # Source Code
          if m.source_code
            section do
              h2(class: "text-xl font-bold mb-2") { "Source Code" }
              p(class: "text-sm mb-2") { code { m.source_location } }
              pre(class: "border p-4 overflow-x-auto text-xs") do
                code { m.source_code }
              end
            end
          end

          div(class: "pt-4") { nav_link "← All models", controller: "/monolith/models", action: :index }
        end
      end
    end
  end
end
