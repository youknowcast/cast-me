require 'rails_helper'

RSpec.describe "EverydayTaskTemplates", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:everyday_task_template) { EverydayTaskTemplate.create!(family: family, name: "Morning") }

  before do
    sign_in user
  end

  describe "POST /bulk_add" do
    before do
      everyday_task_template.task_templates.create!(user: user, title: "Task 1", priority: 0)
      everyday_task_template.task_templates.create!(user: user, title: "Task 2", priority: 1)
    end

    it "creates tasks from templates" do
      expect {
        post bulk_add_everyday_task_template_path(everyday_task_template), params: { date: Date.today.to_s }
      }.to change(Task, :count).by(2)
    end

    it "redirects back" do
      post bulk_add_everyday_task_template_path(everyday_task_template), params: { date: Date.today.to_s }
      expect(response).to redirect_to(calendar_path(date: Date.today.to_s))
    end
  end
end
