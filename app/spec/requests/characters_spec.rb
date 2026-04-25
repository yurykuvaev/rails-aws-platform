require "rails_helper"

RSpec.describe "Characters API", type: :request do
  let(:player)  { create(:player) }
  let(:headers) { { "X-Api-Token" => player.api_token } }

  describe "POST /characters" do
    it "creates a character with default stats" do
      post "/characters", params: { name: "Pika", element: "electric" }, headers: headers
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to    eq("Pika")
      expect(body["element"]).to eq("electric")
      expect(body["max_hp"]).to  eq(100)
    end
  end

  describe "GET /characters/:id" do
    it "is publicly readable" do
      character = create(:character, player: player)
      get "/characters/#{character.id}"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /characters/:id/heal" do
    it "restores HP for the owner" do
      character = create(:character, player: player, current_hp: 10, max_hp: 100,
                                     updated_at: 2.minutes.ago)
      post "/characters/#{character.id}/heal", headers: headers
      expect(response).to have_http_status(:ok)
      expect(character.reload.current_hp).to eq(100)
    end

    it "returns 429 if the cooldown is active" do
      character = create(:character, player: player, updated_at: 1.second.ago)
      post "/characters/#{character.id}/heal", headers: headers
      expect(response).to have_http_status(:too_many_requests)
    end

    it "returns 403 for non-owners" do
      other = create(:player)
      character = create(:character, player: other, updated_at: 2.minutes.ago)
      post "/characters/#{character.id}/heal", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
