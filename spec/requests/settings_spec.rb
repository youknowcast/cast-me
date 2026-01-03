require 'rails_helper'

RSpec.describe 'Settings', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  before do
    sign_in user
  end

  describe 'PATCH /settings' do
    context 'with valid parameters' do
      let(:birth_date) { Date.new(1990, 1, 1) }

      it 'updates the user birthday' do
        patch settings_path, params: { user: { birth: birth_date } }
        expect(response).to redirect_to(settings_path)
        expect(flash[:notice]).to eq('設定を更新しました')
        expect(user.reload.birth).to eq(birth_date)
      end
    end

    context 'with invalid parameters' do
      it 'does not update the user and returns unprocessable entity' do
        patch settings_path, params: { user: { birth: 1.day.from_now } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(user.reload.birth).to be_nil
      end
    end
  end
end
