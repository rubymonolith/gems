class Monolith::Components::Table < Monolith::Components::Base
  def initialize(collection)
    @collection = collection
    @columns = []
  end

  def row(header, &row)
    @columns << [ header, row ]
  end

  def view_template(&)
    vanish(&)

    headers, rows = @columns.transpose

    div(class: "overflow-x-auto") do
      table class: "table" do
        thead do
          tr do
            headers.each do |header|
              th { header }
            end
          end
        end
        tbody do
          @collection.each do |item|
            tr do
              rows.each do |cell|
                td { cell.call item }
              end
            end
          end
        end
      end
    end
  end
end
