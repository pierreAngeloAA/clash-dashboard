class ApplicationController < ActionController::API
  include ActionController::MimeResponds

  rescue_from ActiveRecord::RecordNotFound, with: :no_encontrado
  rescue_from ActiveRecord::RecordInvalid, with: :invalido

  private

  # Cualquier escritura exige sesion.
  def autenticar!
    return if current_user

    render json: { error: "Necesitas iniciar sesion." }, status: :unauthorized
  end

  # Administrar usuarios y el catalogo del juego queda reservado al superadmin:
  # tocar el catalogo afecta a todas las cuentas a la vez.
  def exigir_superadmin!
    return if current_user&.superadmin?

    render json: { error: "Necesitas permisos de superadmin." }, status: :forbidden
  end

  def no_encontrado(excepcion)
    render json: { error: "No se encontro #{excepcion.model&.underscore || 'el recurso'}." },
      status: :not_found
  end

  def invalido(excepcion)
    render json: { errors: excepcion.record.errors.full_messages },
      status: :unprocessable_content
  end
end
