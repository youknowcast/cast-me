# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/today', type: :request do
  let(:family) { create(:family, name: '家族A') }
  let(:user) { create(:user, family: family, login_id: 'father') }
  let!(:other_member) { create(:user, family: family, login_id: 'mother') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'test').last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}" } }
  let(:date) { Date.new(2026, 11, 28) }

  before { host! 'localhost' }

  def get_today(query = {}, auth: headers, **extra)
    get '/api/v1/today', params: query.merge(extra), headers: auth
  end

  context 'with explicit date' do
    context 'with a plan and task on the day' do
      let!(:plan) { create(:plan, family: family, title: '歯医者', date: date, start_time: '10:00', end_time: '11:00') }
      let!(:task) do
        create(:task, family: family, user: user, title: 'ゴミ出し', date: date, completed: false, priority: 1)
      end

      before do
        create(:plan_participant, plan: plan, user: user, status: :joined)
        create(:plan_participant, plan: plan, user: other_member, status: :pending)
        get_today(date: date.iso8601)
      end

      it 'returns http ok with requested date and family' do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['date']).to eq('2026-11-28')
        expect(response.parsed_body['family']).to eq('id' => family.id, 'name' => '家族A')
      end

      it 'returns the day plan with participants' do
        plan_json = response.parsed_body['plans'].first
        expect(response.parsed_body['plans'].size).to eq(1)
        expect(plan_json).to include('id' => plan.id, 'title' => '歯医者', 'start_time' => '10:00', 'end_time' => '11:00')
        expect(plan_json['participants']).to contain_exactly(
          { 'id' => user.id, 'display_name' => 'father', 'status' => 'joined' },
          { 'id' => other_member.id, 'display_name' => 'mother', 'status' => 'pending' }
        )
      end

      it 'returns the day task' do
        task_json = response.parsed_body['tasks'].first
        expect(response.parsed_body['tasks'].size).to eq(1)
        expect(task_json).to eq(
          'id' => task.id, 'title' => 'ゴミ出し',
          'user' => { 'id' => user.id, 'display_name' => 'father' }, 'completed' => false, 'priority' => 1
        )
      end

      it 'returns input_status' do
        expect(response.parsed_body['input_status']).to eq('registered' => 1, 'completed' => 0, 'status' => 'partial')
      end
    end

    it 'serializes null start_time/end_time' do
      create(:plan, family: family, date: date, start_time: nil, end_time: nil)
      get_today(date: date.iso8601)
      plan_json = response.parsed_body['plans'].first
      expect(plan_json['start_time']).to be_nil
      expect(plan_json['end_time']).to be_nil
    end

    it 'includes participants with declined status and empty participants array' do
      plan = create(:plan, family: family, date: date)
      create(:plan_participant, plan: plan, user: user, status: :declined)
      get_today(date: date.iso8601)
      expect(response.parsed_body['plans'].first['participants']).to contain_exactly(
        { 'id' => user.id, 'display_name' => 'father', 'status' => 'declined' }
      )

      plan.plan_participants.delete_all
      get_today(date: date.iso8601)
      expect(response.parsed_body['plans'].first['participants']).to eq([])
    end

    it 'only includes plans/tasks for the given date' do
      create(:plan, family: family, date: date - 1, title: '前日')
      create(:task, family: family, user: user, date: date + 1, title: '翌日')
      get_today(date: date.iso8601)
      expect(response.parsed_body['plans']).to eq([])
      expect(response.parsed_body['tasks']).to eq([])
      expect(response.parsed_body['input_status']).to eq('registered' => 0, 'completed' => 0, 'status' => 'none')
    end

    it 'computes input_status complete when all tasks completed' do
      create(:task, family: family, user: user, date: date, completed: true)
      create(:task, family: family, user: other_member, date: date, completed: true)
      get_today(date: date.iso8601)
      expect(response.parsed_body['input_status']).to eq('registered' => 2, 'completed' => 2, 'status' => 'complete')
    end
  end

  context 'when scoping to family' do
    it 'does not return other family plans, tasks, or members' do
      other_family = create(:family, name: '他家族')
      other_user = create(:user, family: other_family, login_id: 'intruder')
      create(:plan, family: other_family, date: date, title: '他家族の予定')
      create(:task, family: other_family, user: other_user, date: date, title: '他家族のタスク')

      get_today(date: date.iso8601)

      json = response.parsed_body
      expect(json['plans']).to eq([])
      expect(json['tasks']).to eq([])
      expect(json['input_status']).to eq('registered' => 0, 'completed' => 0, 'status' => 'none')
      expect(json['family']['id']).to eq(family.id)
    end

    it 'does not include another family participant on a plan' do
      other_family = create(:family)
      intruder = create(:user, family: other_family, login_id: 'intruder')
      plan = create(:plan, family: family, date: date)
      create(:plan_participant, plan: plan, user: intruder, status: :joined)
      create(:plan_participant, plan: plan, user: user, status: :joined)

      get_today(date: date.iso8601)

      names = response.parsed_body['plans'].first['participants'].pluck('display_name')
      expect(names).to contain_exactly('father')
    end
  end

  context 'when handling dates' do
    it 'defaults to Asia/Tokyo today when date is omitted' do
      # 2026-11-28 16:00 UTC == 2026-11-29 01:00 JST
      travel_to(Time.utc(2026, 11, 28, 16, 0, 0)) do
        today_jst = Date.new(2026, 11, 29)
        create(:task, family: family, user: user, date: today_jst, title: '今日')
        create(:plan, family: family, date: today_jst, title: '今日の予定')

        get_today

        json = response.parsed_body
        expect(json['date']).to eq('2026-11-29')
        expect(json['plans'].pluck('title')).to eq(['今日の予定'])
        expect(json['tasks'].pluck('title')).to eq(['今日'])
      end
    end

    it 'returns 400 invalid_date for malformed date' do
      get_today(date: 'not-a-date')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'returns 400 invalid_date for impossible calendar date' do
      get_today(date: '2026-13-40')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'returns 400 invalid_date for empty date' do
      get_today(date: '')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end
  end

  context 'with strict YYYY-MM-DD date format' do
    it 'accepts a strict YYYY-MM-DD date' do
      get_today(date: '2026-11-28')
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['date']).to eq('2026-11-28')
    end

    it 'rejects 2026-11-28extra' do
      get_today(date: '2026-11-28extra')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'rejects 2026.11.28' do
      get_today(date: '2026.11.28')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'rejects 28-11-2026' do
      get_today(date: '28-11-2026')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'rejects 20261128' do
      get_today(date: '20261128')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'rejects non-padded 2026-1-2' do
      get_today(date: '2026-1-2')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'rejects nested array date[] param' do
      get_today(date: %w[2026-11-28 x])
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'rejects nested date[x] param' do
      get_today(date: { x: '2026-11-28' })
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'rejects impossible calendar date 2026-02-30' do
      get_today(date: '2026-02-30')
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end
  end

  context 'when returning v1 fields' do
    it 'does not return meals, health, or medications' do
      create(:meal, family: family, user: user, date: date)
      create(:health_episode, family: family, user: user, started_on: date)
      create(:medication, family: family)

      get_today(date: date.iso8601)

      json = response.parsed_body
      expect(json.keys).to contain_exactly('date', 'family', 'plans', 'tasks', 'input_status')
      expect(json.keys).not_to include('meals', 'health', 'health_episodes', 'medications')
    end
  end

  context 'when authentication is required' do
    it 'returns 401 when token missing' do
      get_today({}, auth: {})
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end
  end
end
