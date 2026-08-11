class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      # admin edita el progreso; superadmin ademas administra usuarios y el
      # catalogo del juego.
      t.string :rol, null: false, default: "admin"

      # Identificador del token vigente. Cambiarlo invalida el JWT emitido, que
      # es como se cierra sesion sin mantener una tabla de tokens revocados.
      t.string :jti, null: false

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :jti, unique: true
  end
end
