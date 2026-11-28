# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'api_tokens:create', type: :task do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  before { Rails.application.load_tasks }

  def run_task(env)
    Rake::Task['api_tokens:create'].reenable
    original = ENV.to_h
    ENV.update(env)
    output = StringIO.new
    $stdout = output
    Rake::Task['api_tokens:create'].invoke
    output.string
  ensure
    ENV.replace(original)
    $stdout = STDOUT
  end

  it 'issues a family-scoped token and shows the raw token once' do
    out = run_task('FAMILY_ID' => family.id.to_s, 'NAME' => 'alexa-lambda')
    expect(out).to match(/shown once/i)
    token = ApiToken.order(:id).last
    expect(token.family).to eq(family)
    expect(token.name).to eq('alexa-lambda')
    raw = out[/Token \(shown once.*: (\S+)/, 1]
    expect(ApiToken.authenticate(raw)).to eq(token)
  end

  it 'sets user_id when USER_ID is given' do
    run_task('FAMILY_ID' => family.id.to_s, 'NAME' => 't', 'USER_ID' => user.id.to_s)
    expect(ApiToken.order(:id).last.user).to eq(user)
  end

  it 'defaults user to nil when USER_ID is not given' do
    run_task('FAMILY_ID' => family.id.to_s, 'NAME' => 't')
    expect(ApiToken.order(:id).last.user).to be_nil
  end

  it 'rejects USER_ID outside the family' do
    other = create(:user, family: create(:family))
    expect do
      run_task('FAMILY_ID' => family.id.to_s, 'NAME' => 't', 'USER_ID' => other.id.to_s)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
