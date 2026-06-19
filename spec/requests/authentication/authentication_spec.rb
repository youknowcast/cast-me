require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  protected_get_paths = {
    calendar: -> { calendar_path },
    plans: -> { plans_path },
    tasks: -> { tasks_path },
    regular_tasks: -> { regular_tasks_path },
    everyday_task_templates: -> { everyday_task_templates_path },
    settings: -> { settings_path },
    weekly_summary: -> { weekly_summary_path }
  }

  protected_get_paths.each do |name, path|
    it "requires authentication for #{name}" do
      get instance_exec(&path)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  it 'does not create a plan' do
    expect do
      post plans_path, params: { plan: { title: 'Unauthorized' } }
    end.not_to change(Plan, :count)

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'does not create a task' do
    expect do
      post tasks_path, params: { task: { title: 'Unauthorized' } }
    end.not_to change(Task, :count)

    expect(response).to redirect_to(new_user_session_path)
  end

  it 'does not update a plan participant' do
    participant = create(:plan_participant, status: :pending)

    patch plan_participant_path(participant), params: { status: 'joined' }

    expect(response).to redirect_to(new_user_session_path)
    expect(participant.reload).to be_pending
  end
end
