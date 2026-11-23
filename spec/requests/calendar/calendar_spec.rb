require 'rails_helper'

RSpec.describe 'Calendars', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:other_user) { create(:user, family: family) }
  let(:date) { Time.zone.today }

  before do
    sign_in user
  end

  describe 'GET /index' do
    it 'returns http success' do
      get '/calendar'
      expect(response).to have_http_status(:success)
    end

    it 'links to the monthly meal summary for the displayed month' do
      get '/calendar', params: { date: '2026-08-15' }
      expect(response.body).to include(monthly_meal_summary_path(month: '2026-08'))
    end
  end

  describe 'month navigation' do
    let!(:december_plan) { create(:plan, family: family, date: Date.new(2026, 12, 1), title: 'December Plan') }
    let!(:january_plan) { create(:plan, family: family, date: Date.new(2027, 1, 1), title: 'January Plan') }
    let!(:january_task) { create(:task, family: family, user: user, date: Date.new(2027, 1, 1), title: 'January Task') }

    before do
      create(:plan_participant, plan: december_plan, user: user, status: :joined)
      create(:plan_participant, plan: january_plan, user: user, status: :joined)
    end

    it 'renders previous and next month links and a direct month picker', :aggregate_failures do
      get calendar_path, params: { date: '2026-12-15' }

      expect(response.body).to include('2026年12月')
      expect(response.body).to include('aria-label="前月へ"', 'aria-label="次月へ"')
      expect(response.body).to include(calendar_path(date: '2026-11-01'))
      expect(response.body).to include(calendar_path(date: '2027-01-01'))
      expect(response.body).to include('aria-label="年月を選択"')
      expect(response.body).to include('data-monthpicker-connector-date-value="2026-12-15"')
      expect(response.body).to include('data-monthpicker-connector-base-url-value="/calendar"')
    end

    it 'moves to the next month across the year boundary and reloads its plans and tasks', :aggregate_failures do
      get calendar_path, params: { date: '2026-12-01' }
      expect(response.body).to include('December Plan')
      expect(response.body).not_to include('January Plan')

      get calendar_path, params: { date: '2027-01-01' }

      expect(response.body).to include('2027年01月')
      expect(response.body).to include('January Plan')
      expect(response.body).to include('January Task')
      expect(response.body).not_to include('December Plan')
      expect(response.body).to include(calendar_path(date: '2026-12-01'))
    end

    it 'moves to the previous month across the year boundary and reloads its plans and tasks', :aggregate_failures do
      get calendar_path, params: { date: '2027-01-01' }
      expect(response.body).to include(calendar_path(date: '2026-12-01'))

      get calendar_path, params: { date: '2026-12-01' }

      expect(response.body).to include('2026年12月')
      expect(response.body).to include('December Plan')
      expect(response.body).not_to include('January Plan')
      expect(response.body).not_to include('January Task')
      expect(response.body).to include(calendar_path(date: '2027-01-01'))
    end

    it 'navigates months on the my calendar', :aggregate_failures do
      get my_calendar_path, params: { date: '2026-12-15' }

      expect(response.body).to include('2026年12月')
      expect(response.body).to include(my_calendar_path(date: '2026-11-01'))
      expect(response.body).to include(my_calendar_path(date: '2027-01-01'))
      expect(response.body).to include('aria-label="年月を選択"')
      expect(response.body).to include('data-monthpicker-connector-date-value="2026-12-15"')
      expect(response.body).to include('data-monthpicker-connector-base-url-value="/calendar/my"')
    end
  end

  describe 'GET /my' do
    let!(:my_plan) { create(:plan, family: family, date: date, title: 'My Plan') }
    let!(:other_plan) { create(:plan, family: family, date: date, title: 'Other Plan') }
    let!(:my_task) { create(:task, family: family, user: user, date: date, title: 'My Task') }
    let!(:other_task) { create(:task, family: family, user: other_user, date: date, title: 'Other Task') }

    before do
      create(:plan_participant, plan: my_plan, user: user, status: :joined)
      create(:plan_participant, plan: other_plan, user: other_user, status: :joined)
    end

    it 'only assigns plans and tasks belonging to the current user' do
      get my_calendar_path, params: { date: date }

      expect(response).to have_http_status(:success)
      expect(controller.instance_variable_get(:@family_plans)).to contain_exactly(my_plan)
      expect(controller.instance_variable_get(:@family_tasks)).to contain_exactly(my_task)
      expect(response.body).not_to include(other_plan.title, other_task.title)
    end
  end

  describe 'GET /daily_view' do
    it 'preserves the requested my scope in the turbo frame' do
      my_task = create(:task, family: family, user: user, date: date, title: 'My Daily Task')
      other_task = create(:task, family: family, user: other_user, date: date, title: 'Other Daily Task')

      get calendar_daily_view_path, params: { date: date, scope: 'my' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(my_task.title)
      expect(response.body).not_to include(other_task.title)
    end
  end

  describe 'meals in daily view' do
    let(:family) { create(:family) }
    let(:me) { create(:user, family: family) }
    let(:other) { create(:user, family: family) }

    before { sign_in me, scope: :user }

    it 'family scope shows all family meals for the date' do
      ramen = create(:food, family: family, name: 'ラーメン')
      meal = create(:meal, family: family, user: other, date: Time.zone.today, meal_type: 1)
      create(:meal_food, meal: meal, food: ramen)

      get calendar_path(date: Time.zone.today.to_s)
      expect(response.body).to include('ラーメン')
    end

    it 'my scope hides other members-only meals' do
      curry = create(:food, family: family, name: 'カレー')
      meal = create(:meal, family: family, user: other, date: Time.zone.today, meal_type: 2)
      create(:meal_food, meal: meal, food: curry)

      get my_calendar_path(date: Time.zone.today.to_s)
      expect(response.body).not_to include('カレー')
    end
  end

  describe 'GET /monthly_list' do
    let!(:joined_plan) { create(:plan, family: family, date: date, title: 'Joined Plan') }
    let!(:declined_plan) { create(:plan, family: family, date: date, title: 'Declined Plan') }
    let!(:other_month_plan) { create(:plan, family: family, date: date + 1.month, title: 'Other Month') }

    before do
      create(:plan_participant, plan: joined_plan, user: user, status: :joined)
      create(:plan_participant, plan: declined_plan, user: user, status: :declined)
    end

    it 'returns turbo_stream response' do
      get monthly_list_calendar_path, params: { date: date }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'assigns correct plans to @monthly_plans' do
      # NOTE: The controller groups by date
      get monthly_list_calendar_path, params: { date: date }, as: :turbo_stream

      # @monthly_plans is grouped by date
      plans_by_date = controller.instance_variable_get(:@monthly_plans)
      all_plans = plans_by_date.values.flatten

      # Should include all family plans for the month (the controller doesn't filter the LIST of plans,
      # but the VIEW shows active participants. Wait, let me check the controller again.)
      expect(all_plans).to include(joined_plan)
      expect(all_plans).to include(declined_plan)
      expect(all_plans).not_to include(other_month_plan)
    end

    it 'renders participants correctly in the stream' do
      get monthly_list_calendar_path, params: { date: date }, as: :turbo_stream

      expect(response.body).to include('Joined Plan')
      expect(response.body).to include('Declined Plan')

      # Split by plans to verify contents specifically per plan
      # This is a bit rough but works for verifying that the login_id appears after one title but not the other
      joined_plan_part = response.body.split('Joined Plan').last
      declined_plan_part = response.body.split('Declined Plan').last

      # joined_plan should be followed by the user's login_id (in a badge)
      # declined_plan should NOT be followed by the user's login_id (because they are declined)
      expect(joined_plan_part).to include(user.login_id)

      # We check that the user's login_id doesn't appear in the immediate vicinity of the declined plan title
      # (before the next plan or end of the list)
      expect(declined_plan_part.split('Joined Plan').first).not_to include(user.login_id)
    end
  end
end
