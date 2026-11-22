# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FamilyCalendarNotificationService, type: :service do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe '.notify' do
    it 'sends notification with calendar check message' do
      allow(PushNotificationService).to receive(:deliver)

      described_class.notify(user)

      expect(PushNotificationService).to have_received(:deliver).with(
        user_ids: [user.id],
        title: '今日の予定を確認しましょう',
        message: '家族のカレンダーをチェックする時間です'
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
