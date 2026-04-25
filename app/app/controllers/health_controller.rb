class HealthController < ApplicationController
  def show
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: {
      status: "ok",
      db: "connected",
      uptime_seconds: (Time.current - Rails.application.config.boot_time).to_i
    }
  rescue StandardError => e
    render json: { status: "error", db: "down", error: e.message },
           status: :service_unavailable
  end
end
