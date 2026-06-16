Rails.application.routes.draw do
  get  "login",  to: "sessions#new",     as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  get  "signup", to: "registrations#new",    as: :signup
  post "signup", to: "registrations#create"

  resources :passwords, param: :token, only: %i[ new create edit update ]

  get "dashboard", to: "dashboard#show", as: :dashboard
  get "settings",  to: "settings#show",  as: :settings

  resources :presale_sessions, only: %i[ index create update ] do
    member do
      get :setup
      get :profiling
      get :result
      get :present
    end
  end

  # Serves the prospect-facing slide bitmaps at runtime from content/assets/
  # (which is outside the web root). The slide player builds these URLs from the
  # session's segment + the asset name in slides.json — see PresentationAssetsController.
  get "presentation_assets/:segment/:filename",
      to: "presentation_assets#show",
      as: :presentation_asset,
      constraints: { filename: /[^\/]+\.png/ }

  namespace :admin do
    root to: redirect("/admin/users")
    get "design-system", to: "design_system#show", as: :design_system
    resources :users, only: %i[ index show ]
  end

  get   "profile",          to: "profiles#details",          as: :profile
  get   "profile/password", to: "profiles#password",         as: :profile_password
  patch "profile/email",    to: "profiles#update_email"
  patch "profile/password", to: "profiles#update_password"

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
end
