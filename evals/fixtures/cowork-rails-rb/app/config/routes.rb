Rails.application.routes.draw do
  namespace :api do
    resources :bookings, only: [:create, :update, :destroy, :show]
  end

  post "/webhooks/payments", to: "webhooks#payments"
  get "/health", to: "health#show"
end
