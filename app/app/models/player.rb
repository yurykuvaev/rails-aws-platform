require "securerandom"

class Player < ApplicationRecord
  has_many :characters, dependent: :destroy
  has_many :battles_initiated, class_name: "Battle",
                               foreign_key: "attacker_player_id",
                               dependent: :nullify

  validates :username,  presence: true, uniqueness: true
  validates :api_token, presence: true, uniqueness: true

  before_validation :generate_api_token, on: :create

  private

  def generate_api_token
    self.api_token ||= SecureRandom.hex(16)
  end
end
