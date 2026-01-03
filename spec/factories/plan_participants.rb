# == Schema Information
#
# Table name: plan_participants
#
#  id         :integer          not null, primary key
#  status     :integer          default("pending"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  plan_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_plan_participants_on_plan_id_and_user_id  (plan_id,user_id) UNIQUE
#
FactoryBot.define do
  factory :plan_participant do
    association :plan
    association :user
    status { :pending }
  end
end
