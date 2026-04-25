class BattleTurn < ApplicationRecord
  belongs_to :battle
  belongs_to :attacker, class_name: "Character", foreign_key: "attacker_character_id"
  belongs_to :defender, class_name: "Character", foreign_key: "defender_character_id"

  validates :turn_number,       presence: true
  validates :damage_dealt,      presence: true
  validates :defender_hp_after, presence: true
end
