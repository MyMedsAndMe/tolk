Tolk::Engine.routes.draw do
  root to: "locales#index"

  post "/dump_all" => "locales#dump_all", as: :dump_all_locales
  post "sync_locales" => "locales#sync", as: :sync_locales
  get "/stats" => "locales#stats"
  get "/export" => "export#show"

  resources :locales do
    member do
      get :all
      get :completed
      get :updated
    end
  end
  resource :search
end
