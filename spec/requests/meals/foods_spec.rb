require 'rails_helper'

RSpec.describe 'Foods', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  before { sign_in user, scope: :user }

  describe 'GET /foods' do
    it 'lists family foods including inactive ones' do
      create(:food, family: family, name: 'ラーメン', active: true)
      create(:food, family: family, name: 'カレー', active: false)
      get foods_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('ラーメン')
      expect(response.body).to include('カレー')
    end
  end

  describe 'POST /foods' do
    it 'creates a food' do
      expect do
        post foods_path, params: { food: { name: '新しい食べ物' } }
      end.to change(Food, :count).by(1)
      expect(response).to redirect_to(foods_path)
    end

    it 'rejects a duplicate name' do
      create(:food, family: family, name: '重複')
      expect do
        post foods_path, params: { food: { name: '重複' } }
      end.not_to change(Food, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /foods/:id' do
    let(:food) { create(:food, family: family, name: '旧名', active: true) }

    it 'renames the food' do
      patch food_path(food), params: { food: { name: '新名' } }
      expect(food.reload.name).to eq('新名')
    end

    it 'toggles active to false' do
      patch food_path(food), params: { food: { active: '0' } }
      expect(food.reload.active).to be(false)
    end

    it 'does not update a food from another family' do
      other = create(:food, name: '他家族')
      expect { patch food_path(other), params: { food: { name: 'x' } } }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
