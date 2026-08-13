class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :nombre, null: false

      # Tag del jugador en Clash of Clans (#LJ8V90G0). Es la llave con la que
      # se sincroniza contra la API oficial; las cuentas cargadas a mano
      # pueden no tenerlo.
      t.string :tag_coc

      t.integer :town_hall
      t.integer :builder_hall
      t.integer :orden, null: false, default: 0

      # Pestaña del Google Sheet de la que se importo, como trazabilidad.
      t.string :gid_origen

      t.datetime :sincronizado_en

      t.timestamps
    end

    add_index :accounts, :nombre, unique: true
    add_index :accounts, :tag_coc, unique: true
    add_index :accounts, :gid_origen, unique: true
    add_index :accounts, :orden
  end
end
