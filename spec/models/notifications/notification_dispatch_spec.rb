# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationDispatch, type: :model do
  let(:slot) { Time.zone.local(2026, 11, 14, 21, 30) }

  describe '.claim' do
    it 'returns a record the first time a slot is claimed' do
      record = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)

      expect(record).to be_a(described_class)
      expect(record).to be_persisted
      expect(record.attempts).to eq(0)
    end

    it 'rejects a second claim for the same slot' do
      described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)

      expect(described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)).to be_nil
    end

    it 'treats different kinds of the same user and slot as separate' do
      described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)

      expect(described_class.claim(kind: 'family_calendar', user_id: 1, slot_at: slot)).to be_present
    end

    it 'rejects an already sent slot' do
      record = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)
      record.mark_sent!

      expect(described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)).to be_nil
    end

    it 'reclaims a stale claim and counts the attempt' do
      record = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)
      record.update!(claimed_at: 3.minutes.ago)

      reclaimed = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)

      expect(reclaimed).to be_present
      expect(reclaimed.id).to eq(record.id)
      expect(reclaimed.attempts).to eq(1)
    end

    it 'rejects a claim that is still fresh' do
      described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)

      expect(described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)).to be_nil
    end
  end

  describe '#mark_failed!' do
    it 'stores the error and keeps the slot unsent' do
      record = described_class.claim(kind: 'daily_review', user_id: 1, slot_at: slot)
      record.mark_failed!('api down')

      expect(record.reload.error).to eq('api down')
      expect(record.sent_at).to be_nil
    end
  end

  describe '.build_key' do
    it 'encodes kind, user and slot in UTC' do
      expect(described_class.build_key('daily_review', 12, slot)).to eq('daily_review:12:202611141230')
    end
  end
end
