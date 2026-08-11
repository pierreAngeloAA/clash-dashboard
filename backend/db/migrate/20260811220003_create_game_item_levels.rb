# Datos de cada nivel de un elemento del catalogo: costo, tiempo de mejora, lo
# que en el Sheet vivia como texto dentro de la celda.
#
# Cuelga del catalogo y no de la cuenta porque subir un canon al nivel 5 cuesta
# lo mismo para todos los jugadores.
class CreateGameItemLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :game_item_levels do |t|
      t.references :game_item, null: false, foreign_key: true
      t.integer :posicion, null: false
      t.string :etiqueta

      t.timestamps
    end

    add_index :game_item_levels, [ :game_item_id, :posicion ], unique: true

    add_check_constraint :game_item_levels, "posicion > 0",
      name: "game_item_levels_posicion_positiva"
  end
end
