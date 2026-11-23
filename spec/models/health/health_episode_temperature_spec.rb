require 'rails_helper'

RSpec.describe HealthEpisodeTemperature, type: :model do
  it 'has a valid factory' do
    expect(build(:health_episode_temperature)).to be_valid
  end

  it 'defaults measured_at to the current time' do
    temperature = described_class.new
    expect(temperature.measured_at).to be_within(1.minute).of(Time.current)
  end

  it 'requires a value' do
    temperature = build(:health_episode_temperature, value: nil)
    expect(temperature).not_to be_valid
    expect(temperature.errors[:value]).to be_present
  end

  it 'rejects values outside the plausible range' do
    expect(build(:health_episode_temperature, value: 29.9)).not_to be_valid
    expect(build(:health_episode_temperature, value: 45.1)).not_to be_valid
  end

  it 'accepts one decimal place' do
    expect(build(:health_episode_temperature, value: 36.5)).to be_valid
  end
end
