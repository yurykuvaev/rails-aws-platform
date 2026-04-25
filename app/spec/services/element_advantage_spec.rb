require "rails_helper"

RSpec.describe ElementAdvantage do
  it "returns 2.0 when attacker is strong against defender" do
    expect(ElementAdvantage.lookup("fire", "grass")).to eq(2.0)
    expect(ElementAdvantage.lookup("water", "fire")).to eq(2.0)
    expect(ElementAdvantage.lookup("electric", "water")).to eq(2.0)
  end

  it "returns 0.5 for same element" do
    expect(ElementAdvantage.lookup("fire", "fire")).to eq(0.5)
  end

  it "returns 1.0 with no relation" do
    expect(ElementAdvantage.lookup("electric", "fire")).to eq(1.0)
  end
end
