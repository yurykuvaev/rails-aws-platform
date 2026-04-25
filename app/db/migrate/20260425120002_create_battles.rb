class CreateBattles < ActiveRecord::Migration[7.1]
  def change
    create_table :battles do |t|
      t.references :attacker,        null: false, foreign_key: { to_table: :characters }
      t.references :defender,        null: false, foreign_key: { to_table: :characters }
      t.references :attacker_player, null: false, foreign_key: { to_table: :players }
      t.references :winner,          null: true,  foreign_key: { to_table: :characters }
      t.integer :status,     null: false, default: 0
      t.integer :turn_count, null: false, default: 0
      t.timestamps
    end
  end
end
