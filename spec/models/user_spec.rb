# == Schema Information
#
# Table name: users
#
#  id                 :integer          not null, primary key
#  encrypted_password :string           not null
#  icon               :binary
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  family_id          :bigint           not null
#  login_id           :string           not null
#
# Indexes
#
#  index_login_id_on_users  (login_id)
#
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    let(:family) { create(:family) }

    describe 'icon validation' do
      it 'is valid with an icon under 64KB' do
        small_icon = 'x' * 1.kilobyte
        user = build(:user, family: family, icon: small_icon)
        expect(user).to be_valid
      end

      it 'is invalid with an icon over 64KB' do
        large_icon = 'x' * 65.kilobytes
        user = build(:user, family: family, icon: large_icon)
        expect(user).not_to be_valid
        expect(user.errors[:icon]).to be_present
      end

      it 'is valid without an icon' do
        user = build(:user, family: family, icon: nil)
        expect(user).to be_valid
      end
    end
  end

  describe '#display_name' do
    let(:family) { create(:family) }

    it 'returns login_id' do
      user = create(:user, family: family, login_id: 'testuser1')
      expect(user.display_name).to eq('testuser1')
    end
  end

  describe '#icon_data_url' do
    let(:family) { create(:family) }

    it 'returns nil when icon is not present' do
      user = create(:user, family: family, icon: nil)
      expect(user.icon_data_url).to be_nil
    end

    it 'returns base64 data URL when icon is present' do
      user = create(:user, family: family, icon: 'test_binary_data')
      expect(user.icon_data_url).to start_with('data:image/png;base64,')
    end
  end
end
