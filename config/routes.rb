Rails.application.routes.draw do
  mount Rswag::Api::Engine => "/api-docs"
  mount Rswag::Ui::Engine => "/api-docs"

  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      resources :users, only: %i[index show create update destroy]
      delete "users", to: "users#destroy_all" if Rails.env.development? || Rails.env.test?
    end
  end

  match "*unmatched", to: "errors#not_found", via: :all
end
