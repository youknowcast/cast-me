require 'rails_helper'

RSpec.describe 'Calendars', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:other_user) { create(:user, family: family) }
  let(:date) { Date.today }

  before do
    sign_in user
  end

  describe 'GET /index' do
    it 'returns http success' do
      get '/calendar'
      expect(response).to have_http_status(:success)
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
      # Note: The controller groups by date
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
