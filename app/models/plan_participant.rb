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
class PlanParticipant < ApplicationRecord
  belongs_to :plan
  belongs_to :user

  enum status: { pending: 0, joined: 1, declined: 2 }

  validates :user_id, uniqueness: { scope: :plan_id }
end
