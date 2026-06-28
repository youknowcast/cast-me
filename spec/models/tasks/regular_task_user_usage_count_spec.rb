# == Schema Information
#
# Table name: regular_task_user_usage_counts
#
#  id              :integer          not null, primary key
#  usage_count     :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  regular_task_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_regular_task_user_usage_counts_on_user_and_count  (user_id,usage_count)
#  index_regular_task_user_usage_counts_unique             (regular_task_id,user_id) UNIQUE
#
require 'rails_helper'

RSpec.describe RegularTaskUserUsageCount, type: :model do
  describe 'associations' do
    let(:family) { create(:family) }
    let(:user) { create(:user, family: family) }
    let(:regular_task) { create(:regular_task, family: family) }
    let(:usage_count) { create(:regular_task_user_usage_count, regular_task: regular_task, user: user) }

    it 'belongs to regular_task' do
      expect(usage_count.regular_task).to eq(regular_task)
    end

    it 'belongs to user' do
      expect(usage_count.user).to eq(user)
    end
  end

  describe 'validations' do
    let(:family) { create(:family) }
    let(:user) { create(:user, family: family) }
    let(:regular_task) { create(:regular_task, family: family) }

    it 'is valid with valid attributes' do
      usage = build(:regular_task_user_usage_count, regular_task: regular_task, user: user)
      expect(usage).to be_valid
    end

    it 'is invalid without a regular_task_id' do
      usage = build(:regular_task_user_usage_count, regular_task: nil, user: user)
      expect(usage).not_to be_valid
    end

    it 'is invalid without a user_id' do
      usage = build(:regular_task_user_usage_count, regular_task: regular_task, user: nil)
      expect(usage).not_to be_valid
    end

    it 'is invalid with a duplicate user_id for the same regular_task' do
      create(:regular_task_user_usage_count, regular_task: regular_task, user: user)
      duplicate = build(:regular_task_user_usage_count, regular_task: regular_task, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it 'is invalid with a negative usage_count' do
      usage = build(:regular_task_user_usage_count, regular_task: regular_task, user: user, usage_count: -1)
      expect(usage).not_to be_valid
      expect(usage.errors[:usage_count]).to be_present
    end

    it 'is valid with usage_count of 0' do
      usage = build(:regular_task_user_usage_count, regular_task: regular_task, user: user, usage_count: 0)
      expect(usage).to be_valid
    end
  end

  describe 'default values' do
    it 'has a default usage_count of 0' do
      new_usage = described_class.new
      expect(new_usage.usage_count).to eq(0)
    end
  end
end
