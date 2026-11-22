# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyReviewNotificationService, type: :service do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe '.notify' do
    before do
      allow(PushNotificationService).to receive(:deliver)
    end

    it 'sends the daily review push to the given user' do
      described_class.notify(user)

      expect(PushNotificationService).to have_received(:deliver).with(
        user_ids: [user.id],
        title: '🌙 一日のふりかえり',
        message: kind_of(String),
        url: a_string_including('/daily_review')
      )
    end

    it 'lets DeliveryError reach the caller' do
      allow(PushNotificationService).to receive(:deliver)
        .and_raise(PushNotificationService::DeliveryError, 'boom')

      expect { described_class.notify(user) }
        .to raise_error(PushNotificationService::DeliveryError, 'boom')
    end
  end
end
