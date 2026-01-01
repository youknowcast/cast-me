# == Schema Information
#
# Table name: families
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :family do
    sequence(:name) { |n| "テスト家族#{n}" }
  end
end
