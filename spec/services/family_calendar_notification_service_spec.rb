# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FamilyCalendarNotificationService, type: :service do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe '.notify' do
    it 'sends notification with calendar check message' do
      allow(PushNotificationService).to receive(:send_to_user)

      described_class.notify(user)

      expect(PushNotificationService).to have_received(:send_to_user).with(
        user_id: user.id,
        title: '今日の予定を確認しましょう',
        message: '家族のカレンダーをチェックする時間です'
      )
    end
  end
end
