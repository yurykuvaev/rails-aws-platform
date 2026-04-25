FactoryBot.define do
  factory :battle do
    attacker        { create(:character) }
    defender        { create(:character) }
    attacker_player { attacker.player }
    status          { :pending }
  end
end
