class CreateBattleTurns < ActiveRecord::Migration[7.1]
  def change
    create_table :battle_turns do |t|
      t.references :battle, null: false, foreign_key: true
      t.integer :turn_number,            null: false
      t.integer :attacker_character_id,  null: false
      t.integer :defender_character_id,  null: false
      t.integer :damage_dealt,           null: false
      t.boolean :critical_hit,           null: false, default: false
      t.integer :defender_hp_after,      null: false
      t.timestamps
    end

    add_index :battle_turns, [:battle_id, :turn_number]
  end
end
