# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /mcp', type: :request do
  let(:family) { create(:family, name: '家族A') }
  let(:user) { create(:user, family: family, login_id: 'father') }
  let(:other_member) { create(:user, family: family, login_id: 'mother') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'mcp', user: user).last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}", 'CONTENT_TYPE' => 'application/json' } }
  let(:date) { Date.new(2026, 11, 28) }

  def rpc(method, params = nil, id: 1, auth: headers)
    body = { jsonrpc: '2.0', id: id, method: method }
    body[:params] = params if params
    post '/mcp', params: body.to_json, headers: auth
  end

  def call_tool(name, arguments = {}, id: 1, auth: headers)
    rpc('tools/call', { name: name, arguments: arguments }, id: id, auth: auth)
  end

  context 'when authenticating' do
    it 'returns 401 JSON without token' do
      rpc('initialize', { protocolVersion: '2025-11-25' }, auth: { 'CONTENT_TYPE' => 'application/json' })
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
      expect(response.media_type).to eq('application/json')
    end

    it 'returns 401 JSON with invalid token' do
      rpc('initialize', { protocolVersion: '2025-11-25' },
          auth: { 'Authorization' => 'Bearer nope', 'CONTENT_TYPE' => 'application/json' })
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'initialize' do
    before do
      rpc('initialize', { protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'x', version: '1' } })
    end

    it 'returns http ok with jsonrpc 2.0 and echoed id' do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['jsonrpc']).to eq('2.0')
      expect(response.parsed_body['id']).to eq(1)
    end

    it 'returns protocolVersion 2025-11-25' do
      expect(response.parsed_body['result']['protocolVersion']).to eq('2025-11-25')
    end

    it 'returns capabilities.tools and serverInfo' do
      result = response.parsed_body['result']
      expect(result['capabilities']['tools']).to be_a(Hash)
      expect(result['serverInfo']['name']).to eq('cast-me')
      expect(result['serverInfo']['version']).to be_present
    end
  end

  describe 'ping' do
    it 'returns an empty result' do
      rpc('ping')
      expect(response.parsed_body['result']).to eq({})
    end
  end

  describe 'notifications/initialized' do
    it 'accepts with no JSON-RPC response body' do
      post '/mcp', params: { jsonrpc: '2.0', method: 'notifications/initialized' }.to_json, headers: headers
      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_blank
    end
  end

  describe 'tools/list' do
    it 'lists the six tools with name, description and inputSchema' do
      rpc('tools/list')
      tools = response.parsed_body['result']['tools']
      names = tools.pluck('name')
      expect(names).to contain_exactly('get_day', 'create_plan', 'list_tasks', 'complete_task', 'get_input_status',
                                       'list_family')
      tools.each do |tool|
        expect(tool['description']).to be_present
        expect(tool['inputSchema']['type']).to eq('object')
      end
    end

    it 'does not expose health, meals, or medications tools' do
      rpc('tools/list')
      names = response.parsed_body['result']['tools'].pluck('name')
      expect(names.join(' ')).not_to match(/health|meal|medication/i)
    end

    it 'gives concrete schemas distinguishing plans from tasks and the YYYY-MM-DD date format' do
      rpc('tools/list')
      tools = response.parsed_body['result']['tools'].index_by { |t| t['name'] }
      expect(tools['create_plan']['inputSchema']['required']).to include('date', 'title')
      expect(tools['create_plan']['description']).to include('YYYY-MM-DD')
      expect(tools['create_plan']['description']).to match(/task/i)
      expect(tools['list_tasks']['description']).to include('YYYY-MM-DD')
      expect(tools['complete_task']['inputSchema']['required']).to include('task_id')
    end
  end

  describe 'tools/call get_day' do
    it 'returns plans, tasks and input_status as text JSON' do
      create(:plan, family: family, date: date, title: '歯医者', start_time: '10:00', end_time: '11:00')
      create(:task, family: family, user: user, date: date, title: 'ゴミ出し')
      call_tool('get_day', { date: date.iso8601 })
      result = response.parsed_body['result']
      expect(result['isError']).to be_nil.or be(false)
      payload = JSON.parse(result['content'].first['text'])
      expect(result['content'].first['type']).to eq('text')
      expect(payload['plans'].first['title']).to eq('歯医者')
      expect(payload['tasks'].first['title']).to eq('ゴミ出し')
      expect(payload['input_status']).to include('registered' => 1, 'completed' => 0, 'status' => 'partial')
    end

    it 'defaults date to today and rejects invalid date' do
      call_tool('get_day', { date: 'not-a-date' })
      expect(response.parsed_body['result']['isError']).to be true
    end
  end

  describe 'tools/call create_plan' do
    it 'creates a plan via the write API and returns it' do
      expect do
        call_tool('create_plan', { date: date.iso8601, title: '家族会議', start_time: '09:00' })
      end.to change(Plan, :count).by(1)
      result = response.parsed_body['result']
      expect(result['isError']).to be_nil.or be(false)
      payload = JSON.parse(result['content'].first['text'])
      expect(payload['title']).to eq('家族会議')
      expect(Plan.order(:id).last.participants).to contain_exactly(user)
    end

    it 'is idempotent for an identical re-sent request' do
      args = { date: date.iso8601, title: '予定', start_time: '10:00' }
      expect do
        call_tool('create_plan', args, id: 7)
        call_tool('create_plan', args, id: 7)
      end.to change(Plan, :count).by(1)
    end

    it 'rejects invalid arguments with isError' do
      call_tool('create_plan', { title: 'x' })
      expect(response.parsed_body['result']['isError']).to be true
      expect(Plan.count).to eq(0)
    end

    it 'rejects a participant from another family' do
      other = create(:user, family: create(:family))
      call_tool('create_plan', { date: date.iso8601, title: 'x', participant_ids: [other.id] })
      expect(response.parsed_body['result']['isError']).to be true
      expect(Plan.count).to eq(0)
    end
  end

  describe 'tools/call list_tasks' do
    it 'lists family tasks with counts and supports user filter' do
      create(:task, family: family, user: user, date: date, title: 'a')
      create(:task, family: family, user: other_member, date: date, title: 'b', completed: true)
      call_tool('list_tasks', { date: date.iso8601 })
      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload['tasks'].size).to eq(2)
      expect(payload['counts']).to eq('registered' => 2, 'completed' => 1, 'pending' => 1)

      call_tool('list_tasks', { date: date.iso8601, user_id: other_member.id })
      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload['tasks'].size).to eq(1)
      expect(payload['counts']['registered']).to eq(1)
    end
  end

  describe 'tools/call complete_task' do
    it 'marks a task completed' do
      task = create(:task, family: family, user: user, date: date, completed: false)
      call_tool('complete_task', { task_id: task.id })
      expect(task.reload.completed).to be true
      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload['completed']).to be true
    end

    it 'is idempotent' do
      task = create(:task, family: family, user: user, date: date, completed: false)
      call_tool('complete_task', { task_id: task.id })
      call_tool('complete_task', { task_id: task.id })
      expect(response.parsed_body['result']['isError']).to be_nil.or be(false)
      expect(task.reload.completed).to be true
    end

    it 'returns isError for unknown task' do
      call_tool('complete_task', { task_id: 999_999 })
      expect(response.parsed_body['result']['isError']).to be true
    end

    it 'does not complete a task in another family' do
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      other_task = create(:task, family: other_family, user: other_user, date: date)
      call_tool('complete_task', { task_id: other_task.id })
      expect(response.parsed_body['result']['isError']).to be true
      expect(other_task.reload.completed).to be false
    end

    it 'returns isError for missing task_id' do
      call_tool('complete_task', {})
      expect(response.parsed_body['result']['isError']).to be true
    end
  end

  describe 'tools/call get_input_status' do
    it 'returns input status' do
      create(:task, family: family, user: user, date: date, completed: true)
      create(:task, family: family, user: other_member, date: date, completed: false)
      call_tool('get_input_status', { date: date.iso8601 })
      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload).to include('registered' => 2, 'completed' => 1, 'status' => 'partial')
    end

    it 'supports user filter' do
      create(:task, family: family, user: user, date: date, completed: true)
      create(:task, family: family, user: other_member, date: date, completed: false)
      call_tool('get_input_status', { date: date.iso8601, user_id: user.id })
      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload).to include('registered' => 1, 'completed' => 1, 'status' => 'complete')
    end
  end

  describe 'tools/call list_family' do
    it 'lists family members' do
      other_member
      call_tool('list_family')
      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload).to contain_exactly(
        { 'id' => user.id, 'display_name' => 'father' },
        { 'id' => other_member.id, 'display_name' => 'mother' }
      )
    end
  end

  context 'when isolating families' do
    it 'does not expose another family data' do
      other_family = create(:family)
      other_user = create(:user, family: other_family, login_id: 'intruder')
      create(:plan, family: other_family, date: date, title: '他家族')
      create(:task, family: other_family, user: other_user, date: date, title: '他家族')
      call_tool('get_day', { date: date.iso8601 })
      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload['plans']).to eq([])
      expect(payload['tasks']).to eq([])
    end
  end

  describe 'unknown tool' do
    it 'returns isError content' do
      call_tool('nonexistent_tool', {})
      result = response.parsed_body['result']
      expect(result['isError']).to be true
      expect(result['content'].first['type']).to eq('text')
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'invalid params' do
    it 'returns isError for non-object params' do
      post '/mcp', params: { jsonrpc: '2.0', id: 1, method: 'tools/call', params: [] }.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['result']['isError']).to be true
    end
  end

  describe 'unknown method' do
    it 'returns JSON-RPC method not found' do
      rpc('does/not/exist')
      expect(response.parsed_body['error']['code']).to eq(-32_601)
      expect(response.parsed_body['jsonrpc']).to eq('2.0')
    end
  end

  describe 'invalid JSON' do
    it 'returns parse error' do
      post '/mcp', params: '{not json', headers: headers
      expect(response.parsed_body['error']['code']).to eq(-32_700)
    end
  end
end
