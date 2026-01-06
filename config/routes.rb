Rails.application.routes.draw do
  # Auth / session endpoints for React
  post   "/registrations", to: "registrations#create"
  post   "/sessions",      to: "sessions#create"
  delete "/logout",        to: "sessions#destroy"
  get    "/logged_in",     to: "sessions#logged_in"

  # Optional: user endpoints if you need them (JSON)
  resources :users, only: [:index, :show]

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end

