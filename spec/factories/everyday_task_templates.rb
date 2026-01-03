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
FactoryBot.define do
  factory :everyday_task_template do
    family
    name { '朝のルーチン' }
  end
end
