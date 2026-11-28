# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1 authentication', type: :request do
  let(:family) { create(:family) }
  let!(:user) { create(:user, family: family, login_id: 'father') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'test').last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}" } }

  before { host! 'localhost' }

  shared_examples 'requires family bearer token' do |method, path|
    it 'returns 401 unauthorized without Authorization header' do
      public_send(method, path)
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end

    it 'returns 401 unauthorized for invalid token' do
      public_send(method, path, headers: { 'Authorization' => 'Bearer invalid-token' })
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end

    it 'returns 401 unauthorized for revoked token' do
      record, raw = ApiToken.issue!(family: family, name: 'test')
      record.revoke!
      public_send(method, path, headers: { 'Authorization' => "Bearer #{raw}" })
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end

    it 'returns 401 unauthorized for non-Bearer scheme' do
      public_send(method, path, headers: { 'Authorization' => "Token #{raw_token}" })
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 unauthorized for Bearer without token' do
      public_send(method, path, headers: { 'Authorization' => 'Bearer' })
      expect(response).to have_http_status(:unauthorized)
    end

    it 'accepts bearer scheme case-insensitively' do
      public_send(method, path, headers: { 'Authorization' => "bearer #{raw_token}" })
      expect(response).not_to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/family/members' do
    it_behaves_like 'requires family bearer token', :get, '/api/v1/family/members'

    it 'updates last_used_at on successful authentication' do
      record, raw = ApiToken.issue!(family: family, name: 'test')
      expect(record.last_used_at).to be_nil

      get '/api/v1/family/members', headers: { 'Authorization' => "Bearer #{raw}" }

      expect(response).to have_http_status(:ok)
      expect(record.reload.last_used_at).to be_present
    end

    it 'does not return another family data' do
      other_family = create(:family, name: '他家族')
      create(:user, family: other_family, login_id: 'intruder')
      other_raw = ApiToken.issue!(family: other_family, name: 'test').last

      get '/api/v1/family/members', headers: { 'Authorization' => "Bearer #{other_raw}" }

      ids = response.parsed_body.pluck('id')
      expect(ids).not_to include(user.id)
      expect(response.parsed_body.pluck('display_name')).to contain_exactly('intruder')
    end

    it 'does not leak the token digest or family of other tokens' do
      get '/api/v1/family/members', headers: headers
      expect(response.body).not_to include(raw_token)
      expect(response.body).not_to include(ApiToken.digest(raw_token))
    end
  end

  describe 'CSRF' do
    it 'does not require a forgery token for the API' do
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      get '/api/v1/family/members', headers: headers
      expect(response).to have_http_status(:ok)
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end

  describe 'invalid date handling' do
    it 'returns 400 invalid_date for malformed date on /api/v1/today' do
      get '/api/v1/today', params: { date: 'not-a-date' }, headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end
  end
end
