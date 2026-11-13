class AddPlayerStatsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :trophies, :integer
    add_column :accounts, :best_trophies, :integer
    add_column :accounts, :war_stars, :integer
    add_column :accounts, :exp_level, :integer
    add_column :accounts, :donations, :integer
    add_column :accounts, :donations_received, :integer
    add_column :accounts, :clan_name, :string
    add_column :accounts, :clan_tag, :string
    add_column :accounts, :clan_role, :string
    add_column :accounts, :clan_badge_url, :string
  end
end
