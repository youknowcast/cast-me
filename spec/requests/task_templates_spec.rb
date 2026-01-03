require 'rails_helper'

RSpec.describe "TaskTemplates", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:everyday_task_template) { create(:everyday_task_template, family: family) }
  let!(:task_template) { create(:task_template, everyday_task_template: everyday_task_template, user: user) }

  before do
    sign_in user
  end

  describe "POST /create" do
    it "creates a new task template" do
      expect {
        post everyday_task_template_task_templates_path(everyday_task_template),
             params: { task_template: { user_id: user.id, title: "New Task", priority: 1 } }
      }.to change(TaskTemplate, :count).by(1)
      expect(response).to redirect_to(everyday_task_template_path(everyday_task_template))
    end
  end

  describe "PATCH /update" do
    it "updates the task template" do
      patch everyday_task_template_task_template_path(everyday_task_template, task_template),
            params: { task_template: { title: "Updated Task" } }
      expect(task_template.reload.title).to eq("Updated Task")
      expect(response).to redirect_to(everyday_task_template_path(everyday_task_template))
    end
  end

  describe "DELETE /destroy" do
    it "destroys the task template" do
      task_template # Ensure it's created
      expect {
        delete everyday_task_template_task_template_path(everyday_task_template, task_template)
      }.to change(TaskTemplate, :count).by(-1)
      expect(response).to redirect_to(everyday_task_template_path(everyday_task_template))
    end
  end
end
