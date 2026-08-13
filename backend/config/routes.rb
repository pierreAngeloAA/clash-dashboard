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

      # Lectura publica del progreso; escribir exige sesion.
      resources :accounts, only: %i[index show]
    end
  end
end
