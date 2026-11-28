# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /api/v1/plans', type: :request do
  let(:family) { create(:family, name: '家族A') }
  let(:token_user) { create(:user, family: family, login_id: 'father') }
  let(:other_member) { create(:user, family: family, login_id: 'mother') }
  let(:raw_token) { ApiToken.issue!(family: family, name: 'test', user: token_user).last }
  let(:headers) { { 'Authorization' => "Bearer #{raw_token}", 'CONTENT_TYPE' => 'application/json' } }
  let(:date) { Date.new(2026, 11, 28) }

  def post_plan(body, auth: headers, extra_headers: {})
    post '/api/v1/plans', params: body.to_json, headers: auth.merge(extra_headers)
  end

  context 'when authenticating' do
    let(:valid_body) { { date: date.iso8601, title: '歯医者' } }

    it 'returns 401 without token' do
      post '/api/v1/plans', params: valid_body.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'unauthorized')
    end

    it 'returns 401 with invalid token' do
      post_plan(valid_body, auth: { 'Authorization' => 'Bearer nope', 'CONTENT_TYPE' => 'application/json' })
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 with revoked token' do
      ApiToken.authenticate(raw_token)&.revoke!
      post_plan(valid_body)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not create a plan when unauthenticated' do
      expect do
        post '/api/v1/plans', params: valid_body.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
      end.not_to change(Plan, :count)
    end
  end

  context 'with valid parameters' do
    let(:create_body) { { date: date.iso8601, title: '歯医者', start_time: '10:00', end_time: '11:00' } }

    it 'creates a plan' do
      expect { post_plan(create_body) }.to change(Plan, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'persists the plan in the token family with parsed fields' do
      post_plan(create_body)
      plan = Plan.order(:id).last
      expect(plan.family).to eq(family)
      expect(plan.date).to eq(date)
      expect(plan.title).to eq('歯医者')
      expect(plan.start_time.strftime('%H:%M')).to eq('10:00')
      expect(plan.end_time.strftime('%H:%M')).to eq('11:00')
    end

    it 'sets created_by and last_edited_by to the token user' do
      post_plan(create_body)
      plan = Plan.order(:id).last
      expect(plan.created_by).to eq(token_user)
      expect(plan.last_edited_by).to eq(token_user)
    end

    it 'returns PlanSerializer JSON' do
      post_plan(create_body)
      plan = Plan.order(:id).last
      body = response.parsed_body
      expect(body).to include('id' => plan.id, 'title' => '歯医者', 'start_time' => '10:00', 'end_time' => '11:00')
      expect(body.keys).to contain_exactly('id', 'title', 'start_time', 'end_time', 'participants')
    end

    it 'creates a plan without start/end time' do
      post_plan({ date: date.iso8601, title: '終日' })
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['start_time']).to be_nil
      expect(response.parsed_body['end_time']).to be_nil
    end

    it 'creates plan participants' do
      post_plan({ date: date.iso8601, title: '家族会議', participant_ids: [token_user.id, other_member.id] })
      expect(response).to have_http_status(:created)
      plan = Plan.order(:id).last
      expect(plan.plan_participants.count).to eq(2)
      expect(response.parsed_body['participants'].pluck('id')).to contain_exactly(token_user.id, other_member.id)
    end
  end

  context 'with participants' do
    it 'defaults to the api_token user when participant_ids is omitted' do
      post_plan({ date: date.iso8601, title: 'x' })
      expect(response).to have_http_status(:created)
      participants = response.parsed_body['participants']
      expect(participants).to contain_exactly('id' => token_user.id, 'display_name' => 'father', 'status' => 'pending')
      expect(Plan.order(:id).last.participants).to contain_exactly(token_user)
    end

    it 'returns 422 when no participant can be decided' do
      token_without_user = ApiToken.issue!(family: family, name: 'nouser').last
      post_plan({ date: date.iso8601, title: 'x' },
                auth: { 'Authorization' => "Bearer #{token_without_user}", 'CONTENT_TYPE' => 'application/json' })
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 for an explicitly empty participant_ids array' do
      post_plan({ date: date.iso8601, title: 'x', participant_ids: [] })
      expect(response).to have_http_status(:unprocessable_content)
      expect(Plan.count).to eq(0)
    end

    it 'rejects a participant from another family' do
      other_family_user = create(:user, family: create(:family), login_id: 'intruder')
      post_plan({ date: date.iso8601, title: 'x', participant_ids: [other_family_user.id] })
      expect(response).to have_http_status(:unprocessable_content)
      expect(Plan.count).to eq(0)
    end

    it 'rejects unknown participant ids' do
      post_plan({ date: date.iso8601, title: 'x', participant_ids: [token_user.id, 999_999] })
      expect(response).to have_http_status(:unprocessable_content)
      expect(Plan.count).to eq(0)
    end

    it 'rejects non-integer participant ids' do
      post_plan({ date: date.iso8601, title: 'x', participant_ids: ['abc'] })
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'does not create participants from other families' do
      other_family_user = create(:user, family: create(:family))
      post_plan({ date: date.iso8601, title: 'x', participant_ids: [token_user.id, other_family_user.id] })
      expect(PlanParticipant.count).to eq(0)
    end
  end

  context 'when scoping to family' do
    it 'creates the plan in the token family only' do
      create(:family, name: '他家族')
      post_plan({ date: date.iso8601, title: 'x' })
      expect(Plan.order(:id).last.family).to eq(family)
    end
  end

  context 'with invalid date' do
    it 'returns 400 invalid_date for malformed date' do
      post_plan({ date: 'not-a-date', title: 'x' })
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'returns 400 invalid_date for impossible date' do
      post_plan({ date: '2026-13-40', title: 'x' })
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'returns 400 invalid_date for non-padded date' do
      post_plan({ date: '2026-1-2', title: 'x' })
      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 invalid_date for missing date' do
      post_plan({ title: 'x' })
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_date')
    end

    it 'returns 400 invalid_date for non-string date' do
      post_plan({ date: 20_261_128, title: 'x' })
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'with invalid time' do
    it 'returns 400 invalid_time for malformed start_time' do
      post_plan({ date: date.iso8601, title: 'x', start_time: 'foo' })
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_time')
    end

    it 'returns 400 invalid_time for out-of-range time' do
      post_plan({ date: date.iso8601, title: 'x', start_time: '25:00' })
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_time')
    end

    it 'returns 400 invalid_time for malformed end_time' do
      post_plan({ date: date.iso8601, title: 'x', end_time: '10:99' })
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'invalid_time')
    end

    it 'returns 400 invalid_time for non-padded time' do
      post_plan({ date: date.iso8601, title: 'x', start_time: '9:00' })
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'with invalid attributes' do
    it 'returns 422 when title is missing' do
      post_plan({ date: date.iso8601 })
      expect(response).to have_http_status(:unprocessable_content)
      expect(Plan.count).to eq(0)
    end

    it 'returns 422 when title is blank' do
      post_plan({ date: date.iso8601, title: '   ' })
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when end_time is before start_time' do
      post_plan({ date: date.iso8601, title: 'x', start_time: '11:00', end_time: '10:00' })
      expect(response).to have_http_status(:unprocessable_content)
      expect(Plan.count).to eq(0)
    end

    it 'returns JSON only' do
      post_plan({ date: 'bad', title: 'x' })
      expect(response.media_type).to eq('application/json')
    end

    it 'returns 400 JSON for a malformed JSON body' do
      post '/api/v1/plans', params: '{not json', headers: headers
      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq('application/json')
    end
  end

  context 'with idempotency' do
    let(:body) { { date: date.iso8601, title: '歯医者', start_time: '10:00' } }
    let(:key) { 'unique-key-123' }
    let(:idem_headers) { { 'Idempotency-Key' => key } }

    it 'replays the stored response for the same key and body without creating twice' do
      expect do
        post_plan(body, extra_headers: idem_headers)
        first_status = response.status
        first_body = response.parsed_body
        post_plan(body, extra_headers: idem_headers)
        expect(response.status).to eq(first_status)
        expect(response.parsed_body).to eq(first_body)
      end.to change(Plan, :count).by(1)
    end

    it 'stores response_status and response_body' do
      post_plan(body, extra_headers: idem_headers)
      record = ApiIdempotencyKey.find_by(family_id: family.id, key: key)
      expect(record).to be_present
      expect(record.request_hash).to be_present
      expect(record.response_status).to eq(201)
      expect(JSON.parse(record.response_body)['title']).to eq('歯医者')
    end

    it 'returns 409 when the same key is sent with a different body' do
      post_plan(body, extra_headers: idem_headers)
      expect do
        post_plan(body.merge(title: '別の予定'), extra_headers: idem_headers)
      end.not_to change(Plan, :count)
      expect(response).to have_http_status(:conflict)
    end

    it 'scopes keys per family' do
      post_plan(body, extra_headers: idem_headers)
      other_family = create(:family)
      other_user = create(:user, family: other_family)
      other_token = ApiToken.issue!(family: other_family, name: 't', user: other_user).last
      post_plan(body, auth: { 'Authorization' => "Bearer #{other_token}", 'CONTENT_TYPE' => 'application/json' },
                      extra_headers: idem_headers)
      expect(response).to have_http_status(:created)
      expect(Plan.count).to eq(2)
    end

    it 'allows reuse after 24 hours' do
      post_plan(body, extra_headers: idem_headers)
      record = ApiIdempotencyKey.find_by(family_id: family.id, key: key)
      record.update_column(:created_at, 25.hours.ago)
      expect do
        post_plan(body, extra_headers: idem_headers)
      end.to change(Plan, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'creates separate plans without an Idempotency-Key' do
      expect do
        post_plan(body)
        post_plan(body)
      end.to change(Plan, :count).by(2)
    end

    it 'does not record idempotency for invalid requests' do
      post_plan(body.merge(title: ''), extra_headers: idem_headers)
      expect(ApiIdempotencyKey.count).to eq(0)
      expect do
        post_plan(body, extra_headers: idem_headers)
      end.to change(Plan, :count).by(1)
    end
  end
end
