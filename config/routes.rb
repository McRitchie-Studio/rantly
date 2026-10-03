Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "rants#index"
  resources :rants, only: :show
  get "@:handle", to: "users#show", as: :user, constraints: { handle: /[a-z0-9_]+/ }

  # The legal pages the site footer links (config/initializers/studio.rb).
  get "privacy", to: "legal#privacy", as: :privacy
  get "terms", to: "legal#terms", as: :terms
end
