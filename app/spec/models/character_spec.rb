require "rails_helper"

RSpec.describe Character, type: :model do
  let(:player) { create(:player) }

  it "requires a name" do
    c = build(:character, player: player, name: nil)
    expect(c).not_to be_valid
  end

  it "limits each player to 5 characters" do
    5.times { create(:character, player: player) }
    extra = build(:character, player: player)
    expect(extra).not_to be_valid
    expect(extra.errors[:base].first).to match(/maximum of 5/)
  end

  describe "#alive?" do
    it "is true when current_hp > 0 and is_alive flag is true" do
      c = create(:character, player: player, current_hp: 50, is_alive: true)
      expect(c).to be_alive
    end

    it "is false when current_hp is 0" do
      c = create(:character, player: player, current_hp: 0, is_alive: false)
      expect(c).not_to be_alive
    end
  end
end
