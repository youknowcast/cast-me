require 'rails_helper'

RSpec.describe TaskTemplate, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:everyday_task_template) }
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:tasks).dependent(:nullify) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_presence_of(:priority) }
    it { is_expected.to validate_numericality_of(:priority).only_integer }
  end
end
