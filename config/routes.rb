Rails.application.routes.draw do
  devise_for :users
  devise_scope :user do
    root to: "devise/sessions#new"
  end

  # カレンダー関連
  get 'calendar', to: 'calendar#index'
  get 'calendar/daily_view', to: 'calendar#daily_view'

  # 予定とタスクの管理
  resources :plans
  resources :tasks do
    member do
      patch :toggle
    end
  end

  resources :plan_participants, only: [:update]

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  resources :moments
end
