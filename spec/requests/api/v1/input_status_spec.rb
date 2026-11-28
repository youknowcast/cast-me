# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/input_status', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family, login_id: 'father') }
  let!(:other_member) { create(:user, family: family, login_id: 'mother') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'test').last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}" } }
  let(:date) { Date.new(2026, 11, 28) }

  before { host! 'localhost' }

  def get_input_status(query = {}, auth: headers, **extra)
    get '/api/v1/input_status', params: query.merge(extra), headers: auth
  end

  def get_status
    response.parsed_body['status']
  end

  context 'when no tasks are registered' do
    it 'returns none with zero counts when no tasks registered' do
      get_input_status(date: date.iso8601)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'date' => '2026-11-28', 'registered' => 0, 'completed' => 0, 'status' => 'none'
      )
    end
  end

  context 'when partially completed' do
    it 'returns partial when nothing completed yet' do
      create(:task, family: family, user: user, date: date, completed: false)
      create(:task, family: family, user: other_member, date: date, completed: false)
      get_input_status(date: date.iso8601)
      expect(response.parsed_body['registered']).to eq(2)
      expect(response.parsed_body['completed']).to eq(0)
      expect(get_status).to eq('partial')
    end

    it 'returns partial when some but not all completed' do
      create(:task, family: family, user: user, date: date, completed: true)
      create(:task, family: family, user: other_member, date: date, completed: false)
      get_input_status(date: date.iso8601)
      expect(response.parsed_body['registered']).to eq(2)
      expect(response.parsed_body['completed']).to eq(1)
      expect(get_status).to eq('partial')
    end
  end

  context 'when fully completed' do
    it 'returns complete when all registered tasks are completed' do
      create(:task, family: family, user: user, date: date, completed: true)
      create(:task, family: family, user: other_member, date: date, completed: true)
      get_input_status(date: date.iso8601)
      expect(response.parsed_body['registered']).to eq(2)
      expect(response.parsed_body['completed']).to eq(2)
      expect(get_status).to eq('complete')
    end
  end

  context 'when user_id is omitted' do
    it 'aggregates all family members by default' do
      create(:task, family: family, user: user, date: date, completed: true)
      create(:task, family: family, user: other_member, date: date, completed: false)
      get_input_status(date: date.iso8601)
      expect(response.parsed_body['registered']).to eq(2)
      expect(response.parsed_body['completed']).to eq(1)
      expect(get_status).to eq('partial')
    end
  end

  context 'with user filter' do
    it 'scopes counts to the given user' do
      create(:task, family: family, user: user, date: date, completed: true)
      create(:task, family: family, user: other_member, date: date, completed: false)

      get_input_status(date: date.iso8601, user_id: user.id)

      expect(response.parsed_body['registered']).to eq(1)
      expect(response.parsed_body['completed']).to eq(1)
      expect(get_status).to eq('complete')
    end

    it 'returns none for a user with no tasks' do
      create(:task, family: family, user: other_member, date: date, completed: true)
      get_input_status(date: date.iso8601, user_id: user.id)
      expect(get_status).to eq('none')
      expect(response.parsed_body['registered']).to eq(0)
    end

    it 'does not count tasks from another family for a user_id in that family' do
      other_family = create(:family)
      intruder = create(:user, family: other_family, login_id: 'intruder')
      create(:task, family: other_family, user: intruder, date: date, completed: true)
      get_input_status(date: date.iso8601, user_id: intruder.id)
      expect(get_status).to eq('none')
    end
  end

  context 'when scoping to family' do
    it 'does not count other family tasks' do
      other_family = create(:family)
      intruder = create(:user, family: other_family, login_id: 'intruder')
      create(:task, family: other_family, user: intruder, date: date, completed: false)
      create(:task, family: family, user: user, date: date, completed: true)
      get_input_status(date: date.iso8601)
      expect(response.parsed_body['registered']).to eq(1)
    end
  end

  context 'when handling dates' do
    it 'returns 400 invalid_date for malformed date' do
      get_input_status(date: '2026-99-99')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'only counts tasks for the given date' do
      create(:task, family: family, user: user, date: date - 1, completed: true)
      get_input_status(date: date.iso8601)
      expect(get_status).to eq('none')
    end

    it 'defaults to Asia/Tokyo today when date omitted' do
      travel_to(Time.utc(2026, 11, 28, 16, 0, 0)) do
        create(:task, family: family, user: user, date: Date.new(2026, 11, 29), completed: true)
        get_input_status
        expect(response.parsed_body['date']).to eq('2026-11-29')
        expect(get_status).to eq('complete')
      end
    end
  end

  context 'when authentication is required' do
    it 'returns 401 when token missing' do
      get_input_status({}, auth: {})
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
