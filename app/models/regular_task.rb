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
class RegularTask < ApplicationRecord
  belongs_to :family
  has_many :user_usage_counts, class_name: 'RegularTaskUserUsageCount', dependent: :destroy

  validates :title, presence: true, length: { maximum: 255 },
                    uniqueness: { scope: :family_id }

  scope :for_family, ->(family_id) { where(family_id: family_id) }

  # 特定ユーザの上位使用定型タスクを取得
  def self.top_used_for_user(user, limit: 3)
    joins(:user_usage_counts)
      .where(regular_task_user_usage_counts: { user_id: user.id })
      .order('regular_task_user_usage_counts.usage_count DESC, regular_tasks.title ASC')
      .limit(limit)
  end

  # ユーザの使用回数をインクリメント
  def increment_usage_for!(user)
    usage = user_usage_counts.find_or_create_by!(user: user)
    usage.increment!(:usage_count)
  end
end
