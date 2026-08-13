# Los poderes de heroe (hero equipment) ya existian como Guardian, pero colgaban
# sueltos de la cuenta. En el juego cada poder pertenece a un heroe: el
# Guantelete Gigante es del Rey Barbaro y el Escudo Real de la Reina Arquera.
#
# Se agregan dos datos distintos:
#
#   - `game_items.heroe_categoria`: a que heroe pertenece el poder. Es del
#     catalogo, porque vale igual para todas las cuentas.
#   - `account_items.heroe_id`: el heroe concreto de esa cuenta. Es una
#     autorreferencia porque heroes y poderes viven en la misma tabla.
class RelacionaLosPoderesConSuHeroe < ActiveRecord::Migration[8.1]
  def change
    add_column :game_items, :heroe_categoria, :string
    add_index :game_items, :heroe_categoria

    # Nullable: un poder recien importado del Sheet todavia no sabe de que heroe
    # es, porque el Sheet no lo dice. Se completa cuando el catalogo lo declara.
    add_reference :account_items, :heroe,
      null: true,
      foreign_key: { to_table: :account_items },
      index: true
  end
end
