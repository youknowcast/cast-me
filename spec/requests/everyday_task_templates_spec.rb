require 'rails_helper'

RSpec.describe "EverydayTaskTemplates", type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let!(:everyday_task_template) { create(:everyday_task_template, family: family) }

  before do
    sign_in user
  end

  describe "GET /index" do
    it "returns http success" do
      get everyday_task_templates_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it "creates a new template" do
      expect {
        post everyday_task_templates_path, params: { everyday_task_template: { name: "New Set" } }
      }.to change(EverydayTaskTemplate, :count).by(1)
      expect(response).to redirect_to(everyday_task_templates_path)
    end
  end

  describe "PATCH /update" do
    it "updates the template" do
      patch everyday_task_template_path(everyday_task_template), params: { everyday_task_template: { name: "Updated Name" } }
      expect(everyday_task_template.reload.name).to eq("Updated Name")
      expect(response).to redirect_to(everyday_task_templates_path)
    end
  end

  describe "DELETE /destroy" do
    it "destroys the template" do
      expect {
        delete everyday_task_template_path(everyday_task_template)
      }.to change(EverydayTaskTemplate, :count).by(-1)
      expect(response).to redirect_to(everyday_task_templates_path)
    end
  end

  describe "POST /bulk_add" do
    before do
      create(:task_template, everyday_task_template: everyday_task_template, user: user, title: "Task 1")
      create(:task_template, everyday_task_template: everyday_task_template, user: user, title: "Task 2")
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
