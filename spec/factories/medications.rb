FactoryBot.define do
  factory :medication do
    family
    sequence(:name) { |n| "服薬#{n}" }
  end
end
