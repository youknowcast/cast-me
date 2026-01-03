require 'rails_helper'

RSpec.describe EverydayTaskTemplate, type: :model do
  describe 'associations' do
    it { should belong_to(:family) }
    it { should have_many(:task_templates).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end
end
