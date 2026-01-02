require 'rails_helper'

RSpec.describe 'Plans', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:other_user) { create(:user, family: family) }
  let(:plan) { create(:plan, family: family, created_by: user, date: Time.zone.today) }

  before do
    sign_in user
  end

  describe 'POST /plans' do
    let(:valid_params) do
      {
        plan: {
          title: 'New Plan',
          description: 'Description',
          date: Time.zone.today.to_s,
          start_time: '10:00',
          end_time: '11:00',
          participant_ids: [user.id, other_user.id]
        },
        scope: 'family'
      }
    end

    context 'with turbo_stream' do
      it 'creates a new plan and returns success turbo_stream' do
        expect do
          post plans_path, params: valid_params, as: :turbo_stream
        end.to change(Plan, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-stream action="update" target="daily_details"')
        expect(response.body).to include("turbo-stream action=\"replace\" target=\"calendar-cell-#{Time.zone.today}\"")
        expect(response.body).to include('side-panel-closer')
      end

      it 'returns error when params are invalid' do
        post plans_path, params: { plan: { title: '' }, scope: 'family' }, as: :turbo_stream
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('turbo-stream action="update" target="plan-form-container"')
      end

      it 'returns error when no participants are selected' do
        post plans_path,
             params: {
               plan: { title: 'No Participants', date: Time.zone.today.to_s, participant_ids: [] },
               scope: 'family'
             },
             as: :turbo_stream
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('参加者を1人以上選択してください')
      end
    end

    context 'with html' do
      it 'creates a new plan and redirects' do
        post plans_path, params: valid_params
        expect(response).to redirect_to(calendar_path)
        follow_redirect!
        expect(response.body).to include('予定を作成しました')
      end
    end
  end

  describe 'PATCH /plans/:id' do
    let(:update_params) do
      {
        plan: {
          title: 'Updated Plan',
          participant_ids: [user.id]
        },
        scope: 'family'
      }
    end

    context 'with turbo_stream' do
      it 'updates the plan and returns success turbo_stream' do
        patch plan_path(plan), params: update_params, as: :turbo_stream
        expect(response).to have_http_status(:ok)
        plan.reload
        expect(plan.title).to eq('Updated Plan')
        expect(response.body).to include('turbo-stream action="update" target="daily_details"')
        expect(response.body).to include("turbo-stream action=\"replace\" target=\"calendar-cell-#{plan.date}\"")
      end

      it 'returns error when params are invalid' do
        patch plan_path(plan), params: { plan: { title: '' }, scope: 'family' }, as: :turbo_stream
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /plans/:id' do
    it 'destroys the plan and returns success turbo_stream' do
      plan # ensure plan is created
      expect do
        delete plan_path(plan), as: :turbo_stream
      end.to change(Plan, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-stream action="update" target="daily_details"')
      expect(response.body).to include("turbo-stream action=\"replace\" target=\"calendar-cell-#{plan.date}\"")
    end

    it 'destroys the plan and redirects in html' do
      delete plan_path(plan)
      expect(response).to redirect_to(calendar_path)
    end
  end
end
