require 'rails_helper'

RSpec.describe HealthEpisodeReminderTime, type: :model do
  it 'has a valid factory' do
    expect(build(:health_episode_reminder_time)).to be_valid
  end

  it 'only accepts 0 or 30 minutes' do
    expect(build(:health_episode_reminder_time, minute: 15)).not_to be_valid
    expect(build(:health_episode_reminder_time, minute: 30)).to be_valid
  end

  it 'rejects an hour outside 0..23' do
    expect(build(:health_episode_reminder_time, hour: 24)).not_to be_valid
  end

  it 'rejects the same slot twice on one episode' do
    reminder = create(:health_episode_reminder_time, hour: 8, minute: 0)
    duplicate = build(:health_episode_reminder_time, health_episode: reminder.health_episode, hour: 8, minute: 0)
    expect(duplicate).not_to be_valid
  end

  it 'formats the label' do
    expect(build(:health_episode_reminder_time, hour: 8, minute: 30).label).to eq('08:30')
  end
end
