namespace :sheet do
  desc "Importa el Google Sheet a la base (una sola vez; despues la base manda)"
  task importar: :environment do
    resultado = Sheet::Importador.new(logger: ->(mensaje) { puts mensaje }).call

    puts
    puts "Listo."
    puts "  Cuentas:               #{resultado.cuentas}"
    puts "  Catalogo:              #{resultado.elementos_del_catalogo} elementos"
    puts "  Progreso importado:    #{resultado.progreso} registros"
  end
end
