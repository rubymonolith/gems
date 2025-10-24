class Monolith::Views::Layouts::Base < Monolith::Views::Base
  def around_template(&)
    html do
      head do
        title { @title }
        meta name: "viewport", content: "width=device-width,initial-scale=1"
        meta charset: "utf-8"
        meta name: "apple-mobile-web-app-capable", content: "yes"
        meta name: "apple-mobile-web-app-status-bar-style", content: "black-translucent"
        csp_meta_tag
        csrf_meta_tags
        stylesheet_link_tag "monolith/tailwind", data_turbo_track: "reload"
        javascript_importmap_tags
      end

      body(&)
    end
  end

  def view_template
    yield self if block_given?
  end
end
