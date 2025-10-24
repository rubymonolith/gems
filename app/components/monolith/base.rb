class Monolith::Components::Base < Phlex::HTML
  include Phlex::Rails::Helpers::URLFor
  include Phlex::Rails::Helpers::FormAuthenticityToken
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::TurboFrameTag
end
