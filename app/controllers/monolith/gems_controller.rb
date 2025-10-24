# app/controllers/monolith/gems_controller.rb
module Monolith
  class GemsController < Monolith::ApplicationController
    def index
      render Index.new.tap { _1.gems = GemInfo.all }
    end

    def show
      gem_info = GemInfo.find(params[:id].to_s)
      return render plain: "Gem not found", status: :not_found unless gem_info

      render Show.new.tap { |v| v.gem_info = gem_info }
    end

    # =======================
    # Inline ActiveModel-like object
    # =======================
    class GemInfo
      include Comparable
      attr_reader :name, :version, :summary, :licenses, :homepage, :source_code_uri,
                  :bug_tracker_uri, :changelog_uri, :rubygems_uri, :path

      def self.all
        # Bundler.load.specs → Gem::Specification for everything in the bundle
        specs = Bundler.load.specs.sort_by { |s| s.name }
        specs.map { |spec| from_spec(spec) }
      end

      def self.find(name)
        spec = Bundler.load.specs.find { |s| s.name == name }
        spec && from_spec(spec)
      end

      def self.from_spec(spec)
        meta = spec.respond_to?(:metadata) ? (spec.metadata || {}) : {}

        licenses =
          if spec.respond_to?(:licenses) && spec.licenses.any?
            spec.licenses
          elsif spec.respond_to?(:license) && spec.license
            [spec.license]
          else
            Array(meta["license"])
          end

        homepage = presence(spec.homepage) || meta["homepage_uri"]
        source   = meta["source_code_uri"]
        bugs     = meta["bug_tracker_uri"]
        change   = meta["changelog_uri"]

        new(
          name:           spec.name,
          version:        spec.version.to_s,
          summary:        spec.summary,
          licenses:       licenses.compact.map(&:to_s).uniq,
          homepage:       homepage,
          source_code_uri: source,
          bug_tracker_uri: bugs,
          changelog_uri:   change,
          rubygems_uri:   "https://rubygems.org/gems/#{spec.name}",
          path:           spec.full_gem_path
        )
      end

      def initialize(name:, version:, summary:, licenses:, homepage:, source_code_uri:, bug_tracker_uri:, changelog_uri:, rubygems_uri:, path:)
        @name, @version, @summary, @licenses, @homepage, @source_code_uri, @bug_tracker_uri,
          @changelog_uri, @rubygems_uri, @path =
          name, version, summary, licenses, homepage, source_code_uri, bug_tracker_uri, changelog_uri, rubygems_uri, path
      end

      def to_param = name
      def <=>(other) = name <=> other.name

      private

      def self.presence(str)
        s = str.to_s.strip
        s.empty? ? nil : s
      end
    end

    # =======================
    # Phlex views
    # =======================
    class Index < View
      attr_writer :gems

      def view_template
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "Gems" }
          p(class: "text-sm") { "From your current Bundler context (Gemfile.lock)." }

          div(class: "overflow-x-auto border") do
            table(class: "min-w-full text-sm") do
              thead do
                tr do
                  %w[Gem Version Licenses Homepage RubyGems Description].each do |col|
                    th(class: "px-3 py-2 text-left font-semibold") { col }
                  end
                end
              end
              tbody do
                @gems.sort.each do |g|
                  tr do
                    td(class: "px-3 py-2") { nav_link g.name, controller: "/monolith/gems", action: :show, id: g.name }
                    td(class: "px-3 py-2") { g.version }
                    td(class: "px-3 py-2") { g.licenses.any? ? g.licenses.join(", ") : em { "—" } }
                    td(class: "px-3 py-2") { ext_link g.homepage, "homepage" }
                    td(class: "px-3 py-2") { ext_link g.rubygems_uri, "rubygems" }
                    td(class: "px-3 py-2 max-w-md truncate") { g.summary.to_s.strip.empty? ? em { "—" } : g.summary }
                  end
                end
              end
            end
          end
        end
      end
    end

    class Show < View
      attr_writer :gem_info

      def view_template
        g = @gem_info

        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "#{g.name} (#{g.version})" }
          p { g.summary.to_s.strip.empty? ? em { "No summary" } : g.summary }

          dl(class: "grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-2") do
            dt(class: "font-semibold") { "Licenses" }
            dd { g.licenses.any? ? g.licenses.join(", ") : em { "—" } }

            dt(class: "font-semibold") { "Homepage" }
            dd { ext_link g.homepage, g.homepage&.sub(%r{\Ahttps?://}, "") }

            dt(class: "font-semibold") { "Source" }
            dd { ext_link g.source_code_uri, g.source_code_uri&.sub(%r{\Ahttps?://}, "") }

            dt(class: "font-semibold") { "Bugs" }
            dd { ext_link g.bug_tracker_uri, g.bug_tracker_uri&.sub(%r{\Ahttps?://}, "") }

            dt(class: "font-semibold") { "Changelog" }
            dd { ext_link g.changelog_uri, g.changelog_uri&.sub(%r{\Ahttps?://}, "") }

            dt(class: "font-semibold") { "RubyGems" }
            dd { ext_link g.rubygems_uri, g.rubygems_uri&.sub(%r{\Ahttps?://}, "") }

            dt(class: "font-semibold") { "Path" }
            dd { code { g.path } }
          end

          div(class: "pt-4") { nav_link "← All gems", controller: "/monolith/gems", action: :index }
        end
      end
    end
  end
end
