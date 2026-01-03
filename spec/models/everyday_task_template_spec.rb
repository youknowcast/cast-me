require 'rails_helper'

RSpec.describe EverydayTaskTemplate, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:family) }
    it { is_expected.to have_many(:task_templates).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
  end
end
