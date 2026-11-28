# frozen_string_literal: true

namespace :api_tokens do
  desc 'Issue a family-scoped API token. Usage: FAMILY_ID=1 NAME=alexa-lambda [USER_ID=1] bin/rails api_tokens:create'
  task create: :environment do
    family_id = ENV.fetch('FAMILY_ID') { raise ArgumentError, 'FAMILY_ID is required' }
    name = ENV.fetch('NAME') { raise ArgumentError, 'NAME is required' }

    family = Family.find(family_id)
    user = ENV['USER_ID'].present? ? family.users.find(ENV['USER_ID']) : nil
    _record, raw_token = ApiToken.issue!(family: family, name: name, user: user)

    puts "API token issued for family_id=#{family.id} name=#{name} user_id=#{user&.id}"
    puts "Token (shown once, store securely): #{raw_token}"
  end
end
