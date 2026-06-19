require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:family) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:task_template).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1000) }
    it { is_expected.to validate_inclusion_of(:priority).in_range(0..3) }
  end

  describe 'scopes' do
    let(:family) { create(:family) }
    let(:user) { create(:user, family: family) }
    let!(:high_priority_task) do
      create(:task, family: family, user: user, date: Time.zone.today, priority: 3, title: 'High')
    end
    let!(:low_priority_task) do
      create(:task, family: family, user: user, date: Time.zone.today, priority: 0, title: 'Low', completed: true)
    end
    let!(:other_task) { create(:task, date: Time.zone.tomorrow) }

    it 'filters by date, family, user and completion status' do
      expect(described_class.for_date(Time.zone.today)).to contain_exactly(high_priority_task, low_priority_task)
      expect(described_class.for_family(family.id)).to contain_exactly(high_priority_task, low_priority_task)
      expect(described_class.for_user(user.id)).to contain_exactly(high_priority_task, low_priority_task)
      expect(described_class.completed).to include(low_priority_task)
      expect(described_class.pending).to include(high_priority_task, other_task)
    end

    it 'orders higher priorities first' do
      expect(described_class.for_date(Time.zone.today).ordered_by_priority).to eq([high_priority_task,
                                                                                   low_priority_task])
    end
  end

  describe 'priority presentation' do
    it 'returns the corresponding label and CSS class' do
      expect(build(:task, priority: 0)).to have_attributes(priority_text: '低', priority_class: 'text-gray-500')
      expect(build(:task, priority: 1)).to have_attributes(priority_text: '中', priority_class: 'text-blue-600')
      expect(build(:task, priority: 2)).to have_attributes(priority_text: '高', priority_class: 'text-orange-600')
      expect(build(:task, priority: 3)).to have_attributes(priority_text: '緊急', priority_class: 'text-red-600')
    end
  end
end
