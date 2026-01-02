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
FactoryBot.define do
  factory :plan do
    association :family
    association :created_by, factory: :user
    sequence(:title) { |n| "予定#{n}" }
    date { Time.zone.today }
    start_time { '10:00' }
    end_time { '11:00' }
  end
end
