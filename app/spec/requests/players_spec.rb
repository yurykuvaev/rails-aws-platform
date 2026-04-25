require "rails_helper"

RSpec.describe "Players API", type: :request do
  describe "POST /players" do
    it "creates a player and returns api_token" do
      post "/players", params: { username: "ash" }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["username"]).to eq("ash")
      expect(body["api_token"]).to be_present
    end
  end

  describe "GET /players/me" do
    let(:player) { create(:player) }

    it "returns the current player and characters" do
      create(:character, player: player, name: "Pika")
      get "/players/me", headers: { "X-Api-Token" => player.api_token }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["username"]).to     eq(player.username)
      expect(body["characters"].first["name"]).to eq("Pika")
    end

    it "returns 401 without a token" do
      get "/players/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
