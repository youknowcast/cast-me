# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/tasks', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family, login_id: 'father') }
  let!(:other_member) { create(:user, family: family, login_id: 'mother') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'test').last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}" } }
  let(:date) { Date.new(2026, 11, 28) }

  before { host! 'localhost' }

  def get_tasks(query = {}, auth: headers, **extra)
    get '/api/v1/tasks', params: query.merge(extra), headers: auth
  end

  context 'when scoping to the day, family-wide' do
    let(:json) { response.parsed_body }

    before do
      create(:task, family: family, user: user, date: date, title: 'a', completed: true, priority: 2)
      create(:task, family: family, user: other_member, date: date, title: 'b', completed: false, priority: 0)
      create(:task, family: family, user: user, date: date - 1, title: 'other day')
      get_tasks(date: date.iso8601)
    end

    it 'returns http ok with requested date' do
      expect(response).to have_http_status(:ok)
      expect(json['date']).to eq('2026-11-28')
    end

    it 'returns only tasks for the day, family-wide' do
      expect(json['tasks'].size).to eq(2)
      expect(json['tasks'].pluck('title')).to contain_exactly('a', 'b')
    end

    it 'serializes task user, completed, priority' do
      task = json['tasks'].find { |t| t['title'] == 'a' }
      expect(task['user']).to eq('id' => user.id, 'display_name' => 'father')
      expect(task['completed']).to be true
      expect(task['priority']).to eq(2)
    end

    it 'returns counts' do
      expect(json['counts']).to eq('registered' => 2, 'completed' => 1, 'pending' => 1)
    end
  end

  it 'serializes task shape id/title/user/completed/priority' do
    task = create(:task, family: family, user: user, date: date, title: 'ゴミ出し', completed: false, priority: 3)
    get_tasks(date: date.iso8601)
    json = response.parsed_body['tasks'].first
    expect(json.keys).to contain_exactly('id', 'title', 'user', 'completed', 'priority')
    expect(json['id']).to eq(task.id)
  end

  context 'with user filter' do
    it 'filters tasks to the given user and recomputes counts' do
      create(:task, family: family, user: user, date: date, title: 'a', completed: true)
      create(:task, family: family, user: user, date: date, title: 'b', completed: false)
      create(:task, family: family, user: other_member, date: date, title: 'c', completed: false)

      get_tasks(date: date.iso8601, user_id: user.id)

      json = response.parsed_body
      expect(json['tasks'].pluck('title')).to contain_exactly('a', 'b')
      expect(json['tasks'].map { |t| t['user']['id'] }).to all(eq(user.id))
      expect(json['counts']).to eq('registered' => 2, 'completed' => 1, 'pending' => 1)
    end

    it 'returns empty for unknown user_id' do
      create(:task, family: family, user: user, date: date)
      get_tasks(date: date.iso8601, user_id: 999_999)
      json = response.parsed_body
      expect(json['tasks']).to eq([])
      expect(json['counts']).to eq('registered' => 0, 'completed' => 0, 'pending' => 0)
    end

    it 'does not return tasks for a user in another family' do
      other_family = create(:family)
      intruder = create(:user, family: other_family, login_id: 'intruder')
      create(:task, family: other_family, user: intruder, date: date, title: '他家族')

      get_tasks(date: date.iso8601, user_id: intruder.id)

      json = response.parsed_body
      expect(json['tasks']).to eq([])
      expect(json['counts']).to eq('registered' => 0, 'completed' => 0, 'pending' => 0)
    end
  end

  context 'when scoping to family' do
    it 'does not include other family tasks' do
      other_family = create(:family)
      intruder = create(:user, family: other_family, login_id: 'intruder')
      create(:task, family: other_family, user: intruder, date: date, title: '他家族のタスク')
      create(:task, family: family, user: user, date: date, title: '自家族')

      get_tasks(date: date.iso8601)

      json = response.parsed_body
      expect(json['tasks'].pluck('title')).to contain_exactly('自家族')
      expect(json['counts']['registered']).to eq(1)
    end

    it 'with another family token, does not return this family tasks' do
      other_family = create(:family)
      intruder = create(:user, family: other_family, login_id: 'intruder')
      create(:task, family: family, user: user, date: date, title: '自家族')
      other_raw = ApiToken.issue!(family: other_family, name: 'test').last
      create(:task, family: other_family, user: intruder, date: date, title: '他家族')

      get_tasks({ date: date.iso8601 }, auth: { 'Authorization' => "Bearer #{other_raw}" })

      json = response.parsed_body
      expect(json['tasks'].pluck('title')).to contain_exactly('他家族')
      expect(json['tasks'].pluck('title')).not_to include('自家族')
    end
  end

  context 'when handling dates' do
    it 'returns 400 invalid_date for malformed date' do
      get_tasks(date: 'nope')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'returns 400 invalid_date for impossible calendar date' do
      get_tasks(date: '2026-02-30')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'defaults to Asia/Tokyo today when date omitted' do
      travel_to(Time.utc(2026, 11, 28, 16, 0, 0)) do
        create(:task, family: family, user: user, date: Date.new(2026, 11, 29))
        get_tasks
        expect(response.parsed_body['date']).to eq('2026-11-29')
        expect(response.parsed_body['counts']['registered']).to eq(1)
      end
    end
  end

  context 'when authentication is required' do
    it 'returns 401 when token missing' do
      get_tasks({}, auth: {})
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'does not return meals, health, or medications' do
    create(:meal, family: family, user: user, date: date)
    create(:health_episode, family: family, user: user, started_on: date)
    create(:medication, family: family)
    get_tasks(date: date.iso8601)
    expect(response.parsed_body.keys).not_to include('meals', 'health', 'medications', 'health_episodes')
  end
end
