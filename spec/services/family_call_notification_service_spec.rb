# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FamilyCallNotificationService, type: :service do
  let(:family) { create(:family) }
  let(:caller_user) { create(:user, family: family) }
  let(:target_user) { create(:user, family: family) }

  describe '.notify' do
    before do
      allow(PushNotificationService).to receive(:send_to_user)
    end

    it 'sends notification with caller name in title' do
      described_class.notify(
        caller: caller_user,
        target_user: target_user,
        message: 'これを見たら連絡して'
      )

      expect(PushNotificationService).to have_received(:send_to_user).with(
        user_id: target_user.id,
        title: "#{caller_user.display_name} からの呼び出し",
        message: 'これを見たら連絡して'
      )
    end

    it 'sends custom message' do
      custom_message = '急ぎの用事があります'

      described_class.notify(
        caller: caller_user,
        target_user: target_user,
        message: custom_message
      )

      expect(PushNotificationService).to have_received(:send_to_user).with(
        user_id: target_user.id,
        title: "#{caller_user.display_name} からの呼び出し",
        message: custom_message
      )
    end
  end
end
