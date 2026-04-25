class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound,    with: :not_found
  rescue_from ActiveRecord::RecordInvalid,     with: :unprocessable

  def current_player
    @current_player ||= begin
      token = request.headers["X-Api-Token"].to_s
      Player.find_by(api_token: token) if token.present?
    end
  end

  def authenticate_player!
    return if current_player

    render json: { error: "invalid or missing API token" }, status: :unauthorized
  end

  private

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable(exception)
    render json: { errors: exception.record.errors.full_messages },
           status: :unprocessable_entity
  end
end
