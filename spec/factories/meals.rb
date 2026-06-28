# == Schema Information
#
# Table name: meals
#
#  id         :integer          not null, primary key
#  date       :date             not null
#  meal_type  :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#  user_id    :bigint
#
FactoryBot.define do
  factory :meal do
    association :family
    user { nil }
    date { Time.zone.today }
    meal_type { 1 } # 昼
  end
end
