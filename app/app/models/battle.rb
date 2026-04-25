class Battle < ApplicationRecord
  belongs_to :attacker,        class_name: "Character"
  belongs_to :defender,        class_name: "Character"
  belongs_to :attacker_player, class_name: "Player"
  belongs_to :winner,          class_name: "Character", optional: true
  has_many :battle_turns, -> { order(:turn_number) }, dependent: :destroy

  enum status: { pending: 0, in_progress: 1, completed: 2 }

  validate :different_characters
  validate :both_combatants_alive, on: :create

  private

  def different_characters
    return unless attacker_id && defender_id

    errors.add(:base, "attacker and defender must be different characters") if attacker_id == defender_id
  end

  def both_combatants_alive
    errors.add(:attacker, "is not alive") if attacker && !attacker.alive?
    errors.add(:defender, "is not alive") if defender && !defender.alive?
  end
end
