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
FactoryBot.define do
  factory :day_memo do
    association :family
    date { Time.zone.today }
    body { '家族メモ' }
  end
end
