# == Schema Information
#
# Table name: regular_task_user_usage_counts
#
#  id              :integer          not null, primary key
#  usage_count     :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  regular_task_id :bigint           not null
#  user_id         :bigint           not null
#
FactoryBot.define do
  factory :regular_task_user_usage_count do
    association :regular_task
    association :user
    usage_count { 0 }
  end
end
