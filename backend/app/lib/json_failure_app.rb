# Respuesta de Devise cuando la autenticacion falla.
#
# Por defecto Devise contesta con sus mensajes en ingles y, segun el formato de
# la peticion, hasta con texto plano. Siendo una API consumida por el frontend,
# conviene que siempre responda JSON y en el mismo idioma que el resto.
class JsonFailureApp < Devise::FailureApp
  def respond
    self.status = 401
    self.content_type = "application/json"
    self.response_body = { error: mensaje }.to_json
  end

  private

  def mensaje
    case warden_message
    when :invalid, :not_found_in_database
      "Email o contraseña invalidos."
    when :unauthenticated
      "Necesitas iniciar sesion."
    else
      "No se pudo autenticar la peticion."
    end
  end
end
