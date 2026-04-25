class CreatePlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :players do |t|
      t.string :username,  null: false
      t.string :api_token, null: false
      t.timestamps
    end

    add_index :players, :username,  unique: true
    add_index :players, :api_token, unique: true
  end
end
