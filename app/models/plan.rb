# == Schema Information
#
# Table name: plans
#
#  id          :integer          not null, primary key
#  date        :date             not null
#  description :text
#  end_time    :time
#  start_time  :time
#  title       :string(255)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  family_id   :bigint           not null
#  user_id     :bigint
#
# Indexes
#
#  index_plans_on_date_and_start_time  (date,start_time)
#  index_plans_on_family_id_and_date   (family_id,date)
#
class Plan < ApplicationRecord
  belongs_to :family
  belongs_to :user, optional: true # 作成者を記録（オプション）

  validates :family_id, presence: true
  validates :date, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  scope :for_date, ->(date) { where(date: date) }
  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :ordered_by_time, -> { order(:start_time, :title) }

  private

  def end_time_after_start_time
    if end_time <= start_time
      errors.add(:end_time, "は開始時刻より後に設定してください")
    end
  end
end 
