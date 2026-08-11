require "rails_helper"

RSpec.describe "Api::V1::Sessions" do
  let(:password) { "contrasena-larga-123" }
  let!(:usuario) { create(:user, email: "pierre@clash.test", password: password) }

  def login(email: "pierre@clash.test", clave: "contrasena-larga-123")
    post "/api/v1/login", params: { user: { email: email, password: clave } }, as: :json
  end

  def token_de_login
    login
    response.headers["Authorization"]
  end

  describe "POST /api/v1/login" do
    it "devuelve 200 con credenciales validas" do
      login

      expect(response).to have_http_status(:ok)
    end

    it "entrega el token en el header Authorization" do
      login

      expect(response.headers["Authorization"]).to match(/\ABearer .+/)
    end

    it "devuelve los datos del usuario, sin la contraseña" do
      login
      cuerpo = response.parsed_body

      expect(cuerpo["user"]).to include("email" => "pierre@clash.test", "rol" => "admin")
      expect(cuerpo["user"].keys).not_to include("encrypted_password", "jti")
    end

    it "marca si el usuario es superadmin" do
      create(:user, :superadmin, email: "jefe@clash.test", password: password)

      login(email: "jefe@clash.test")

      expect(response.parsed_body.dig("user", "superadmin")).to be(true)
    end

    it "rechaza una contraseña incorrecta" do
      login(clave: "otra-contrasena-larga")

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["Authorization"]).to be_nil
    end

    it "rechaza un email inexistente" do
      login(email: "nadie@clash.test")

      expect(response).to have_http_status(:unauthorized)
    end

    it "explica el fallo en el idioma de la app, no en el de Devise" do
      login(clave: "otra-contrasena-larga")

      expect(response.parsed_body["error"]).to eq("Email o contraseña invalidos.")
    end

    it "responde JSON tambien cuando el cliente no pide JSON" do
      post "/api/v1/login", params: { user: { email: usuario.email, password: "mala" } }

      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body["error"]).to be_present
    end
  end

  describe "GET /api/v1/me" do
    it "devuelve el usuario del token" do
      token = token_de_login

      get "/api/v1/me", headers: { "Authorization" => token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("user", "email")).to eq("pierre@clash.test")
    end

    it "rechaza la peticion sin token" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "rechaza un token inventado" do
      get "/api/v1/me", headers: { "Authorization" => "Bearer token-falso" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/logout" do
    it "cierra la sesion" do
      token = token_de_login

      delete "/api/v1/logout", headers: { "Authorization" => token }

      expect(response).to have_http_status(:ok)
    end

    # Esto es lo que aporta JTIMatcher: el token deja de servir sin mantener
    # una tabla de tokens revocados.
    it "invalida el token emitido: no sirve despues del logout" do
      token = token_de_login

      delete "/api/v1/logout", headers: { "Authorization" => token }
      get "/api/v1/me", headers: { "Authorization" => token }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rota el jti del usuario" do
      jti_original = usuario.jti
      token = token_de_login

      delete "/api/v1/logout", headers: { "Authorization" => token }

      expect(usuario.reload.jti).not_to eq(jti_original)
    end

    it "un logout no invalida la sesion de otro usuario" do
      otro = create(:user, email: "otro@clash.test", password: password)
      token_propio = token_de_login
      login(email: "otro@clash.test")
      token_ajeno = response.headers["Authorization"]

      delete "/api/v1/logout", headers: { "Authorization" => token_propio }
      get "/api/v1/me", headers: { "Authorization" => token_ajeno }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("user", "email")).to eq(otro.email)
    end
  end

  describe "no hay registro publico" do
    it "no existe una ruta para crear usuarios" do
      post "/api/v1/users", params: { user: { email: "colado@clash.test" } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
