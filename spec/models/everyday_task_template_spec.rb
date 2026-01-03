# == Schema Information
#
# Table name: everyday_task_templates
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#
# Indexes
#
#  index_everyday_task_templates_on_family_id  (family_id)
#
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
