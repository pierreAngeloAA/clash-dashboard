# Progreso de una cuenta sobre un elemento del catalogo. Es la tabla que se
# edita: todo lo que se modifica cuelga de account_id, asi que actualizar una
# cuenta nunca puede tocar el progreso de otra.
class CreateAccountItems < ActiveRecord::Migration[8.1]
  def change
    create_table :account_items do |t|
      # Herencia de tabla unica: Heroe, Animal, Defensa, Trampa, TropaClara...
      # Cada seccion del Sheet es una clase real de Ruby colgada de la cuenta,
      # sin pagar nueve tablas con exactamente las mismas columnas.
      t.string :type, null: false

      t.references :account, null: false, foreign_key: true
      t.references :game_item, null: false, foreign_key: true

      # Una cuenta tiene varios canones. Cada uno es una fila con su indice, tal
      # como el Sheet los lista numerados dentro de su seccion.
      t.integer :indice, null: false, default: 1

      # 0 significa disponible por ayuntamiento pero todavia no liberado.
      t.integer :current_level, null: false, default: 0

      # El maximo alcanzable depende del ayuntamiento de la cuenta, asi que no
      # siempre coincide con el max_level global del catalogo.
      t.integer :max_level, null: false

      # De donde salio este dato: sheet (import inicial), api (sincronizacion
      # con Clash of Clans) o manual (lo cargo el superadmin).
      t.string :fuente, null: false, default: "manual"

      # Un dato editado a mano no debe ser pisado por la proxima sincronizacion
      # con la API. La API no conoce defensas ni trampas, y para lo que si
      # conoce el jugador puede querer anotar algo distinto.
      t.boolean :bloqueado, null: false, default: false

      t.datetime :sincronizado_en

      t.timestamps
    end

    add_index :account_items, [ :account_id, :game_item_id, :indice ], unique: true
    add_index :account_items, [ :account_id, :type ]
    add_index :account_items, :fuente

    add_check_constraint :account_items, "indice > 0", name: "account_items_indice_positivo"

    add_check_constraint :account_items,
      "current_level >= 0 AND current_level <= max_level",
      name: "account_items_current_level_dentro_de_rango"

    add_check_constraint :account_items, "max_level > 0",
      name: "account_items_max_level_positivo"
  end
end
