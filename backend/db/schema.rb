# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_13_180001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_items", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.boolean "bloqueado", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "current_level", default: 0, null: false
    t.string "fuente", default: "manual", null: false
    t.bigint "game_item_id", null: false
    t.bigint "heroe_id"
    t.integer "indice", default: 1, null: false
    t.integer "max_level", null: false
    t.datetime "sincronizado_en"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "game_item_id", "indice"], name: "index_account_items_on_account_id_and_game_item_id_and_indice", unique: true
    t.index ["account_id", "type"], name: "index_account_items_on_account_id_and_type"
    t.index ["account_id"], name: "index_account_items_on_account_id"
    t.index ["fuente"], name: "index_account_items_on_fuente"
    t.index ["game_item_id"], name: "index_account_items_on_game_item_id"
    t.index ["heroe_id"], name: "index_account_items_on_heroe_id"
    t.check_constraint "current_level >= 0 AND current_level <= max_level", name: "account_items_current_level_dentro_de_rango"
    t.check_constraint "indice > 0", name: "account_items_indice_positivo"
    t.check_constraint "max_level > 0", name: "account_items_max_level_positivo"
  end

  create_table "accounts", force: :cascade do |t|
    t.integer "builder_hall"
    t.datetime "created_at", null: false
    t.string "gid_origen"
    t.string "nombre", null: false
    t.integer "orden", default: 0, null: false
    t.datetime "sincronizado_en"
    t.string "tag_coc"
    t.integer "town_hall"
    t.datetime "updated_at", null: false
    t.index ["gid_origen"], name: "index_accounts_on_gid_origen", unique: true
    t.index ["nombre"], name: "index_accounts_on_nombre", unique: true
    t.index ["orden"], name: "index_accounts_on_orden"
    t.index ["tag_coc"], name: "index_accounts_on_tag_coc", unique: true
  end

  create_table "game_item_levels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "etiqueta"
    t.bigint "game_item_id", null: false
    t.integer "posicion", null: false
    t.datetime "updated_at", null: false
    t.index ["game_item_id", "posicion"], name: "index_game_item_levels_on_game_item_id_and_posicion", unique: true
    t.index ["game_item_id"], name: "index_game_item_levels_on_game_item_id"
    t.check_constraint "posicion > 0", name: "game_item_levels_posicion_positiva"
  end

  create_table "game_item_town_halls", force: :cascade do |t|
    t.integer "cantidad", default: 1, null: false
    t.datetime "created_at", null: false
    t.bigint "game_item_id", null: false
    t.integer "max_level", null: false
    t.integer "town_hall", null: false
    t.datetime "updated_at", null: false
    t.index ["game_item_id", "town_hall"], name: "index_game_item_town_halls_on_game_item_id_and_town_hall", unique: true
    t.index ["game_item_id"], name: "index_game_item_town_halls_on_game_item_id"
    t.check_constraint "cantidad > 0", name: "game_item_town_halls_cantidad_positiva"
    t.check_constraint "max_level > 0", name: "game_item_town_halls_max_level_positivo"
    t.check_constraint "town_hall > 0", name: "game_item_town_halls_th_positivo"
  end

  create_table "game_items", force: :cascade do |t|
    t.string "categoria", null: false
    t.datetime "created_at", null: false
    t.integer "desbloquea_en_th", default: 1, null: false
    t.string "heroe_categoria"
    t.integer "max_level", null: false
    t.string "nombre", null: false
    t.string "nombre_api"
    t.integer "orden", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["categoria", "nombre"], name: "index_game_items_on_categoria_and_nombre", unique: true
    t.index ["categoria"], name: "index_game_items_on_categoria"
    t.index ["heroe_categoria"], name: "index_game_items_on_heroe_categoria"
    t.index ["nombre_api"], name: "index_game_items_on_nombre_api", unique: true
    t.check_constraint "max_level > 0", name: "game_items_max_level_positivo"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "rol", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "account_items", "account_items", column: "heroe_id"
  add_foreign_key "account_items", "accounts"
  add_foreign_key "account_items", "game_items"
  add_foreign_key "game_item_levels", "game_items"
  add_foreign_key "game_item_town_halls", "game_items"
end
