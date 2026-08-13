# Catalogo de lo que existe en Clash of Clans, compartido por todas las cuentas.
#
# Las categorias son exactamente las secciones del Google Sheet, para que la app
# siga mostrando la informacion como el Sheet la organiza.
#
# Se separa del progreso porque un canon es un canon para todos los jugadores:
# su nombre y su nivel maximo son datos del juego, no de la cuenta. Ademas da un
# nombre canonico contra el cual matchear lo que devuelve la API oficial, que
# usa su propia grafia en ingles.
class CreateGameItems < ActiveRecord::Migration[8.1]
  def change
    create_table :game_items do |t|
      # Seccion del Sheet: NIVELES DEFENSAS, TROPAS CLARAS, REY BARBARO, etc.
      t.string :categoria, null: false

      t.string :nombre, null: false

      # Nombre exacto con el que la API oficial devuelve este elemento
      # ("Barbarian King"). Es la llave del matcheo en cada sincronizacion.
      # Queda en null para lo que la API no expone: defensas y trampas.
      t.string :nombre_api

      # Maximo absoluto del juego, sin importar el ayuntamiento.
      t.integer :max_level, null: false

      # Ayuntamiento a partir del cual el elemento existe. Al crear una cuenta
      # solo se le generan los elementos que su ayuntamiento ya desbloqueo.
      t.integer :desbloquea_en_th, null: false, default: 1

      t.integer :orden, null: false, default: 0

      t.timestamps
    end

    add_index :game_items, [ :categoria, :nombre ], unique: true
    add_index :game_items, :nombre_api, unique: true
    add_index :game_items, :categoria

    add_check_constraint :game_items, "max_level > 0", name: "game_items_max_level_positivo"
  end
end
