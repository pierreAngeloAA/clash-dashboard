module Api
  module V1
    # El token lo emite y lo revoca el middleware de devise-jwt segun las rutas
    # declaradas en config/initializers/devise.rb; aca solo se responde el
    # cuerpo JSON. El JWT viaja en el header Authorization.
    class SessionsController < Devise::SessionsController
      skip_before_action :verify_signed_out_user, only: :destroy
      before_action :autenticar!, only: :show

      def create
        usuario = warden.authenticate!(auth_options)

        render json: { user: usuario_json(usuario) }, status: :ok
      end

      def destroy
        render json: { mensaje: "Sesion cerrada." }, status: :ok
      end

      # Permite al frontend recuperar quien esta logueado tras un refresh, sin
      # tener que decodificar el token del lado del cliente.
      def show
        render json: { user: usuario_json(current_user) }, status: :ok
      end

      private

      def usuario_json(usuario)
        {
          id: usuario.id,
          email: usuario.email,
          rol: usuario.rol,
          superadmin: usuario.superadmin?
        }
      end

      # Cuando las credenciales fallan responde JsonFailureApp, configurado en
      # config/initializers/devise.rb.
    end
  end
end
