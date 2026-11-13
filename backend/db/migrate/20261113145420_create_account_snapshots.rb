class CreateAccountSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :account_snapshots do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.date :taken_on, null: false
      t.decimal :progress_pct, precision: 5, scale: 2, null: false
      t.integer :town_hall
      t.integer :trophies
      t.integer :war_stars
      t.integer :donations

      t.timestamps
    end

    # One snapshot per account and day: syncing twice the same day updates it.
    add_index :account_snapshots, %i[account_id taken_on], unique: true
    remove_index :account_snapshots, :account_id
  end
end
