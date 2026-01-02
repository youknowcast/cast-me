require 'rails_helper'

RSpec.describe 'RegularTasks', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  before do
    sign_in user
    host! 'localhost'
  end

  describe 'GET /regular_tasks' do
    let!(:task1) { create(:regular_task, family: family, title: '買い物') }
    let!(:task2) { create(:regular_task, family: family, title: '掃除') }
    let!(:other_family_task) { create(:regular_task, title: '他の家族のタスク') }

    it "returns regular tasks for the current user's family as JSON" do
      get regular_tasks_path, as: :json

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json.size).to eq(2)
      expect(json.map { |t| t['title'] }).to contain_exactly('買い物', '掃除')
    end

    it 'does not include regular tasks from other families' do
      get regular_tasks_path, as: :json

      json = response.parsed_body
      expect(json.map { |t| t['title'] }).not_to include('他の家族のタスク')
    end

    it 'returns tasks ordered by title' do
      get regular_tasks_path, as: :json

      json = response.parsed_body
      titles = json.map { |t| t['title'] }
      expect(titles).to eq(titles.sort)
    end
  end
end
