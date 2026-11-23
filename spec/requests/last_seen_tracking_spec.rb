require 'rails_helper'

RSpec.describe 'Last seen tracking', type: :request do
  let(:user) { create(:user) }
  let(:start_time) { Time.zone.parse('2026-11-23 09:00') }

  it 'records last_seen_at for a signed in user' do
    sign_in user

    travel_to(start_time) { get calendar_path }

    expect(user.reload.last_seen_at).to be_within(1.second).of(start_time)
  end

  it 'does not update last_seen_at again within 30 minutes' do
    sign_in user
    travel_to(start_time) { get calendar_path }
    first_seen_at = user.reload.last_seen_at

    travel_to(start_time + 10.minutes) { get calendar_path }

    expect(user.reload.last_seen_at).to eq(first_seen_at)
  end

  it 'updates last_seen_at after 30 minutes have passed' do
    sign_in user
    travel_to(start_time) { get calendar_path }

    travel_to(start_time + 31.minutes) { get calendar_path }

    expect(user.reload.last_seen_at).to be_within(1.second).of(start_time + 31.minutes)
  end

  it 'does not record last_seen_at for signed out visitors' do
    user

    travel_to(start_time) { get new_user_session_path }

    expect(user.reload.last_seen_at).to be_nil
  end
end
