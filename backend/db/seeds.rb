# Crea el primer superadmin. No hay registro publico, asi que sin esto no hay
# forma de entrar al panel.
#
# La contraseña se toma de una variable de entorno: dejarla escrita aca la
# publicaria en el historial de git, que es exactamente como se filtran las
# credenciales de produccion.
#
#   ADMIN_EMAIL=vos@ejemplo.com ADMIN_PASSWORD=... bin/rails db:seed

email = ENV["ADMIN_EMAIL"]
password = ENV["ADMIN_PASSWORD"]

if email.blank? || password.blank?
  puts "Seed omitido: definí ADMIN_EMAIL y ADMIN_PASSWORD para crear el superadmin."
else
  usuario = User.find_or_initialize_by(email: email)
  usuario.password = password
  usuario.rol = "superadmin"
  usuario.save!

  puts "Superadmin listo: #{usuario.email}"
end
