# frozen_string_literal: true

desc 'Create an idempotent test family with test users and a user-linked API token for verification. ' \
     'Not part of seeds. Prints the raw API token once. Usage: bin/rails test_family'
task test_family: :environment do
  family_name = 'test_family'
  token_name = 'test-family'
  test_login_ids = %w[test_family_user_1 test_family_user_2]

  family = Family.find_or_create_by!(name: family_name)

  users = test_login_ids.map do |login_id|
    family.users.find_or_create_by!(login_id: login_id) do |new_user|
      new_user.password = SecureRandom.urlsafe_base64(24)
    end
  end

  puts "test family ready: family_id=#{family.id} name=#{family_name}"
  puts "test users: #{users.map { |u| "#{u.id}:#{u.login_id}" }.join(', ')}"
  puts "token user_id=#{users.first.id}"

  if family.api_tokens.exists?(name: token_name)
    puts "api token '#{token_name}' already exists for family_id=#{family.id}; not re-issued. " \
         'Use the previously shown token, or revoke it and re-run.'
  else
    _record, raw_token = ApiToken.issue!(family: family, name: token_name, user: users.first)
    puts "API token (shown once, store securely): #{raw_token}"
  end
end
