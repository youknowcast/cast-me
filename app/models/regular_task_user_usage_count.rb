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
# Indexes
#
#  index_regular_task_user_usage_counts_on_user_and_count  (user_id,usage_count)
#  index_regular_task_user_usage_counts_unique             (regular_task_id,user_id) UNIQUE
#
class RegularTaskUserUsageCount < ApplicationRecord
  belongs_to :regular_task
  belongs_to :user

  validates :user_id, uniqueness: { scope: :regular_task_id }
  validates :usage_count, numericality: { greater_than_or_equal_to: 0 }
end
