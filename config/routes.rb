Monolith::Engine.routes.draw do
  root to: "emails#index"

  resources :emails, only: [:index, :show]
  resources :tables, only: [:index, :show]
  resources :gems, only: [:index, :show]
  resources :routes, only: [:index, :show]
  resources :models, only: [:index, :show]
  resources :generators, only: [:index, :show] do
    member do
      post :create
    end
  end
  
  get "/exceptions/:id", to: "exceptions#show", as: :exception
end