require 'rails_helper'

RSpec.describe 'Meals', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  before { sign_in user, scope: :user }

  describe 'POST /meals' do
    let(:params) do
      {
        meal: { date: Time.zone.today.to_s, meal_type: 1, user_id: '',
                food_names: %W[\u30E9\u30FC\u30E1\u30F3 \u9903\u5B50] },
        scope: 'family'
      }
    end

    it 'creates a meal with foods (find_or_create master)' do
      expect do
        post meals_path, params: params, as: :turbo_stream
      end.to change(Meal, :count).by(1).and change(Food, :count).by(2).and change(MealFood, :count).by(2)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream action="update" target="daily_details"')
      expect(Meal.last.user_id).to be_nil
    end

    it 'reuses an existing food master' do
      create(:food, family: family, name: 'ラーメン')
      expect do
        post meals_path,
             params: { meal: { date: Time.zone.today.to_s, meal_type: 1, food_names: ['ラーメン'] },
                       scope: 'family' }, as: :turbo_stream
      end.to change(Meal, :count).by(1)
      expect(Food.count).to eq(1)
    end

    it 'does not create a meal attributed to a user from another family' do
      stranger = create(:user)
      expect do
        post meals_path,
             params: { meal: { date: Time.zone.today.to_s, meal_type: 1, user_id: stranger.id, food_names: ['ラーメン'] },
                       scope: 'family' },
             as: :turbo_stream
      end.not_to change(Meal, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a meal with no foods' do
      expect do
        post meals_path,
             params: { meal: { date: Time.zone.today.to_s, meal_type: 1, food_names: [] },
                       scope: 'family' }, as: :turbo_stream
      end.not_to change(Meal, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /meals/:id' do
    let(:meal) { create(:meal, family: family, user: user, meal_type: 1) }

    before do
      create(:meal_food, meal: meal, food: create(:food, family: family, name: '古い'))
    end

    it 'replaces the foods' do
      patch meal_path(meal),
            params: { meal: { date: meal.date.to_s, meal_type: 2, food_names: ['新しい'] },
                      scope: 'family' }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(meal.reload.foods.map(&:name)).to eq(['新しい'])
      expect(meal.meal_type).to eq(2)
    end

    it 'does not update a meal from another family' do
      other = create(:meal)
      expect do
        patch meal_path(other), params: { meal: { date: other.date.to_s, meal_type: 1, food_names: ['x'] } },
                                as: :turbo_stream
      end
        .to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'rolls back foods when the update is invalid' do
      patch meal_path(meal),
            params: { meal: { date: meal.date.to_s, meal_type: 9, food_names: ['新しい'] }, scope: 'family' },
            as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_entity)
      expect(meal.reload.foods.map(&:name)).to eq(['古い'])
    end
  end

  describe 'DELETE /meals/:id' do
    it 'destroys the meal' do
      meal = create(:meal, family: family, user: user)
      create(:meal_food, meal: meal, food: create(:food, family: family))
      expect do
        delete meal_path(meal), as: :turbo_stream
      end.to change(Meal, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /meals/new' do
    it 'renders the form with frequently used foods as quick buttons' do
      create(:food, family: family, name: 'ラーメン', active: true)
      get new_meal_path(date: Time.zone.today.to_s, scope: 'family'), as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('meal-food')
      expect(response.body).to include('ラーメン')
    end
  end

  describe 'GET /meals/:id/edit' do
    it 'pre-fills chips with existing foods' do
      meal = create(:meal, family: family, user: user, meal_type: 1)
      create(:meal_food, meal: meal, food: create(:food, family: family, name: 'カレー'))
      get edit_meal_path(meal, scope: 'family'), as: :turbo_stream
      expect(response.body).to include('カレー')
      expect(response.body).to include('meal[food_names][]')
    end
  end
end
