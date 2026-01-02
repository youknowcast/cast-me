FactoryBot.define do
  factory :plan_participant do
    association :plan
    association :user
    status { :pending }
  end
end
