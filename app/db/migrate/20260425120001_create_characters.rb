class CreateCharacters < ActiveRecord::Migration[7.1]
  def change
    create_table :characters do |t|
      t.references :player, null: false, foreign_key: true
      t.string  :name,       null: false
      t.integer :level,      null: false, default: 1
      t.integer :experience, null: false, default: 0
      t.integer :max_hp,     null: false, default: 100
      t.integer :current_hp, null: false, default: 100
      t.integer :attack,     null: false, default: 10
      t.integer :defense,    null: false, default: 5
      t.integer :speed,      null: false, default: 5
      t.integer :element,    null: false
      t.integer :wins,       null: false, default: 0
      t.integer :losses,     null: false, default: 0
      t.boolean :is_alive,   null: false, default: true
      t.timestamps
    end

    add_index :characters, :wins
    add_index :characters, :element
  end
end
