# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /api/v1/tasks/:id/complete', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family, login_id: 'father') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'test', user: user).last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}" } }
  let(:date) { Date.new(2026, 11, 28) }

  def complete(id, auth: headers)
    patch "/api/v1/tasks/#{id}/complete", headers: auth
  end

  context 'when authenticating' do
    let(:task) { create(:task, family: family, user: user, date: date) }

    it 'returns 401 without token' do
      complete(task.id, auth: {})
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end

    it 'does not complete when unauthenticated' do
      expect { complete(task.id, auth: {}) }.not_to(change { task.reload.completed })
    end
  end

  it 'marks an incomplete task completed and returns TaskSerializer' do
    task = create(:task, family: family, user: user, date: date, completed: false, title: 'ゴミ出し', priority: 2)
    complete(task.id)
    expect(response).to have_http_status(:ok)
    expect(task.reload.completed).to be true
    expect(response.parsed_body).to eq(
      'id' => task.id, 'title' => 'ゴミ出し',
      'user' => { 'id' => user.id, 'display_name' => 'father' }, 'completed' => true, 'priority' => 2
    )
  end

  context 'when the task is already completed' do
    it 'is a no-op and returns completed=true' do
      task = create(:task, family: family, user: user, date: date, completed: true)
      complete(task.id)
      expect(response).to have_http_status(:ok)
      expect(task.reload.completed).to be true
      expect(response.parsed_body['completed']).to be true
    end

    it 'does not change updated_at again' do
      task = create(:task, family: family, user: user, date: date, completed: true)
      original_updated_at = task.updated_at
      complete(task.id)
      expect(task.reload.updated_at).to eq(original_updated_at)
    end
  end

  context 'when scoping to family' do
    it 'returns 404 for a task in another family' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      other_task = create(:task, family: other_family, user: other_user, date: date, completed: false)
      complete(other_task.id)
      expect(response).to have_http_status(:not_found)
      expect(other_task.reload.completed).to be false
    end

    it 'returns 404 for an unknown task id' do
      complete(999_999)
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('not_found')
    end

    it 'returns 404 for a non-integer id' do
      complete('abc')
      expect(response).to have_http_status(:not_found)
    end
  end
end
