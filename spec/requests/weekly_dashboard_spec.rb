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

  describe 'GET /weekly/cell' do
    let(:date) { week_start }
    let(:turbo_headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

    it 'renders a turbo stream updating the side panel with the member plans' do
      plan = create(:plan, family: family, date: date, title: 'テニス')
      create(:plan_participant, plan: plan, user: member, status: :joined)
      get weekly_cell_path(user_id: member.id, date: date.to_s), headers: turbo_headers
      expect(response).to have_http_status(:success)
      expect(response.body).to include('side-panel')
      expect(response.body).to include('テニス')
    end

    it 'does not include plans the member declined' do
      plan = create(:plan, family: family, date: date, title: '辞退した予定')
      create(:plan_participant, plan: plan, user: member, status: :declined)
      get weekly_cell_path(user_id: member.id, date: date.to_s), headers: turbo_headers
      expect(response.body).not_to include('辞退した予定')
    end

    it 'raises RecordNotFound for a member of another family' do
      other = create(:user, family: create(:family))
      expect do
        get weekly_cell_path(user_id: other.id, date: date.to_s), headers: turbo_headers
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'returns 400 for an invalid date' do
      get weekly_cell_path(user_id: member.id, date: 'not-a-date'), headers: turbo_headers
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'day memo' do
    let(:date) { week_start }
    let(:turbo_headers) { { 'Accept' => 'text/vnd.turbo-stream.html' } }

    describe 'GET /weekly/memo' do
      it 'renders the memo form in the side panel' do
        get weekly_memo_path(date: date.to_s), headers: turbo_headers
        expect(response).to have_http_status(:success)
        expect(response.body).to include('side-panel')
        expect(response.body).to include('家族メモ')
      end

      it 'returns 400 for an invalid date' do
        get weekly_memo_path(date: 'not-a-date'), headers: turbo_headers
        expect(response).to have_http_status(:bad_request)
      end
    end

    describe 'PATCH /weekly/memo' do
      it 'creates a memo for the family on that date' do
        patch weekly_memo_path, params: { date: date.to_s, body: '牛乳買う' }, headers: turbo_headers
        expect(response).to have_http_status(:success)
        expect(family.day_memos.find_by(date: date).body).to eq('牛乳買う')
      end

      it 'updates an existing memo' do
        create(:day_memo, family: family, date: date, body: '旧メモ')
        patch weekly_memo_path, params: { date: date.to_s, body: '新メモ' }, headers: turbo_headers
        expect(family.day_memos.find_by(date: date).body).to eq('新メモ')
      end

      it 'replaces the memo cell in the response' do
        patch weekly_memo_path, params: { date: date.to_s, body: '牛乳買う' }, headers: turbo_headers
        expect(response.body).to include("weekly-memo-#{date}")
      end

      it 'rejects a body longer than 1000 characters' do
        patch weekly_memo_path, params: { date: date.to_s, body: 'あ' * 1001 }, headers: turbo_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(family.day_memos.find_by(date: date)).to be_nil
      end
    end

    it 'shows the memo body on the weekly grid' do
      create(:day_memo, family: family, date: date, body: '懇談会')
      get weekly_dashboard_path
      expect(response.body).to include('懇談会')
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
