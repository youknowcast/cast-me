# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiToken, type: :model do
  let(:family) { create(:family) }

  describe '.digest' do
    it 'returns SHA256 hex digest' do
      expect(described_class.digest('secret')).to eq(Digest::SHA256.hexdigest('secret'))
    end
  end

  describe '.issue!' do
    let(:issued) { described_class.issue!(family: family, name: 'alexa-lambda') }
    let(:record) { issued.first }
    let(:raw_token) { issued.last }

    it 'returns a raw token' do
      expect(raw_token).to be_present
      expect(raw_token.length).to be >= 32
    end

    it 'creates a token for the family with the given name' do
      expect(record.family).to eq(family)
      expect(record.name).to eq('alexa-lambda')
    end

    it 'stores only the SHA256 digest, never the raw token' do
      expect(record.token_digest).to eq(described_class.digest(raw_token))
      expect(record.token_digest).not_to eq(raw_token)
      expect(record.reload.token_digest).to eq(described_class.digest(raw_token))
      expect(record.attributes).not_to have_key('token')
    end

    it 'is not revoked initially' do
      expect(record.revoked_at).to be_nil
    end
  end

  describe '.authenticate' do
    it 'returns the token for a valid raw token' do
      record, raw_token = described_class.issue!(family: family, name: 't')
      expect(described_class.authenticate(raw_token)).to eq(record)
    end

    it 'returns nil for invalid token' do
      described_class.issue!(family: family, name: 't')
      expect(described_class.authenticate('nope')).to be_nil
    end

    it 'returns nil for blank token' do
      expect(described_class.authenticate(nil)).to be_nil
      expect(described_class.authenticate('')).to be_nil
    end

    it 'returns nil for revoked token' do
      record, raw_token = described_class.issue!(family: family, name: 't')
      record.revoke!
      expect(record.revoked?).to be true
      expect(described_class.authenticate(raw_token)).to be_nil
    end
  end

  describe '#touch_last_used!' do
    it 'updates last_used_at' do
      record = create(:api_token, family: family)
      expect(record.last_used_at).to be_nil
      record.touch_last_used!
      expect(record.reload.last_used_at).to be_present
    end
  end

  describe 'Family association' do
    it 'is accessible via family.api_tokens' do
      token = create(:api_token, family: family)
      expect(family.api_tokens).to include(token)
    end
  end
end
