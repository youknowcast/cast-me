# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiIdempotencyKey, type: :model do
  let(:family) { create(:family) }

  describe 'schema' do
    let(:record) do
      described_class.create!(
        family: family, key: 'abc', request_hash: 'hash', response_status: 201,
        response_body: '{"id":1}', created_at: Time.current
      ).tap(&:reload)
    end

    it 'stores family, key and request hash' do
      expect(record.family).to eq(family)
      expect(record.key).to eq('abc')
      expect(record.request_hash).to eq('hash')
    end

    it 'stores response status and body' do
      expect(record.response_status).to eq(201)
      expect(record.response_body).to eq('{"id":1}')
    end

    it 'stores created_at' do
      expect(record.created_at).to be_present
    end
  end

  describe '.active' do
    it 'returns keys created within the retention window' do
      fresh = described_class.create!(family: family, key: 'k', request_hash: 'h', response_status: 201,
                                      response_body: '{}', created_at: 1.hour.ago)
      old = described_class.create!(family: family, key: 'k2', request_hash: 'h', response_status: 201,
                                    response_body: '{}', created_at: 25.hours.ago)
      expect(described_class.active).to include(fresh)
      expect(described_class.active).not_to include(old)
    end
  end

  describe 'Family association' do
    it 'is accessible via family.api_idempotency_keys' do
      key = described_class.create!(family: family, key: 'k', request_hash: 'h', response_status: 201,
                                    response_body: '{}', created_at: Time.current)
      expect(family.api_idempotency_keys).to include(key)
    end
  end
end
