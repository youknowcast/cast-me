# == Schema Information
#
# Table name: foods
#
#  id         :integer          not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  family_id  :bigint           not null
#
FactoryBot.define do
  factory :food do
    association :family
    sequence(:name) { |n| "食べ物#{n}" }
    active { true }
  end
end
