require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:task) { create(:task, family: family, user: user, date: Time.zone.today, completed: false) }

  before do
    sign_in user
  end

  describe 'PATCH /update' do
    it 'updates the completed status' do
      patch task_path(task), params: { task: { completed: true } }
      task.reload
      expect(task.completed).to be true
    end

    it 'updates other attributes' do
      patch task_path(task), params: { task: { title: 'New Title' } }
      task.reload
      expect(task.title).to eq('New Title')
    end
  end
end
