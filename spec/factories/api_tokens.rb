# frozen_string_literal: true

FactoryBot.define do
  factory :api_token do
    association :family
    name { 'alexa-lambda' }
    token_digest { ApiToken.digest(SecureRandom.urlsafe_base64(32)) }
  end
end
