# Permite que el frontend (otro origen) consuma la API.
#
# El header Authorization se expone explicitamente porque es donde Devise-JWT
# devuelve el token al hacer login: sin exponerlo, el navegador se lo oculta al
# JavaScript y el login parece funcionar pero no llega el token.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_URL", "http://localhost:5173")

    resource "*",
      headers: :any,
      expose: [ "Authorization" ],
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
