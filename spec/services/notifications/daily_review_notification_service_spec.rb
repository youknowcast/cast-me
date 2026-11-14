# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DailyReviewNotificationService, type: :service do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe '.notify' do
    before do
      allow(PushNotificationService).to receive(:send_to_user)
    end

    it 'sends the daily review push to the given user' do
      described_class.notify(user)

      expect(PushNotificationService).to have_received(:send_to_user).with(
        user_id: user.id,
        title: '🌙 一日のふりかえり',
        message: kind_of(String),
        url: a_string_including('/daily_review')
      )
    end
  end
end
