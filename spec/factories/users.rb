# == Schema Information
#
# Table name: users
#
#  id                 :integer          not null, primary key
#  encrypted_password :string           not null
#  login_id           :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  family_id          :bigint           not null
#
FactoryBot.define do
  factory :user do
    association :family
    sequence(:login_id) { |n| "user#{n}" }
    password { "password123" }
  end
end
