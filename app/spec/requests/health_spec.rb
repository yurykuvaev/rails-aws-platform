require "rails_helper"

RSpec.describe "GET /health", type: :request do
  it "returns ok with db connected" do
    get "/health"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("ok")
    expect(body["db"]).to     eq("connected")
    expect(body["uptime_seconds"]).to be >= 0
  end
end
