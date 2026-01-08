# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WeeklySummaries', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:other_user) { create(:user, family: family) }

  before do
    sign_in user
  end

  describe 'GET /weekly_summary' do
    let(:week_start) { Date.current.beginning_of_week }
    let(:week_end) { Date.current.end_of_week }

    before do
      # Create tasks for current week
      create(:task, user: user, family: family, date: week_start, title: 'User Task 1', completed: true)
      create(:task, user: user, family: family, date: week_start + 1.day, title: 'User Task 2', completed: false)
      create(:task, user: other_user, family: family, date: week_start + 2.days, title: 'Other Task', completed: true)

      # Task outside current week (should not appear)
      create(:task, user: user, family: family, date: week_start - 1.week, title: 'Old Task', completed: true)
    end

    it 'returns http success' do
      get weekly_summary_path
      expect(response).to have_http_status(:success)
    end

    it 'displays week range in the header' do
      get weekly_summary_path
      expect(response.body).to include(I18n.l(week_start, format: :short))
      expect(response.body).to include(I18n.l(week_end, format: :short))
    end

    it 'displays completed tasks for current user' do
      get weekly_summary_path
      expect(response.body).to include('User Task 1')
    end

    it 'displays pending tasks for current user' do
      get weekly_summary_path
      expect(response.body).to include('User Task 2')
    end

    it 'displays tasks from other family members' do
      get weekly_summary_path
      expect(response.body).to include('Other Task')
    end

    it 'does not display tasks from previous weeks' do
      get weekly_summary_path
      expect(response.body).not_to include('Old Task')
    end

    it 'displays both users in summary' do
      get weekly_summary_path
      expect(response.body).to include(user.display_name)
      expect(response.body).to include(other_user.display_name)
    end
  end

  context 'when not signed in' do
    before { sign_out user }

    it 'redirects to sign in page' do
      get weekly_summary_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
