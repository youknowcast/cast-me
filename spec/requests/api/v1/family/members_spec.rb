# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /api/v1/family/members', type: :request do
  let(:family) { create(:family, name: '家族A') }
  let!(:father) { create(:user, family: family, login_id: 'father') }
  let!(:mother) { create(:user, family: family, login_id: 'mother') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'test').last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}" } }

  before { host! 'localhost' }

  it 'returns id and display_name for family members' do
    get '/api/v1/family/members', headers: headers

    expect(response).to have_http_status(:ok)
    json = response.parsed_body
    expect(json).to contain_exactly(
      { 'id' => father.id, 'display_name' => 'father' },
      { 'id' => mother.id, 'display_name' => 'mother' }
    )
  end

  it 'uses User#display_name' do
    allow_any_instance_of(User).to receive(:display_name).and_return('表示名') # rubocop:disable RSpec/AnyInstance
    get '/api/v1/family/members', headers: headers
    expect(response.parsed_body.pluck('display_name')).to all(eq('表示名'))
  end

  it 'returns members ordered by id' do
    get '/api/v1/family/members', headers: headers
    ids = response.parsed_body.pluck('id')
    expect(ids).to eq(ids.sort)
  end

  it 'does not return members of other families' do
    other_family = create(:family, name: '他家族')
    create(:user, family: other_family, login_id: 'intruder')

    get '/api/v1/family/members', headers: headers

    names = response.parsed_body.pluck('display_name')
    expect(names).to contain_exactly('father', 'mother')
  end

  it 'returns member shape with only id and display_name' do
    get '/api/v1/family/members', headers: headers
    expect(response.parsed_body.first.keys).to contain_exactly('id', 'display_name')
  end

  context 'when authentication is required' do
    it 'returns 401 when token missing' do
      get '/api/v1/family/members'
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end

    it 'returns 401 for invalid token' do
      get '/api/v1/family/members', headers: { 'Authorization' => 'Bearer nope' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
