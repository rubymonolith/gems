module Monolith
  class EmailsController < ApplicationController
    before_action do
      Rails.application.eager_load!
      # @emails = ApplicationEmail.descendants

      if params.key? :id
        @email = @emails.find { it.to_s == params.fetch(:id) }
      end
    end

    class Index < View
      attr_writer :emails

      def render_content
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { "Emails" }
          ul(class: "list-disc pl-6 space-y-1") {
            @emails.each do |email|
              li {
                if email.respond_to? :preview
                  nav_link email.to_s, action: :show, id: email.to_s
                else
                  plain email.to_s
                end
              }
            end
          }
        end
      end
    end

    class Show < View
      attr_writer :email

      def render_content
        div(class: "p-6 space-y-4") do
          h1(class: "text-2xl font-bold") { @email.to_s }
          dl(class: "grid grid-cols-1 gap-y-2") {
            dt(class: "font-semibold") { "To:" }
            dd(class: "mb-3") { preview.to }

            dt(class: "font-semibold") { "From:" }
            dd(class: "mb-3") { preview.from }

            dt(class: "font-semibold") { "Subject:" }
            dd(class: "mb-3") { preview.subject }

            dt(class: "font-semibold") { "Body:" }
            dd(class: "whitespace-pre-wrap") { preview.body }
          }
          div(class: "pt-4") { nav_link "← All emails", controller: "/monolith/emails", action: :index }
        end
      end

      def preview
        @email.preview
      end
    end
  end
end
