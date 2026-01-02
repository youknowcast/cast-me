# == Schema Information
#
# Table name: plans
#
#  id                :integer          not null, primary key
#  date              :date             not null
#  description       :text
#  end_time          :time
#  start_time        :time
#  title             :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  created_by_id     :bigint
#  family_id         :bigint           not null
#  last_edited_by_id :bigint
#
# Indexes
#
#  index_plans_on_date_and_start_time  (date,start_time)
#  index_plans_on_family_id_and_date   (family_id,date)
#
class Plan < ApplicationRecord
  belongs_to :family
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :last_edited_by, class_name: 'User', optional: true

  has_many :plan_participants, dependent: :destroy
  has_many :participants, through: :plan_participants, source: :user
  has_many :joined_plan_participants, lambda {
    joined
  }, class_name: 'PlanParticipant', dependent: :destroy, inverse_of: :plan
  has_many :joined_participants, through: :joined_plan_participants, source: :user
  has_many :active_plan_participants, -> { where.not(status: :declined) }, class_name: 'PlanParticipant',
                                                                           dependent: :destroy, inverse_of: :plan
  has_many :active_participants, through: :active_plan_participants, source: :user

  validates :date, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }
  validate :end_time_after_start_time, if: -> { start_time.present? && end_time.present? }

  scope :for_date, ->(date) { where(date: date) }
  scope :for_month, ->(date) { where(date: date.all_month) }
  scope :for_family, ->(family_id) { where(family_id: family_id) }
  scope :ordered_by_time, -> { order(:start_time, :title) }

  private

  def end_time_after_start_time
    return unless end_time < start_time

    errors.add(:end_time, 'は開始時刻より後に設定してください')
  end
end
