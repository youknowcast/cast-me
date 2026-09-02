# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyReviewNotificationService, type: :service do
  describe '.notify_all' do
    let!(:family) { create(:family) }
    let!(:user1) { create(:user, family: family) }
    let!(:user2) { create(:user, family: family) }

    before do
      allow(PushNotificationService).to receive(:send_to_users)
    end

    it 'sends a notification to all users with the daily review url' do
      described_class.notify_all

      expect(PushNotificationService).to have_received(:send_to_users).with(
        user_ids: contain_exactly(user1.id, user2.id),
        title: '🌙 一日のふりかえり',
        message: kind_of(String),
        url: a_string_including('/daily_review')
      )
    end

    it 'returns the notified user count' do
      expect(described_class.notify_all).to eq({ count: 2 })
    end
  end
end
