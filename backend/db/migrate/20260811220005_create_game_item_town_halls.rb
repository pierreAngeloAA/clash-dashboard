# Que da cada ayuntamiento para un elemento del catalogo: cuantas unidades se
# pueden tener y hasta que nivel se pueden subir.
#
# En TH15 hay 7 canones y llegan a nivel 21; en TH9 hay 6 y llegan a 13. Sin
# esta tabla no se puede generar el inventario correcto al crear una cuenta.
class CreateGameItemTownHalls < ActiveRecord::Migration[8.1]
  def change
    create_table :game_item_town_halls do |t|
      t.references :game_item, null: false, foreign_key: true
      t.integer :town_hall, null: false
      t.integer :max_level, null: false
      t.integer :cantidad, null: false, default: 1

      t.timestamps
    end

    add_index :game_item_town_halls, [ :game_item_id, :town_hall ], unique: true

    add_check_constraint :game_item_town_halls, "town_hall > 0",
      name: "game_item_town_halls_th_positivo"
    add_check_constraint :game_item_town_halls, "max_level > 0",
      name: "game_item_town_halls_max_level_positivo"
    add_check_constraint :game_item_town_halls, "cantidad > 0",
      name: "game_item_town_halls_cantidad_positiva"
  end
end
