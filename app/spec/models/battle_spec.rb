require "rails_helper"

RSpec.describe Battle, type: :model do
  it "rejects same character as attacker and defender" do
    c = create(:character)
    b = build(:battle, attacker: c, defender: c, attacker_player: c.player)
    expect(b).not_to be_valid
    expect(b.errors[:base].first).to match(/different characters/)
  end

  it "rejects creation if defender is dead" do
    dead = create(:character, current_hp: 0, is_alive: false)
    b = build(:battle, defender: dead)
    expect(b).not_to be_valid
  end
end
