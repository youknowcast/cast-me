require 'rails_helper'

RSpec.describe 'HealthEpisodeTemperatures', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:episode) { create(:health_episode, family: family, user: user, title: '発熱') }

  before { sign_in user }

  describe 'POST /health_episodes/:id/temperatures' do
    it 'records a temperature' do
      expect do
        post health_episode_temperatures_path(episode), params: {
          health_episode_temperature: { measured_at: '2026-11-20T10:30', value: '38.5' }
        }
      end.to change(episode.health_episode_temperatures, :count).by(1)

      expect(response).to redirect_to(health_episode_path(episode))
      expect(episode.health_episode_temperatures.last.value).to eq(38.5)
    end

    it 'rejects an implausible value' do
      expect do
        post health_episode_temperatures_path(episode), params: {
          health_episode_temperature: { measured_at: '2026-11-20T10:30', value: '50' }
        }
      end.not_to change(HealthEpisodeTemperature, :count)

      expect(response).to redirect_to(health_episode_path(episode))
      expect(flash[:alert]).to be_present
    end

    it 'does not add to an episode from another family' do
      other = create(:health_episode)

      expect do
        post health_episode_temperatures_path(other), params: {
          health_episode_temperature: { measured_at: '2026-11-20T10:30', value: '38.5' }
        }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PATCH /health_episodes/:id/temperatures/:id' do
    let(:temperature) { create(:health_episode_temperature, health_episode: episode, value: 37.0) }

    it 'updates the measured time and value' do
      patch health_episode_temperature_path(episode, temperature), params: {
        health_episode_temperature: { measured_at: '2026-11-21T19:00', value: '39.2' }
      }

      temperature.reload
      expect(temperature.value).to eq(39.2)
      expect(temperature.measured_at).to eq(Time.zone.parse('2026-11-21 19:00'))
    end
  end

  describe 'DELETE /health_episodes/:id/temperatures/:id' do
    it 'removes the temperature' do
      temperature = create(:health_episode_temperature, health_episode: episode)

      expect do
        delete health_episode_temperature_path(episode, temperature)
      end.to change(HealthEpisodeTemperature, :count).by(-1)

      expect(response).to redirect_to(health_episode_path(episode))
    end
  end

  it 'rejects authenticated access for a temperature of another family' do
    other = create(:health_episode)
    temperature = create(:health_episode_temperature, health_episode: other)

    expect do
      delete health_episode_temperature_path(other, temperature)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
