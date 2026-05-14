Rails.application.routes.draw do
  # Health check endpoint for Kamal
  get 'up' => 'rails/health#show', as: :rails_health_check

  # API endpoints
  namespace :api do
    post 'scheduled_notifications/trigger', to: 'scheduled_notifications#trigger'
  end

  devise_for :users
  devise_scope :user do
    root to: 'devise/sessions#new'
  end

  # カレンダー関連
  get 'calendar', to: 'calendar#index'
  get 'calendar/my', to: 'calendar#my', as: :my_calendar
  get 'calendar/daily_view', to: 'calendar#daily_view'
  get 'calendar/monthly_list', to: 'calendar#monthly_list', as: :monthly_list_calendar

  # 予定とタスクの管理
  resources :plans
  resources :calls, only: [:create]
  resources :tasks do
    member do
      patch :toggle
    end
  end

  resources :regular_tasks, only: %i[index create]
  resources :everyday_task_templates do
    member do
      post :bulk_add
    end
    resources :task_templates
  end

  resources :plan_participants, only: [:update]

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  # 設定
  resource :settings, only: %i[show update] do
    patch :update_avatar
    patch :update_notifications
  end

  resources :moments

  resources :articles

  # 週次サマリ
  resource :weekly_summary, only: [:show]

  # API エンドポイント
  namespace :api do
    resource :weekly_notifications, only: [:create]
  end
end
