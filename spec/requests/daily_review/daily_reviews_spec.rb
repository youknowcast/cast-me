# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DailyReviews', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:other_user) { create(:user, family: family) }

  describe 'GET /daily_review' do
    context 'when signed out' do
      it 'redirects to sign in' do
        get daily_review_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when signed in' do
      before { sign_in user }

      it 'returns http success' do
        get daily_review_path
        expect(response).to have_http_status(:success)
      end

      it "displays today's own tasks only" do
        create(:task, user: user, family: family, date: Date.current, title: '今日の自分タスク')
        create(:task, user: other_user, family: family, date: Date.current, title: '他人のタスク')
        create(:task, user: user, family: family, date: Date.current - 1, title: '昨日のタスク')

        get daily_review_path

        expect(response.body).to include('今日の自分タスク')
        expect(response.body).not_to include('他人のタスク')
        expect(response.body).not_to include('昨日のタスク')
      end

      it "displays today's meals" do
        meal = create(:meal, family: family, date: Date.current)
        create(:meal_food, meal: meal, food: create(:food, family: family, name: 'カレーライス'))

        get daily_review_path

        expect(response.body).to include('カレーライス')
      end

      it 'includes a meal registration button' do
        get daily_review_path
        expect(response.body).to include('openMealForm')
      end

      it 'carries return_to on meal edit and delete controls' do
        meal = create(:meal, family: family, date: Date.current)
        create(:meal_food, meal: meal, food: create(:food, family: family))

        get daily_review_path

        expect(response.body).to include('data-return-to="daily_review"')
        expect(response.body).to include('return_to=daily_review')
      end

      it 'includes the recipe note app link' do
        get daily_review_path
        expect(response.body).to include('id1636414129')
      end
    end
  end
end
