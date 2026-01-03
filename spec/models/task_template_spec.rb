require 'rails_helper'

RSpec.describe TaskTemplate, type: :model do
  describe 'associations' do
    it { should belong_to(:everyday_task_template) }
    it { should belong_to(:user) }
    it { should have_many(:tasks).dependent(:nullify) }
  end

  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_presence_of(:priority) }
    it { should validate_numericality_of(:priority).only_integer }
  end
end
