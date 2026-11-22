require 'rails_helper'

RSpec.describe HealthEpisodeMedication, type: :model do
  it 'has a valid factory' do
    expect(build(:health_episode_medication)).to be_valid
  end

  it 'rejects the same medication twice on one episode' do
    link = create(:health_episode_medication)
    duplicate = build(:health_episode_medication, health_episode: link.health_episode, medication: link.medication)
    expect(duplicate).not_to be_valid
  end

  it 'rejects a medication from another family' do
    episode = create(:health_episode)
    link = build(:health_episode_medication, health_episode: episode, medication: create(:medication))
    expect(link).not_to be_valid
    expect(link.errors[:medication]).to be_present
  end
end
