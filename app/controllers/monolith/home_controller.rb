# app/controllers/monolith/gems_controller.rb
module Monolith
  class HomeController < Monolith::ApplicationController
    class Show < View
      def view_template
        h1(class: "text-6xl") { "Welcome to Monolith!" }
      end
    end
  end
end
