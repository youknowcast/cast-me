require 'rails_helper'

RSpec.describe 'WeeklyDashboard', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family, login_id: 'はは') }
  let(:member) { create(:user, family: family, login_id: 'ちち') }
  let(:week_start) { Date.current.beginning_of_week }

  before { sign_in user }

  describe 'GET /weekly' do
    it 'returns http success' do
      get weekly_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it 'shows a plan in the participating member row' do
      plan = create(:plan, family: family, date: week_start, title: 'バイオリン練習')
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_dashboard_path
      expect(response.body).to include('バイオリン練習')
    end

    it 'shows a shared plan once per participating member' do
      plan = create(:plan, family: family, date: week_start, title: '家族イベント')
      create(:plan_participant, plan: plan, user: user, status: :joined)
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_dashboard_path
      expect(response.body.scan('家族イベント').size).to eq(2)
    end

    it 'hides a plan the member declined' do
      plan = create(:plan, family: family, date: week_start, title: '辞退した予定')
      create(:plan_participant, plan: plan, user: member, status: :declined)
      get weekly_dashboard_path
      expect(response.body).not_to include('辞退した予定')
    end

    it 'does not show plans from another family' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      plan = create(:plan, family: other_family, date: week_start, title: '他家族の予定')
      create(:plan_participant, plan: plan, user: other_user, status: :joined)
      get weekly_dashboard_path
      expect(response.body).not_to include('他家族の予定')
    end

    it 'shows the requested week when week param is given' do
      target = week_start - 1.week
      plan = create(:plan, family: family, date: target, title: '先週の予定')
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_dashboard_path(week: target.to_s)
      expect(response.body).to include('先週の予定')
    end

    it 'falls back to the current week for an invalid week param' do
      get weekly_dashboard_path(week: 'not-a-date')
      expect(response).to have_http_status(:success)
    end
  end

  context 'when not signed in' do
    before { sign_out user }

    it 'redirects to sign in page' do
      get weekly_dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
