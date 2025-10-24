# app/controllers/monolith/tables_controller.rb
module Monolith
  class TablesController < Monolith::ApplicationController
    before_action :set_pagination
    before_action :set_table, only: :show

    def index
      render Index.new.tap { _1.tables = Table.all }
    end

    def show
      not_found! unless @table
      rows = @table.rows(page: @page, per_page: @per_page)
      render Show.new.tap { |v|
        v.table   = @table
        v.rows    = rows[:data]
        v.total   = rows[:total]
        v.page    = @page
        v.per_page= @per_page
      }
    end

    private

    def set_pagination
      @page     = params[:page].to_i
      @page     = 1 if @page < 1
      @per_page = (params[:per_page] || 50).to_i
      @per_page = 50 if @per_page <= 0
      @per_page = 500 if @per_page > 500
    end

    def set_table
      @table = Table.find(params[:id].to_s) if params[:id].present?
    end

    def not_found!
      render plain: "Not found", status: :not_found
    end

    # =======================
    # Inline ActiveModel-like object
    # =======================
    class Table
      attr_reader :name

      EXCLUDED = %w[schema_migrations ar_internal_metadata].freeze

      def self.all
        tables.map { |t| new(t) }
      end

      def self.find(name)
        return nil unless tables.include?(name)
        new(name)
      end

      # ---- instance ----
      def initialize(name)
        @name = name
      end

      def to_param = name

      def columns
        @columns ||= conn.columns(name).map(&:name)
      end

      def primary_key
        @primary_key ||= conn.primary_key(name)
      end

      # Returns { data: [Hash], total: Integer }
      def rows(page:, per_page:)
        offset = (page - 1) * per_page
        total  = conn.exec_query("SELECT COUNT(*) AS c FROM #{qtn(name)}").first["c"]

        order_sql = primary_key ? "ORDER BY #{qcn(primary_key)}" : ""
        sql = <<~SQL
          SELECT *
          FROM #{qtn(name)}
          #{order_sql}
          LIMIT #{per_page.to_i} OFFSET #{offset.to_i}
        SQL

        data = conn.exec_query(sql).to_a
        { data: data, total: total }
      end

      private

      def self.conn = ActiveRecord::Base.connection
      def conn = self.class.conn

      def self.tables
        @tables ||= (conn.tables - EXCLUDED).sort
      end

      def qtn(t) = conn.quote_table_name(t)
      def qcn(c) = "#{qtn(name)}.#{conn.quote_column_name(c)}"
    end

    # =======================
    # Phlex views
    # =======================
    class Index < View
      attr_writer :tables

      def view_template
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "Tables" }
          ul(class: "list-disc pl-6 space-y-1") do
            @tables.each do |t|
              li { nav_link t.name, controller: "/monolith/tables", action: :show, id: t.name }
            end
          end
        end
      end
    end

    class Show < View
      attr_writer :table, :rows, :page, :per_page, :total

      def view_template
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { @table.name }
          p do
            plain "Rows "
            strong { "#{start_row}-#{end_row}" }
            plain " of #{@total} (per page: #{@per_page})"
            if @table.primary_key
              span(class: "ml-2 text-sm") { "PK: #{@table.primary_key}" }
            end
          end

          Table @table.columns do
            it.row(col) {
              format_cell(it[col])
            }
          end

          div(class: "flex items-center gap-3") do
            if @page > 1
              nav_link "← Prev", controller: "/monolith/tables", action: :show, id: @table.name, page: @page - 1, per_page: @per_page
            end
            if end_row < @total
              nav_link "Next →", controller: "/monolith/tables", action: :show, id: @table.name, page: @page + 1, per_page: @per_page
            end
            span(class: "text-sm ml-auto") { "Page #{@page}" }
            nav_link "All tables", controller: "/monolith/tables", action: :index
          end
        end
      end

      def start_row = ((@page - 1) * @per_page) + 1
      def end_row = [@page * @per_page, @total].min

      def format_cell(v)
        case v
        when Hash, Array then code { v.ai(plain: true) rescue v.to_json }
        when Time, DateTime, Date then v.iso8601
        else
          v.nil? ? em { "NULL" } : v.to_s
        end
      end
    end
  end
end
