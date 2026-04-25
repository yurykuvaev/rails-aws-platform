require "rails_helper"

RSpec.describe Player, type: :model do
  it "auto-generates a 32-char hex api_token on create" do
    p = Player.create!(username: "tester")
    expect(p.api_token).to match(/\A[0-9a-f]{32}\z/)
  end

  it "requires a unique username" do
    create(:player, username: "ash")
    dup = Player.new(username: "ash")
    expect(dup).not_to be_valid
    expect(dup.errors[:username]).to include("has already been taken")
  end
end
