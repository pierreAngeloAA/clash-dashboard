# Genera el inventario de una cuenta a partir del catalogo y de su ayuntamiento.
#
# Al crear una cuenta de TH9 se le crean los heroes, animales y edificaciones
# que un TH9 tiene disponibles, en la cantidad que corresponde (seis canones, no
# uno) y con el tope de nivel de ese ayuntamiento. Todo arranca en nivel 0:
# disponible pero no liberado.
#
# Es idempotente: volver a correrlo sobre una cuenta existente agrega lo que
# falte sin tocar lo que ya tiene progreso cargado.
class PoblarCuenta
  def initialize(account)
    @account = account
  end

  def call
    return 0 if account.town_hall.blank?

    creados = 0

    GameItem.includes(:game_item_town_halls).find_each do |game_item|
      disponibilidad = disponibilidad_de(game_item)
      next if disponibilidad.nil?

      creados += crear_faltantes(game_item, disponibilidad)
      subir_topes(game_item, disponibilidad)
    end

    creados
  end

  private

  attr_reader :account

  # Devuelve { cantidad:, max_level: } o nil si el ayuntamiento de la cuenta
  # todavia no desbloqueo el elemento.
  def disponibilidad_de(game_item)
    return nil if game_item.desbloquea_en_th > account.town_hall

    # Se toma la fila del ayuntamiento exacto y, si no existe, la del
    # ayuntamiento mas alto que no lo supere: el catalogo solo necesita cargar
    # los TH en los que algo cambia.
    fila = game_item.game_item_town_halls
      .select { |th| th.town_hall <= account.town_hall }
      .max_by(&:town_hall)

    return { cantidad: fila.cantidad, max_level: fila.max_level } if fila

    # Sin datos por ayuntamiento se asume una unidad al maximo del juego.
    { cantidad: 1, max_level: game_item.max_level }
  end

  def crear_faltantes(game_item, disponibilidad)
    ya_tiene = account.account_items.where(game_item: game_item).pluck(:indice).to_set
    clase = game_item.clase_de_progreso
    creados = 0

    (1..disponibilidad[:cantidad]).each do |indice|
      next if ya_tiene.include?(indice)

      clase.create!(
        account: account,
        game_item: game_item,
        indice: indice,
        current_level: 0,
        max_level: disponibilidad[:max_level],
        fuente: "manual"
      )
      creados += 1
    end

    creados
  end

  # Subir de ayuntamiento no solo habilita elementos nuevos: tambien sube el tope
  # de los que la cuenta ya tenia. Sin esto un canon de una cuenta que paso de
  # TH15 a TH16 seguiria diciendo que su maximo es el de TH15, y el porcentaje de
  # progreso quedaria inflado.
  #
  # El tope solo sube. Bajar de ayuntamiento no le quita niveles a lo que ya esta
  # construido, y ademas dejaria elementos con current_level mayor que su maximo.
  #
  # Se actualiza en bloque porque subir el tope no puede invalidar nada: el nivel
  # actual ya era menor o igual al tope anterior, que es menor que el nuevo.
  def subir_topes(game_item, disponibilidad)
    account.account_items
      .where(game_item: game_item)
      .where(max_level: ...disponibilidad[:max_level])
      .update_all(max_level: disponibilidad[:max_level])
  end
end
