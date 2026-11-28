# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'test_family', type: :task do
  before { Rails.application.load_tasks }

  def run_task
    Rake::Task['test_family'].reenable
    output = StringIO.new
    $stdout = output
    Rake::Task['test_family'].invoke
    output.string
  ensure
    $stdout = STDOUT
  end

  it 'creates a test_family with test users and a user-linked api token, printing the token once' do
    out = run_task
    family = Family.find_by(name: 'test_family')
    expect(family).to be_present
    expect(family.users.count).to eq(2)
    raw = out[/Token \(shown once.*: (\S+)/, 1] || out[/API token.*: (\S+)/, 1]
    expect(raw).to be_present
    token = family.api_tokens.find_by(name: 'test-family')
    expect(token.user).to eq(family.users.order(:id).first)
    expect(ApiToken.authenticate(raw)).to eq(token)
  end

  it 'is idempotent and does not duplicate family, users, or tokens' do
    run_task
    family_count = Family.where(name: 'test_family').count
    user_count = User.where(family: Family.find_by(name: 'test_family')).count
    token_count = ApiToken.where(name: 'test-family').count

    second = run_task

    expect(Family.where(name: 'test_family').count).to eq(family_count)
    expect(User.where(family: Family.find_by(name: 'test_family')).count).to eq(user_count)
    expect(ApiToken.where(name: 'test-family').count).to eq(token_count)
    expect(ApiToken.where(name: 'test-family').count).to eq(1)
    expect(second).not_to match(/shown once/i)
  end
end
