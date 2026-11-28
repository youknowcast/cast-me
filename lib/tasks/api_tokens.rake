# frozen_string_literal: true

namespace :api_tokens do
  desc 'Issue a family-scoped API token. Usage: FAMILY_ID=1 NAME=alexa-lambda bin/rails api_tokens:create'
  task create: :environment do
    family_id = ENV.fetch('FAMILY_ID') { raise ArgumentError, 'FAMILY_ID is required' }
    name = ENV.fetch('NAME') { raise ArgumentError, 'NAME is required' }

    family = Family.find(family_id)
    _record, raw_token = ApiToken.issue!(family: family, name: name)

    puts "API token issued for family_id=#{family.id} name=#{name}"
    puts "Token (shown once, store securely): #{raw_token}"
  end
end
