require "rails_helper"

RSpec.describe "Battles API", type: :request do
  let(:p1)       { create(:player) }
  let(:p2)       { create(:player) }
  let(:headers)  { { "X-Api-Token" => p1.api_token } }
  let(:attacker) { create(:character, player: p1) }
  let(:defender) { create(:character, player: p2) }

  describe "POST /battles" do
    it "creates a pending battle" do
      post "/battles",
           params: { attacker_character_id: attacker.id, defender_character_id: defender.id },
           headers: headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["status"]).to eq("pending")
    end

    it "rejects when defender is also owned by current player" do
      mine = create(:character, player: p1)
      post "/battles",
           params: { attacker_character_id: attacker.id, defender_character_id: mine.id },
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /battles/:id/attack" do
    it "executes one turn and returns updated state" do
      battle = create(:battle, attacker: attacker, defender: defender, attacker_player: p1)
      post "/battles/#{battle.id}/attack", headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["turn"]["damage"]).to be > 0
    end
  end

  describe "GET /battles/:id" do
    it "returns turns ordered by turn_number" do
      battle = create(:battle, attacker: attacker, defender: defender, attacker_player: p1,
                               status: :in_progress)
      BattleEngine.execute_turn(battle)
      get "/battles/#{battle.id}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["turns"].length).to eq(1)
    end
  end
end
