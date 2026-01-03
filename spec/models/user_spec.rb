# == Schema Information
#
# Table name: users
#
#  id                 :integer          not null, primary key
#  avatar             :binary
#  birth              :date
#  encrypted_password :string           not null
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

    describe 'avatar validation' do
      it 'is valid with an avatar under 64KB' do
        small_avatar = 'x' * 1.kilobyte
        user = build(:user, family: family, avatar: small_avatar)
        expect(user).to be_valid
      end

      it 'is invalid with an avatar over 64KB' do
        large_avatar = 'x' * 65.kilobytes
        user = build(:user, family: family, avatar: large_avatar)
        expect(user).not_to be_valid
        expect(user.errors[:avatar]).to be_present
      end

      it 'is valid without an avatar' do
        user = build(:user, family: family, avatar: nil)
        expect(user).to be_valid
      end
    end

    describe 'birth validation' do
      it 'is valid with a past date' do
        user = build(:user, family: family, birth: 1.day.ago)
        expect(user).to be_valid
      end

      it 'is valid with today date' do
        user = build(:user, family: family, birth: Date.today)
        expect(user).to be_valid
      end

      it 'is invalid with a future date' do
        user = build(:user, family: family, birth: 1.day.from_now)
        expect(user).not_to be_valid
        expect(user.errors[:birth]).to include('は未来の日付にできません')
      end

      it 'is valid without birth' do
        user = build(:user, family: family, birth: nil)
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

  describe '#avatar_data_url' do
    let(:family) { create(:family) }

    it 'returns nil when avatar is not present' do
      user = create(:user, family: family, avatar: nil)
      expect(user.avatar_data_url).to be_nil
    end

    it 'returns base64 data URL when avatar is present' do
      user = create(:user, family: family, avatar: 'test_binary_data')
      expect(user.avatar_data_url).to start_with('data:image/png;base64,')
    end
  end
end
