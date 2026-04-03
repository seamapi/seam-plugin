Rails.application.routes.draw do
  namespace :api do
    resources :reservations, only: [:create, :update, :destroy, :show]
  end

  post "/webhooks/payments", to: "webhooks#payments"
  get "/health", to: "health#show"
end
