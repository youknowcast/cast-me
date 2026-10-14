# == Schema Information
#
# Table name: day_memos
#
#  id         :integer          not null, primary key
#  body       :text
#  date       :date             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#
# Indexes
#
#  index_day_memos_on_family_id_and_date  (family_id,date) UNIQUE
#
class DayMemo < ApplicationRecord
  belongs_to :family

  validates :date, presence: true, uniqueness: { scope: :family_id }
  validates :body, length: { maximum: 1000 }
end
