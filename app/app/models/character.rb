class Character < ApplicationRecord
  MAX_PER_PLAYER = 5

  belongs_to :player
  has_many :battle_turns_as_attacker, class_name: "BattleTurn",
                                      foreign_key: "attacker_character_id",
                                      dependent: :nullify
  has_many :battle_turns_as_defender, class_name: "BattleTurn",
                                      foreign_key: "defender_character_id",
                                      dependent: :nullify

  enum element: { fire: 0, water: 1, grass: 2, electric: 3 }

  validates :name, presence: true
  validates :element, presence: true
  validate  :player_character_limit, on: :create

  scope :alive,    -> { where(is_alive: true) }
  scope :top_wins, -> { order(wins: :desc, level: :desc).limit(20) }

  def alive?
    current_hp.positive? && is_alive
  end

  def battles_history
    Battle.where("attacker_id = :id OR defender_id = :id", id: id)
          .order(created_at: :desc)
  end

  private

  def player_character_limit
    return unless player

    if player.characters.count >= MAX_PER_PLAYER
      errors.add(:base, "player has reached the maximum of #{MAX_PER_PLAYER} characters")
    end
  end
end
