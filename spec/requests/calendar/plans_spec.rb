require 'rails_helper'

RSpec.describe 'Plans', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:other_user) { create(:user, family: family) }
  let(:plan) { create(:plan, family: family, created_by: user, date: Time.zone.today) }

  before do
    sign_in user, scope: :user
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

      it 'creates an independent plan for each selected date', :aggregate_failures do
        dates = [Time.zone.today, Time.zone.tomorrow, Time.zone.today + 1.week]
        params = valid_params.deep_dup
        params[:plan].delete(:date)
        params[:plan][:dates] = dates.map(&:to_s)

        expect do
          post plans_path, params: params, as: :turbo_stream
        end.to change(Plan, :count).by(3)

        created_plans = Plan.order(:date).last(3)
        expect(created_plans.map(&:date)).to eq(dates.sort)
        expect(created_plans.map(&:title).uniq).to eq(['New Plan'])
        expect(created_plans).to all(have_attributes(created_by: user, last_edited_by: user))
        expect(created_plans.map { |plan| plan.participant_ids.sort }.uniq).to eq([[user.id, other_user.id].sort])
        dates.each do |date|
          expect(response.body).to include("target=\"calendar-cell-#{date}\"")
        end
      end

      it 'creates only one plan for duplicate selected dates' do
        params = valid_params.deep_dup
        params[:plan].delete(:date)
        params[:plan][:dates] = [Time.zone.today.to_s, Time.zone.today.to_s]

        expect do
          post plans_path, params: params, as: :turbo_stream
        end.to change(Plan, :count).by(1)
      end

      it 'does not create plans when a selected date is invalid' do
        params = valid_params.deep_dup
        params[:plan].delete(:date)
        params[:plan][:dates] = [Time.zone.today.to_s, 'invalid-date']

        expect do
          post plans_path, params: params, as: :turbo_stream
        end.not_to change(Plan, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('を1日以上選択してください')
      end

      it 'notifies newly added participants only once for a multi-date submission' do
        allow(PushNotificationService).to receive(:send_to_users)
        params = valid_params.deep_dup
        params[:plan].delete(:date)
        params[:plan][:dates] = [Time.zone.today, Time.zone.tomorrow, Time.zone.today + 2.days].map(&:to_s)

        post plans_path, params: params, as: :turbo_stream

        expect(PushNotificationService).to have_received(:send_to_users).once
      end

      it 'shows a flash notice in the turbo_stream response' do
        params = valid_params.deep_dup
        params[:plan].delete(:date)
        params[:plan][:dates] = [Time.zone.today, Time.zone.tomorrow].map(&:to_s)

        post plans_path, params: params, as: :turbo_stream

        expect(response.body).to include('turbo-stream action="replace" target="flash"')
        expect(response.body).to include('予定を2件作成しました')
      end

      it 'accepts non-ISO date formats' do
        params = valid_params.deep_dup
        params[:plan].delete(:date)
        params[:plan][:dates] = ['2026/06/28']

        expect do
          post plans_path, params: params, as: :turbo_stream
        end.to change(Plan, :count).by(1)

        expect(Plan.last.date).to eq(Date.new(2026, 6, 28))
      end

      it 'renders a multi-date selector for a new plan' do
        get new_plan_path, params: { date: Time.zone.today, scope: 'family' }, as: :turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('data-controller="multi-datepicker-connector"')
        expect(response.body).to include('name="plan[dates][]"')
      end
    end

    context 'with html' do
      it 'creates a new plan and redirects' do
        post plans_path, params: valid_params
        expect(response).to redirect_to(calendar_path)
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

      it 'does not update a plan from another family' do
        other_plan = create(:plan, title: 'Other family plan')

        expect do
          patch plan_path(other_plan), params: update_params, as: :turbo_stream
        end.to raise_error(ActiveRecord::RecordNotFound)

        expect(other_plan.reload.title).to eq('Other family plan')
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

    it 'keeps the my calendar scope in turbo_stream' do
      plan.participants << user
      other_plan = create(:plan, family: family, title: 'Other family plan', date: plan.date)
      other_plan.participants << other_user

      delete plan_path(plan), params: { scope: 'my', date: plan.date }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(other_plan.title)
    end

    it 'does not destroy a plan from another family' do
      other_plan = create(:plan)

      expect do
        delete plan_path(other_plan), as: :turbo_stream
      end.to raise_error(ActiveRecord::RecordNotFound)

      expect(Plan.exists?(other_plan.id)).to be true
    end
  end
end
