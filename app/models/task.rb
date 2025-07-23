# == Schema Information
#
# Table name: tasks
#
#  id          :integer          not null, primary key
#  completed   :boolean          default(FALSE), not null
#  date        :date             not null
#  description :text
#  priority    :integer          default(0), not null
#  title       :string(255)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  family_id   :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_tasks_on_date_and_completed  (date,completed)
#  index_tasks_on_family_id_and_date  (family_id,date)
#  index_tasks_on_user_id_and_date    (user_id,date)
#
class Task < ApplicationRecord
  belongs_to :family
  belongs_to :user

  validates :family_id, presence: true
  validates :user_id, presence: true
  validates :date, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validates :priority, inclusion: { in: 0..3 } # 0: 低, 1: 中, 2: 高, 3: 緊急

  scope :for_date, ->(date) { where(date: date) }
  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }
  scope :ordered_by_priority, -> { order(priority: :desc, title: :asc) }

  def priority_text
    case priority
    when 0 then "低"
    when 1 then "中"
    when 2 then "高"
    when 3 then "緊急"
    else "未設定"
    end
  end

  def priority_class
    case priority
    when 0 then "text-gray-500"
    when 1 then "text-blue-600"
    when 2 then "text-orange-600"
    when 3 then "text-red-600"
    else "text-gray-500"
    end
  end
end
