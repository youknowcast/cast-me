require 'rails_helper'

RSpec.describe 'UsageReports', type: :request do
  around do |example|
    travel_to(Time.zone.parse('2026-11-23 12:00')) { example.run }
  end

  let(:family) { create(:family, name: 'やまだ家') }
  let(:user) { create(:user, family: family, login_id: 'はは') }
  let(:member) { create(:user, family: family, login_id: 'ちち') }

  describe 'GET /usage without signing in' do
    it 'redirects to the sign in page' do
      get usage_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'GET /usage' do
    before do
      sign_in user
      member
    end

    it 'renders the usage page' do
      get usage_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('家族の利用状況')
    end

    it 'shows the family name and its members' do
      get usage_path

      expect(response.body).to include('やまだ家')
      expect(response.body).to include('はは')
      expect(response.body).to include('ちち')
    end

    it 'does not show another family name or members' do
      other_family = create(:family, name: 'すずき家')
      create(:user, family: other_family, login_id: 'たろう')

      get usage_path

      expect(response.body).not_to include('すずき家')
      expect(response.body).not_to include('たろう')
    end

    it 'shows relative last access labels without clock times' do
      user.update!(last_seen_at: Time.zone.parse('2026-11-23 08:00'))
      member.update!(last_seen_at: Time.zone.parse('2026-11-20 08:00'))

      get usage_path

      expect(response.body).to include('今日')
      expect(response.body).to include('3日前')
      expect(response.body).not_to match(/\d{1,2}:\d{2}/)
      expect(response.body).not_to include('ログイン回数')
    end

    it 'shows まだ記録なし for a member who has never been seen' do
      get usage_path

      expect(response.body).to include('まだ記録なし')
    end

    it 'counts only the current family records' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      create(:plan, family: other_family, created_by: other_user, created_at: Time.zone.parse('2026-11-22 09:00'))

      get usage_path

      expect(response.body).to include('予定 0件')
    end

    it 'counts records made today' do
      create(:plan, family: family, created_by: user, created_at: Time.zone.parse('2026-11-23 10:00'))
      create(:task, family: family, user: member, created_at: Time.zone.parse('2026-11-23 11:00'))

      get usage_path

      expect(response.body).to include('直近7日で 1日 記録しました')
      expect(response.body).to include('予定 1件')
      expect(response.body).to include('タスク 1件')
    end

    it 'defaults to the last 7 days' do
      create(:plan, family: family, created_by: user, created_at: Time.zone.parse('2026-11-05 09:00'))

      get usage_path

      expect(response.body).to include('予定 0件')
    end

    it 'shows the last 30 days when period=30 is given' do
      create(:plan, family: family, created_by: user, created_at: Time.zone.parse('2026-11-05 09:00'))

      get usage_path(period: '30')

      expect(response.body).to include('予定 1件')
      expect(response.body).to include('直近30日')
    end

    it 'falls back to the last 7 days for an unknown period' do
      get usage_path(period: '999')

      expect(response.body).to include('直近7日')
    end

    it 'ignores the scope parameter and always shows the family view' do
      get usage_path(scope: 'my')

      expect(response.body).to include('記録日数')
      expect(response.body).to include('ちち')
    end
  end
end
