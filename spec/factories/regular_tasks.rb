# == Schema Information
#
# Table name: regular_tasks
#
#  id         :integer          not null, primary key
#  title      :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#
# Indexes
#
#  index_regular_tasks_on_family_id            (family_id)
#  index_regular_tasks_on_family_id_and_title  (family_id,title) UNIQUE
#
FactoryBot.define do
  factory :regular_task do
    association :family
    sequence(:title) { |n| "定型タスク#{n}" }
  end
end
