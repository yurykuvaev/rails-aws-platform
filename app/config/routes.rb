Rails.application.routes.draw do
  get  "/health",      to: "health#show"
  get  "/leaderboard", to: "leaderboard#index"

  resources :players, only: [:create] do
    collection do
      get :me
    end
  end

  resources :characters, only: [:create, :show] do
    member do
      post :heal
    end
  end

  resources :battles, only: [:create, :show] do
    member do
      post :attack
    end
  end
end
