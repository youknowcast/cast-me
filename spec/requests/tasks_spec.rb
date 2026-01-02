require 'rails_helper'

RSpec.describe 'Tasks', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:task) { create(:task, family: family, user: user, date: Time.zone.today, completed: false) }

  before do
    sign_in user
  end

  describe 'POST /tasks' do
    let(:valid_params) do
      {
        task: {
          title: 'New Task',
          description: 'Task Description',
          date: Time.zone.today.to_s,
          priority: 'medium',
          user_id: user.id
        },
        scope: 'my'
      }
    end

    context 'with turbo_stream' do
      it 'creates a new task and returns success turbo_stream' do
        expect do
          post tasks_path, params: valid_params, as: :turbo_stream
        end.to change(Task, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('turbo-stream action="update" target="daily_details"')
        expect(response.body).to include("turbo-stream action=\"replace\" target=\"calendar-cell-#{Time.zone.today}\"")
      end
    end

    context 'with html' do
      it 'creates a new task and redirects' do
        post tasks_path, params: valid_params
        expect(response).to redirect_to(calendar_path)
      end
    end
  end

  describe 'PATCH /update' do
    it 'updates the completed status' do
      patch task_path(task), params: { task: { completed: true }, scope: 'my' }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      task.reload
      expect(task.completed).to be true
      expect(response.body).to include("turbo-stream action=\"replace\" target=\"calendar-cell-#{task.date}\"")
    end

    it 'updates other attributes' do
      patch task_path(task), params: { task: { title: 'New Title' }, scope: 'my' }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      task.reload
      expect(task.title).to eq('New Title')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the task' do
      task # ensure task is created
      expect do
        delete task_path(task), as: :turbo_stream
      end.to change(Task, :count).by(-1)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("turbo-stream action=\"replace\" target=\"calendar-cell-#{task.date}\"")
    end
  end

  describe 'PATCH /toggle' do
    it 'toggles the completion status' do
      patch toggle_task_path(task), as: :turbo_stream
      expect(response).to have_http_status(:ok)
      task.reload
      expect(task.completed).to be true
      expect(response.body).to include("turbo-stream action=\"replace\" target=\"task_#{task.id}\"")
      expect(response.body).to include("turbo-stream action=\"replace\" target=\"calendar-cell-#{task.date}\"")
    end
  end
end
