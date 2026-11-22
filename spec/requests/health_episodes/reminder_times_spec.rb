require 'rails_helper'

RSpec.describe 'HealthEpisodeReminderTimes', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:episode) { create(:health_episode, family: family, user: user) }

  before { sign_in user }

  describe 'POST /health_episodes/:id/reminder_times' do
    it 'adds a 30 minute slot' do
      expect do
        post health_episode_reminder_times_path(episode), params: { reminder_time: '08:30' }
      end.to change(episode.health_episode_reminder_times, :count).by(1)

      expect(episode.health_episode_reminder_times.last.label).to eq('08:30')
      expect(response).to redirect_to(health_episode_path(episode))
    end

    it 'does not duplicate an existing slot' do
      create(:health_episode_reminder_time, health_episode: episode, hour: 8, minute: 30)

      expect do
        post health_episode_reminder_times_path(episode), params: { reminder_time: '08:30' }
      end.not_to change(HealthEpisodeReminderTime, :count)
    end

    it 'rejects a time outside the 30 minute grid' do
      expect do
        post health_episode_reminder_times_path(episode), params: { reminder_time: '08:15' }
      end.not_to change(HealthEpisodeReminderTime, :count)

      expect(response).to redirect_to(health_episode_path(episode))
    end

    it 'does not add to an episode from another family' do
      other = create(:health_episode)

      expect do
        post health_episode_reminder_times_path(other), params: { reminder_time: '08:30' }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /health_episodes/:id/reminder_times/:id' do
    it 'removes the slot' do
      reminder_time = create(:health_episode_reminder_time, health_episode: episode)

      expect do
        delete health_episode_reminder_time_path(episode, reminder_time)
      end.to change(HealthEpisodeReminderTime, :count).by(-1)

      expect(response).to redirect_to(health_episode_path(episode))
    end
  end
end
