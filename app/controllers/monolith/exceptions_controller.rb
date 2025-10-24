# app/controllers/monolith/exceptions_controller.rb
module Monolith
  class ExceptionsController < Monolith::ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    def show
      exception = request.env['action_dispatch.exception']

      if exception.nil?
        return render plain: "No exception found", status: :not_found
      end

      render Show.new.tap { |v| v.exception = ExceptionInfo.new(exception) }
    end

    def source
      file = params[:file]
      line = params[:line].to_i

      if file.blank? || line <= 0
        Rails.logger.error "Invalid parameters for source: file=#{file}, line=#{line}"
        return render plain: "Invalid parameters", status: :bad_request
      end

      # Security: ensure file exists and is a real file (not a directory traversal)
      unless File.exist?(file) && File.file?(file)
        Rails.logger.error "File not found: #{file}"
        return render plain: "File not found", status: :not_found
      end

      # Security: resolve path and ensure it's not trying to escape via symlinks
      real_path = File.realpath(file)

      # Allow files in Rails.root or gem directories
      allowed = real_path.start_with?(Rails.root.to_s) ||
                real_path.include?('/gems/') ||
                real_path.include?('/.rbenv/') ||
                real_path.include?('/.rvm/') ||
                real_path.include?('/ruby/')

      unless allowed
        Rails.logger.error "Access denied for file: #{real_path}"
        return render plain: "Access denied", status: :forbidden
      end

      extract = ExceptionInfo.new(nil).send(:extract_source, file, line)

      if extract
        render SourceExtract.new.tap { |v| v.extract = extract }, layout: false
      else
        Rails.logger.error "Source not available for file: #{file}, line: #{line}"
        render plain: "Source not available", status: :not_found
      end
    rescue => e
      Rails.logger.error "Exception in source action: #{e.class.name}: #{e.message}\n#{e.backtrace.join("\n")}"
      render plain: "Error: #{e.message}", status: :internal_server_error
    end

    # =======================
    # Inline ActiveModel-like object
    # =======================
    class ExceptionInfo
      attr_reader :exception

      def initialize(exception)
        @exception = exception
      end

      def class_name
        exception.class.name
      end

      def message
        exception.message
      end

      def backtrace
        exception.backtrace || []
      end

      def grouped_trace
        @grouped_trace ||= backtrace.map do |frame|
          file, line, method = parse_frame(frame)
          group = categorize_frame(frame)
          {
            frame: frame,
            file: file,
            line: line,
            method: method,
            group: group
          }
        end
      end

      def first_application_frame
        # Try Application first, then any other group
        grouped_trace.find { |f| f[:group] == 'Application' } || grouped_trace.first
      end

      def source_extract
        frame = first_application_frame
        return nil unless frame

        file = frame[:file]
        line = frame[:line]
        return nil unless file && line
        return nil unless File.exist?(file)

        extract_source(file, line)
      end

      private

      def categorize_frame(frame)
        if frame.start_with?(Rails.root.to_s)
          if frame.include?('/app/')
            'Application'
          elsif frame.include?('/lib/')
            'Library'
          elsif frame.include?('/config/')
            'Configuration'
          else
            'Application'
          end
        elsif frame.include?('/.gem/') || frame.include?('/gems/')
          'Gems'
        elsif frame.include?('/ruby/')
          'Ruby'
        else
          'Framework'
        end
      end

      def parse_frame(frame)
        # Parse "path/to/file.rb:123:in `method_name'" format
        # Also handle "path/to/file.rb:123" format without method
        if match = frame.match(/^(.+?):(\d+)(?::in [`'](.+?)['"])?/)
          file = match[1]
          line = match[2].to_i
          method_name = match[3]
          [file, line, method_name]
        else
          [nil, nil, nil]
        end
      end

      def extract_source(file, line_number, context = nil)
        return nil unless file
        return nil unless File.exist?(file)

        source_code = File.read(file)
        lines = source_code.split("\n")
        return nil if lines.empty?

        # Load entire file
        {
          file: file.gsub(Rails.root.to_s + '/', ''),
          line_number: line_number,
          start_line: 1,
          end_line: lines.size,
          total_lines: lines.size,
          lines: lines.map.with_index do |content, idx|
            {
              number: idx + 1,
              content: content,
              highlighted: (idx + 1) == line_number
            }
          end
        }
      rescue => e
        # Debug: log the error
        Rails.logger.error("Error extracting source from #{file}: #{e.message}")
        nil
      end
    end

    # =======================
    # Phlex views
    # =======================
    class Show < View
      attr_writer :exception

      def render_content
        e = @exception

        # Full-screen dark background with code editor aesthetic
        div(class: "relative h-screen overflow-hidden bg-gray-900") do
          # Main scrollable code area (fills entire screen) - wrapped in turbo frame
          turbo_frame_tag "source-view", class: "h-full overflow-y-auto block" do
            extract = e.source_extract
            if extract
              render_source_extract(extract)
            else
              div(class: "flex items-center justify-center h-full text-gray-500 font-mono text-sm") do
                plain "Click a stack frame to view source"
              end
            end
          end

          # Floating HUD on the right side
          div(class: "fixed top-20 right-8 w-96 max-h-[calc(100vh-6rem)] flex flex-col bg-gray-800/80 backdrop-blur-md rounded-xl shadow-2xl border border-gray-700 overflow-hidden") do
            # Exception header (fixed at top of HUD)
            div(class: "bg-gray-700 text-white p-4 border-b border-gray-600") do
              h1(class: "text-lg font-bold mb-1 text-red-400") { e.class_name }
              p(class: "text-sm text-gray-300 leading-snug") { e.message }
            end

            # Scrollable stack trace
            div(class: "overflow-y-auto flex-1") do
              render_grouped_trace(e.grouped_trace)
            end
          end
        end
      end

      def render_source_extract(extract)
        return unless extract

        div(class: "min-h-full bg-gray-900") do
          # File header (sticky at top)
          div(class: "sticky top-0 bg-gray-800 text-gray-300 px-6 py-3 font-mono text-xs border-b border-gray-700 z-10") do
            span(class: "text-gray-500") { "📄 " }
            span(class: "text-green-400") { extract[:file] }
          end

          # Code lines - text editor style
          div(class: "p-6") do
            div(class: "font-mono text-sm") do
              extract[:lines].each do |line_data|
                div(
                  id: "L#{line_data[:number]}",
                  class: line_data[:highlighted] ? "bg-red-900/30 border-l-4 border-red-500" : ""
                ) do
                  div(class: "flex") do
                    # Line number (left side, text editor style)
                    div(class: "px-4 py-1 text-right select-none text-gray-600 min-w-[4rem]") do
                      if line_data[:highlighted]
                        span(class: "text-red-400 font-bold") { line_data[:number].to_s }
                      else
                        plain line_data[:number].to_s
                      end
                    end
                    # Code content
                    div(class: "px-4 py-1 flex-1 whitespace-pre") do
                      code(class: line_data[:highlighted] ? "text-red-300" : "text-gray-300") do
                        plain line_data[:content]
                      end
                    end
                  end
                end
              end
            end
          end

          # Auto-scroll to highlighted line on load
          if extract[:line_number]
            script do
              raw safe("setTimeout(() => { const frame = document.getElementById('source-view'); const el = document.getElementById('L#{extract[:line_number]}'); if (frame && el) { el.scrollIntoView({ block: 'center', behavior: 'instant' }); } }, 10);")
            end
          end
        end
      end

      def render_grouped_trace(grouped_trace)
        # Group frames by category
        current_group = nil

        grouped_trace.each_with_index do |frame_data, idx|
          # If we're starting a new group, render the group header
          if current_group != frame_data[:group]
            current_group = frame_data[:group]

            # Group header with subtle color coding
            group_color = case current_group
            when 'Application' then 'bg-blue-900/50'
            when 'Gems' then 'bg-purple-900/50'
            when 'Framework' then 'bg-green-900/50'
            when 'Ruby' then 'bg-red-900/50'
            else 'bg-gray-700'
            end

            div(class: "#{group_color} text-gray-300 px-4 py-2 text-xs font-bold uppercase tracking-wide") do
              plain current_group
            end
          end

          # Render the frame (clickable link with Turbo Frame target)
          if frame_data[:file] && frame_data[:line]
            a(
              href: url_for(controller: 'monolith/exceptions', action: 'source', file: frame_data[:file], line: frame_data[:line]),
              class: "block border-b border-gray-700 px-4 py-3 font-mono text-xs hover:bg-gray-700/50 transition-colors no-underline",
              data_turbo_frame: "source-view"
            ) do
              div(class: "truncate text-gray-200 mb-1 font-medium") {
                plain frame_data[:file]
              }
              div(class: "text-gray-400 text-xs") do
                span(class: "text-cyan-400") { "Line #{frame_data[:line]}" }
                if frame_data[:method]
                  plain " • "
                  code(class: "text-yellow-300") { frame_data[:method] }
                end
              end
            end
          else
            div(class: "border-b border-gray-700 px-4 py-3 font-mono text-xs") do
              code(class: "text-xs text-gray-400") { frame_data[:frame] }
            end
          end
        end
      end
    end

    class SourceExtract < View
      attr_writer :extract

      def view_template
        return unless @extract

        turbo_frame_tag "source-view", class: "h-full overflow-y-auto block" do
          div(class: "min-h-full bg-gray-900") do
            # File header (sticky at top)
            div(class: "sticky top-0 bg-gray-800 text-gray-300 px-6 py-3 font-mono text-xs border-b border-gray-700 z-10") do
              span(class: "text-gray-500") { "📄 " }
              span(class: "text-green-400") { @extract[:file] }
            end

            # Code lines - text editor style
            div(class: "p-6") do
              div(class: "font-mono text-sm") do
                @extract[:lines].each do |line_data|
                  div(
                    id: "L#{line_data[:number]}",
                    class: line_data[:highlighted] ? "bg-red-900/30 border-l-4 border-red-500" : ""
                  ) do
                    div(class: "flex") do
                      # Line number (left side, text editor style)
                      div(class: "px-4 py-1 text-right select-none text-gray-600 min-w-[4rem]") do
                        if line_data[:highlighted]
                          span(class: "text-red-400 font-bold") { line_data[:number].to_s }
                        else
                          plain line_data[:number].to_s
                        end
                      end
                      # Code content
                      div(class: "px-4 py-1 flex-1 whitespace-pre") do
                        code(class: line_data[:highlighted] ? "text-red-300" : "text-gray-300") do
                          plain line_data[:content]
                        end
                      end
                    end
                  end
                end
              end
            end

            # Auto-scroll to highlighted line on load
            if @extract[:line_number]
              script do
                raw safe("document.addEventListener('turbo:frame-load', function(e) { if (e.target.id === 'source-view') { setTimeout(() => { const el = document.getElementById('L#{@extract[:line_number]}'); if (el) { el.scrollIntoView({ block: 'center', behavior: 'smooth' }); } }, 50); } });")
              end
            end
          end
        end
      end
    end


  end
end
