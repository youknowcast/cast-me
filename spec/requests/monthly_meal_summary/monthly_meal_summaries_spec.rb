# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MonthlyMealSummaries', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  def create_meal_with_food(family:, date:, food_name:, meal_type: 0)
    meal = create(:meal, family: family, date: date, meal_type: meal_type)
    food = create(:food, family: family, name: food_name)
    create(:meal_food, meal: meal, food: food)
    meal
  end

  describe 'GET /monthly_meal_summary' do
    context 'when not signed in' do
      it 'redirects to sign in' do
        get monthly_meal_summary_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when signed in' do
      before { sign_in user }

      it 'shows current month meals by default' do
        create_meal_with_food(family: family, date: Date.current.beginning_of_month, food_name: '納豆')

        get monthly_meal_summary_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('納豆')
        expect(response.body).to include(Date.current.strftime('%Y年%m月'))
      end

      it 'shows only meals of the specified month' do
        create_meal_with_food(family: family, date: Date.new(2026, 7, 10), food_name: 'カレー')
        create_meal_with_food(family: family, date: Date.new(2026, 8, 10), food_name: 'うどん')

        get monthly_meal_summary_path(month: '2026-07')

        expect(response.body).to include('カレー')
        expect(response.body).not_to include('うどん')
        expect(response.body).to include('2026年07月')
      end

      it 'does not show meals of other families' do
        other_family = create(:family)
        create_meal_with_food(family: other_family, date: Date.current.beginning_of_month, food_name: '他家族の食事')

        get monthly_meal_summary_path

        expect(response.body).not_to include('他家族の食事')
      end

      it 'falls back to current month for an invalid month param' do
        get monthly_meal_summary_path(month: 'invalid')

        expect(response).to have_http_status(:success)
        expect(response.body).to include(Date.current.strftime('%Y年%m月'))
      end

      it 'shows meal type labels' do
        create_meal_with_food(family: family, date: Date.current.beginning_of_month, food_name: 'ごはん', meal_type: 0)

        get monthly_meal_summary_path

        expect(response.body).to include('朝')
      end
    end
  end
end
