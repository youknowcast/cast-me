require 'rails_helper'

RSpec.describe RegularTask, type: :model do
  describe 'associations' do
    let(:family) { create(:family) }
    let(:regular_task) { create(:regular_task, family: family) }
    let(:user) { create(:user, family: family) }

    it 'belongs to family' do
      expect(regular_task.family).to eq(family)
    end

    it 'has many user_usage_counts' do
      usage = create(:regular_task_user_usage_count, regular_task: regular_task, user: user)
      expect(regular_task.user_usage_counts).to include(usage)
    end

    it 'destroys associated user_usage_counts when destroyed' do
      create(:regular_task_user_usage_count, regular_task: regular_task, user: user)
      expect { regular_task.destroy }.to change(RegularTaskUserUsageCount, :count).by(-1)
    end
  end

  describe 'validations' do
    let(:family) { create(:family) }

    it 'is valid with valid attributes' do
      regular_task = build(:regular_task, family: family)
      expect(regular_task).to be_valid
    end

    it 'is invalid without a family_id' do
      regular_task = build(:regular_task, family: nil)
      expect(regular_task).not_to be_valid
      expect(regular_task.errors[:family_id]).to be_present
    end

    it 'is invalid without a title' do
      regular_task = build(:regular_task, family: family, title: nil)
      expect(regular_task).not_to be_valid
      expect(regular_task.errors[:title]).to be_present
    end

    it 'is invalid with a title longer than 255 characters' do
      regular_task = build(:regular_task, family: family, title: 'a' * 256)
      expect(regular_task).not_to be_valid
      expect(regular_task.errors[:title]).to be_present
    end

    it 'is invalid with a duplicate title in the same family' do
      create(:regular_task, family: family, title: '重複タイトル')
      duplicate = build(:regular_task, family: family, title: '重複タイトル')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:title]).to be_present
    end

    it 'is valid with the same title in different families' do
      other_family = create(:family)
      create(:regular_task, family: family, title: '同じタイトル')
      other_task = build(:regular_task, family: other_family, title: '同じタイトル')
      expect(other_task).to be_valid
    end
  end

  describe 'scopes' do
    describe '.for_family' do
      let(:family1) { create(:family) }
      let(:family2) { create(:family) }
      let!(:task1) { create(:regular_task, family: family1) }
      let!(:task2) { create(:regular_task, family: family2) }

      it 'returns regular tasks for the specified family' do
        expect(RegularTask.for_family(family1.id)).to eq([task1])
      end
    end
  end

  describe '.top_used_for_user' do
    let(:family) { create(:family) }
    let(:user) { create(:user, family: family) }
    let!(:task1) { create(:regular_task, family: family, title: 'Task A') }
    let!(:task2) { create(:regular_task, family: family, title: 'Task B') }
    let!(:task3) { create(:regular_task, family: family, title: 'Task C') }
    let!(:task4) { create(:regular_task, family: family, title: 'Task D') }

    before do
      create(:regular_task_user_usage_count, regular_task: task1, user: user, usage_count: 10)
      create(:regular_task_user_usage_count, regular_task: task2, user: user, usage_count: 5)
      create(:regular_task_user_usage_count, regular_task: task3, user: user, usage_count: 8)
      # task4 has no usage count for this user
    end

    it 'returns the top used tasks for the user ordered by usage count' do
      result = RegularTask.top_used_for_user(user, limit: 3)
      expect(result.map(&:title)).to eq(['Task A', 'Task C', 'Task B'])
    end

    it 'respects the limit parameter' do
      result = RegularTask.top_used_for_user(user, limit: 2)
      expect(result.count).to eq(2)
    end

    it 'does not include tasks with no usage for the user' do
      result = RegularTask.top_used_for_user(user, limit: 10)
      expect(result).not_to include(task4)
    end
  end

  describe '#increment_usage_for!' do
    let(:family) { create(:family) }
    let(:user) { create(:user, family: family) }
    let(:regular_task) { create(:regular_task, family: family) }

    context 'when user has no usage record' do
      it 'creates a new usage record with count 1' do
        expect {
          regular_task.increment_usage_for!(user)
        }.to change(RegularTaskUserUsageCount, :count).by(1)

        usage = regular_task.user_usage_counts.find_by(user: user)
        expect(usage.usage_count).to eq(1)
      end
    end

    context 'when user already has a usage record' do
      before do
        create(:regular_task_user_usage_count, regular_task: regular_task, user: user, usage_count: 5)
      end

      it 'increments the existing usage count' do
        expect {
          regular_task.increment_usage_for!(user)
        }.not_to change(RegularTaskUserUsageCount, :count)

        usage = regular_task.user_usage_counts.find_by(user: user)
        expect(usage.usage_count).to eq(6)
      end
    end
  end
end
