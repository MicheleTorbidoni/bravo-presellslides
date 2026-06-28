Rails.application.routes.draw do
  get  "login",  to: "sessions#new",     as: :login
  post "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  get  "signup", to: "registrations#new",    as: :signup
  post "signup", to: "registrations#create"

  resources :passwords, param: :token, only: %i[ new create edit update ]

  get "dashboard", to: "dashboard#show", as: :dashboard
  get "settings",  to: "settings#show",  as: :settings

  resources :presale_sessions, only: %i[ index create update destroy ] do
    member do
      get :setup
      get :profiling
      get :result
      get :present
      get :debrief
      post :recap
    end
  end

  # Inbound HubSpot webhooks (Fase 3, currently simulated). Server-to-server,
  # signature-authenticated — see Integrations::Hubspot::BaseController.
  namespace :integrations do
    namespace :hubspot do
      post "appointments", to: "appointments#create"
    end
  end

  # Public, token-gated recap page sent to the prospect after the call. No login:
  # the unguessable token in the path is the only credential (see PublicRecapsController).
  get "/r/:token", to: "public_recaps#show", as: :public_recap
  # The follow-up appointment as a downloadable .ics (same token gate).
  get "/r/:token/calendar.ics", to: "public_recaps#calendar", as: :public_recap_calendar

  # Serves the prospect-facing slide bitmaps at runtime from content/assets/
  # (which is outside the web root). The slide player receives already-resolved
  # URLs whose :dir is either "criticalities" (shared) or a segment id (override)
  # — see PresentationAssetsController and ContentConfig.steps_for.
  get "presentation_assets/:dir/:filename",
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
