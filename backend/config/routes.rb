Rails.application.routes.draw do
  # Devuelve 200 si la app arranca sin excepciones. Lo usan los balanceadores y
  # los monitores de uptime.
  get "up" => "rails/health#show", as: :rails_health_check

  # Registra el mapeo de Devise sin publicar ninguna de sus rutas: no hay
  # registro publico ni recuperacion de contraseña por ahora. Las rutas de
  # sesion se declaran a mano mas abajo, dentro del namespace de la API.
  devise_for :users, skip: :all

  namespace :api do
    namespace :v1 do
      devise_scope :user do
        post "login", to: "sessions#create"
        delete "logout", to: "sessions#destroy"

        # Dentro del scope porque el controlador hereda de Devise y necesita el
        # mapping en el entorno de la peticion.
        get "me", to: "sessions#show"
      end

      # API oficial de Clash of Clans. El tag lleva un "#" que viaja escapado
      # como %23, asi que la restriccion acepta cualquier cosa menos la barra, y
      # se desactiva el formato para que un tag no se confunda con una extension.
      scope constraints: { tag: %r{[^/]+} }, format: false do
        get "clan/:tag", to: "clash#clan"
        get "clan/:tag/currentwar", to: "clash#guerra"
        get "player/:tag", to: "clash#jugador"
      end
      get "coc/health", to: "clash#health"

      # Lectura publica del progreso; escribir exige sesion.
      resources :accounts, only: %i[index show create update destroy] do
        # Traen el progreso real desde la API oficial. Son POST y no GET porque
        # modifican las cuentas.
        post :sincronizar, on: :member
        # Sobre la coleccion: sincroniza de una vez todas las que tienen tag.
        post :sincronizar, on: :collection, action: :sincronizar_todas
        # Anidado porque un elemento no significa nada fuera de su cuenta, y asi
        # el controlador lo busca siempre dentro de ella.
        resources :items, only: :update, controller: "account_items"
      end
    end
  end
end
