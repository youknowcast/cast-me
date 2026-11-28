Rails.application.routes.draw do
  # Health check endpoint for Kamal
  get 'up' => 'rails/health#show', as: :rails_health_check

  devise_for :users
  devise_scope :user do
    root to: 'devise/sessions#new'
  end

  # カレンダー関連
  get 'calendar', to: 'calendar#index'
  get 'calendar/my', to: 'calendar#my', as: :my_calendar
  get 'calendar/daily_view', to: 'calendar#daily_view'
  get 'calendar/monthly_list', to: 'calendar#monthly_list', as: :monthly_list_calendar

  # 家族の利用状況
  get 'usage', to: 'usage_reports#show', as: :usage

  # 週間家族ダッシュボード
  get 'weekly', to: 'weekly_dashboard#show', as: :weekly_dashboard
  get 'weekly/cell', to: 'weekly_dashboard#cell', as: :weekly_cell
  get 'weekly/memo', to: 'weekly_dashboard#edit_memo', as: :weekly_memo
  patch 'weekly/memo', to: 'weekly_dashboard#update_memo'

  # 予定とタスクの管理
  resources :plans
  resources :calls, only: [:create]
  resources :tasks do
    member do
      patch :toggle
    end
  end

  resources :regular_tasks, only: %i[index create]
  resources :foods, only: %i[index create update]
  resources :medications, only: %i[index create update]
  resources :health_episodes, only: %i[show new create edit update] do
    member do
      patch :recover
      patch :reopen
    end
    resources :temperatures, only: %i[create update destroy], controller: 'health_episode_temperatures'
    resources :reminder_times, only: %i[create destroy], controller: 'health_episode_reminder_times'
  end
  resources :meals, only: %i[new create edit update destroy]
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

  # 週次サマリ
  resource :weekly_summary, only: [:show]

  # リリースノート
  resources :release_notes, only: [:index]

  # 一日のふりかえり
  resource :daily_review, only: [:show]

  # 月間食事一覧
  resource :monthly_meal_summary, only: [:show]

  # API エンドポイント
  namespace :api do
    resource :weekly_notifications, only: [:create]

    namespace :v1 do
      get 'today', to: 'today#index'
      get 'tasks', to: 'tasks#index'
      get 'input_status', to: 'input_status#index'

      namespace :family do
        get 'members', to: 'members#index'
      end
    end
  end
end
