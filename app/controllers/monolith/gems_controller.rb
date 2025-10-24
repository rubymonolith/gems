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
                  :bug_tracker_uri, :changelog_uri, :rubygems_uri, :path, :source_type, :source_info

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

        # Detect gem source
        source_type, source_info = detect_source(spec)

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
          path:           spec.full_gem_path,
          source_type:    source_type,
          source_info:    source_info
        )
      end

      def initialize(name:, version:, summary:, licenses:, homepage:, source_code_uri:, bug_tracker_uri:, changelog_uri:, rubygems_uri:, path:, source_type:, source_info:)
        @name, @version, @summary, @licenses, @homepage, @source_code_uri, @bug_tracker_uri,
          @changelog_uri, @rubygems_uri, @path, @source_type, @source_info =
          name, version, summary, licenses, homepage, source_code_uri, bug_tracker_uri, changelog_uri, rubygems_uri, path, source_type, source_info
      end

      def to_param = name
      def <=>(other) = name <=> other.name

      private

      def self.presence(str)
        s = str.to_s.strip
        s.empty? ? nil : s
      end

      def self.detect_source(spec)
        # Check Bundler's locked specs to find the source
        locked_spec = Bundler.locked_gems&.specs&.find { |s| s.name == spec.name }

        if locked_spec && locked_spec.source
          case locked_spec.source
          when Bundler::Source::Rubygems
            [:rubygems, "https://rubygems.org/gems/#{spec.name}"]
          when Bundler::Source::Git
            git_uri = locked_spec.source.uri
            git_ref = locked_spec.source.ref || locked_spec.source.branch || locked_spec.source.revision
            if git_uri.to_s =~ /github\.com/
              [:github, "#{git_uri} @ #{git_ref}"]
            else
              [:git, "#{git_uri} @ #{git_ref}"]
            end
          when Bundler::Source::Path
            [:path, locked_spec.source.path.to_s]
          else
            [:unknown, locked_spec.source.class.name]
          end
        else
          # Fallback: check if path looks like it's from RubyGems cache
          if spec.full_gem_path.to_s.include?('/gems/')
            [:rubygems, "https://rubygems.org/gems/#{spec.name}"]
          elsif spec.full_gem_path.to_s.include?('/bundler/gems/')
            [:git, spec.full_gem_path.to_s]
          else
            [:path, spec.full_gem_path.to_s]
          end
        end
      rescue => e
        [:unknown, "Error: #{e.message}"]
      end
    end

    class View < View

      protected

      def gem_origin_link(g)
        case g.source_type
        when :rubygems
          ext_link g.rubygems_uri
        when :github
          git_uri = g.source_info.split(' @ ').first
          git_ref = g.source_info.split(' @ ').last
          # Convert GitHub URI to branch/commit URL
          normalized_uri = git_uri.to_s.sub(/\.git$/, '')
          branch_url = "#{normalized_uri}/tree/#{git_ref}"
          ext_link branch_url
        when :git
          code { g.source_info }
        when :path
          if defined?(ActiveSupport::Editor) && (editor = ActiveSupport::Editor.current)
            # Try to link to the path in the editor
            absolute_path = File.expand_path(g.source_info)
            if absolute_path && File.exist?(absolute_path)
              ext_link editor.url_for(absolute_path, 1), "Local Path: #{g.source_info}"
            else
              code { g.source_info }
            end
          else
            code { g.source_info }
          end
        else
          code { "#{g.source_type}: #{g.source_info}" }
        end
      end
    end

    # =======================
    # Phlex views
    # =======================
    #
    class Index < View
      attr_writer :gems

      def view_template
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "Gems" }
          p(class: "text-sm") { "From your current Bundler context (Gemfile.lock)." }

          Table @gems do
            it.row("Gem") {
              nav_link it.name, controller: "/monolith/gems", action: :show, id: it.name
            }
            it.row("Version") {
              it.version
            }
            it.row("Licenses") {
              it.licenses.any? ? it.licenses.join(", ") : em { "—" }
            }
            it.row("Origin") {
              gem_origin_link it
            }
            it.row("Description") {
              it.summary.to_s.strip.empty? ? em { "—" } : it.summary
            }
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

            dt(class: "font-semibold") { "Origin" }
            dd {
              gem_origin_link g
            }

            dt(class: "font-semibold") { "Path" }
            dd { code { g.path } }
          end

          div(class: "pt-4") { nav_link "← All gems", controller: "/monolith/gems", action: :index }
        end
      end
    end
  end
end
