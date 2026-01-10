# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calls', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:target_user) { create(:user, family: family) }

  before do
    sign_in user
    allow(FamilyCallNotificationService).to receive(:notify)
  end

  describe 'POST /calls' do
    it 'sends call notification to target user' do
      post calls_path, params: { user_id: target_user.id, message: 'テストメッセージ' }

      expect(FamilyCallNotificationService).to have_received(:notify).with(
        caller: user,
        target_user: target_user,
        message: 'テストメッセージ'
      )
    end

    it 'uses default message when message is blank' do
      post calls_path, params: { user_id: target_user.id, message: '' }

      expect(FamilyCallNotificationService).to have_received(:notify).with(
        caller: user,
        target_user: target_user,
        message: 'これを見たら連絡して'
      )
    end

    it 'redirects back with success notice' do
      post calls_path, params: { user_id: target_user.id }

      expect(response).to redirect_to(calendar_path)
      follow_redirect!
      expect(response.body).to include('呼び出しを送信しました')
    end

    context 'when target user is not in same family' do
      let(:other_family) { create(:family) }
      let(:other_user) { create(:user, family: other_family) }

      it 'raises RecordNotFound error' do
        expect do
          post calls_path, params: { user_id: other_user.id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
