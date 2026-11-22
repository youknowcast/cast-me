require 'rails_helper'

RSpec.describe HealthEpisode, type: :model do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  it 'has a valid factory' do
    expect(build(:health_episode, family: family, user: user)).to be_valid
  end

  it 'requires a title' do
    episode = build(:health_episode, family: family, user: user, title: '')
    expect(episode).not_to be_valid
    expect(episode.errors[:title]).to be_present
  end

  it 'requires a started_on' do
    episode = build(:health_episode, family: family, user: user, started_on: nil)
    expect(episode).not_to be_valid
  end

  it 'rejects an ended_on before started_on' do
    episode = build(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 10),
                                     ended_on: Date.new(2026, 11, 9))
    expect(episode).not_to be_valid
    expect(episode.errors[:ended_on]).to be_present
  end

  it 'rejects a user from another family' do
    episode = build(:health_episode, family: family, user: create(:user))
    expect(episode).not_to be_valid
    expect(episode.errors[:user]).to be_present
  end

  describe 'status' do
    it 'is active without an ended_on' do
      episode = create(:health_episode, family: family, user: user)
      expect(episode).to be_active
      expect(episode.ended_on).to be_nil
    end

    it 'is recovered when ended_on is given' do
      episode = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 18),
                                        ended_on: Date.new(2026, 11, 22))
      expect(episode).to be_recovered
    end

    it 'returns to active when ended_on is cleared' do
      episode = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 18),
                                        ended_on: Date.new(2026, 11, 22))
      episode.update!(ended_on: nil)
      expect(episode).to be_active
    end
  end

  describe 'period helpers' do
    it 'covers dates between started_on and ended_on' do
      episode = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 10),
                                        ended_on: Date.new(2026, 11, 12))
      expect(episode.covers?(Date.new(2026, 11, 9))).to be(false)
      expect(episode.covers?(Date.new(2026, 11, 10))).to be(true)
      expect(episode.covers?(Date.new(2026, 11, 12))).to be(true)
      expect(episode.covers?(Date.new(2026, 11, 13))).to be(false)
    end

    it 'covers every date from started_on while active' do
      episode = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 10))
      expect(episode.covers?(Date.new(2030, 1, 1))).to be(true)
    end

    it 'formats the period label' do
      episode = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 5),
                                        ended_on: Date.new(2026, 11, 8))
      expect(episode.period_label).to eq('11/5〜11/8')
    end

    it 'only places the band title on the first visible day of the week' do
      episode = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 4),
                                        ended_on: Date.new(2026, 11, 10))
      week_start = Date.new(2026, 11, 8)
      expect(episode.band_title_on?(Date.new(2026, 11, 8), week_start)).to be(true)
      expect(episode.band_title_on?(Date.new(2026, 11, 9), week_start)).to be(false)
    end
  end

  describe '.overlapping' do
    it 'includes episodes that intersect the range' do
      before_range = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 1),
                                             ended_on: Date.new(2026, 11, 4))
      inside = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 5),
                                       ended_on: Date.new(2026, 11, 6))
      ongoing = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 1))
      after_range = create(:health_episode, family: family, user: user, started_on: Date.new(2026, 11, 20))

      episodes = described_class.overlapping(Date.new(2026, 11, 5), Date.new(2026, 11, 11))

      expect(episodes).to include(inside, ongoing)
      expect(episodes).not_to include(before_range, after_range)
    end
  end
end
