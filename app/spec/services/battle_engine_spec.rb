require "rails_helper"

RSpec.describe BattleEngine do
  let(:p1)       { create(:player) }
  let(:p2)       { create(:player) }
  let(:attacker) { create(:character, player: p1, attack: 50, defense: 10) }
  let(:defender) { create(:character, player: p2, attack: 10, defense: 5, current_hp: 200) }
  let(:battle)   { create(:battle, attacker: attacker, defender: defender, attacker_player: p1) }

  before { allow(BattleEngine).to receive(:rand).and_return(0.5) } # disable crit

  it "deals at least 1 damage and reduces defender HP" do
    expect { described_class.execute_turn(battle) }
      .to change { defender.reload.current_hp }
  end

  it "creates a battle turn record" do
    expect { described_class.execute_turn(battle) }
      .to change { battle.battle_turns.count }.by(1)
  end

  it "marks battle completed and sets winner when defender HP hits 0" do
    huge_attacker = create(:character, player: p1, attack: 9999, defense: 5)
    fragile       = create(:character, player: p2, current_hp: 1)
    finishing     = create(:battle, attacker: huge_attacker, defender: fragile,
                                    attacker_player: p1, status: :in_progress)

    described_class.execute_turn(finishing)
    finishing.reload

    expect(finishing.status).to     eq("completed")
    expect(finishing.winner_id).to  eq(huge_attacker.id)
    expect(huge_attacker.reload.wins).to eq(1)
    expect(fragile.reload.losses).to     eq(1)
  end
end
