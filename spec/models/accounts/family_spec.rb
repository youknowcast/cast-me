require 'rails_helper'

RSpec.describe Family, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:users).dependent(:destroy) }
    it { is_expected.to have_many(:plans).dependent(:destroy) }
    it { is_expected.to have_many(:tasks).dependent(:destroy) }
    it { is_expected.to have_many(:regular_tasks).dependent(:destroy) }
    it { is_expected.to have_many(:everyday_task_templates).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end
end
