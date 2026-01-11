FactoryBot.define do
  factory :article do
    user
    title { "Sample Article" }
    description { "Some content" }
    pinned { false }
  end
end
