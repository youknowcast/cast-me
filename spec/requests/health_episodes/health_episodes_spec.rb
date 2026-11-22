require 'rails_helper'

RSpec.describe 'HealthEpisodes', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family, login_id: 'mama') }
  let(:member) { create(:user, family: family, login_id: 'kodo') }

  before { sign_in user }

  describe 'GET /health_episodes/new' do
    it 'renders the form starting on the requested date' do
      get new_health_episode_path(date: '2026-11-20')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('体調記録を追加')
      expect(controller.instance_variable_get(:@episode).started_on).to eq(Date.new(2026, 11, 20))
    end

    it 'renders a turbo stream that opens the side panel' do
      get new_health_episode_path(date: '2026-11-20'), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('side-panel')
    end
  end

  describe 'POST /health_episodes' do
    it 'creates an active episode for a family member' do
      expect do
        post health_episodes_path, params: {
          health_episode: { user_id: member.id, title: 'インフルエンザ', started_on: '2026-11-20' }
        }
      end.to change(family.health_episodes, :count).by(1)

      episode = family.health_episodes.last
      expect(response).to redirect_to(health_episode_path(episode))
      expect(episode).to be_active
      expect(episode.user).to eq(member)
    end

    it 'creates a recovered episode when an ended_on is given' do
      post health_episodes_path, params: {
        health_episode: { user_id: member.id, title: 'おたふく', started_on: '2026-11-10', ended_on: '2026-11-15' }
      }

      episode = family.health_episodes.last
      expect(episode).to be_recovered
      expect(episode.ended_on).to eq(Date.new(2026, 11, 15))
    end

    it 'defaults the target to the signed-in user' do
      post health_episodes_path, params: { health_episode: { title: '発熱', started_on: '2026-11-20' } }

      expect(family.health_episodes.last.user).to eq(user)
    end

    it 'rejects a user from another family' do
      outsider = create(:user)

      expect do
        post health_episodes_path, params: {
          health_episode: { user_id: outsider.id, title: '発熱', started_on: '2026-11-20' }
        }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'renders the form with errors when the title is blank' do
      expect do
        post health_episodes_path, params: {
          health_episode: { user_id: user.id, title: '', started_on: '2026-11-20' }
        }
      end.not_to change(HealthEpisode, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET /health_episodes/:id' do
    it 'shows the episode with its target' do
      episode = create(:health_episode, family: family, user: member, title: '発熱')
      create(:health_episode_temperature, health_episode: episode, value: 38.5)

      get health_episode_path(episode)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('発熱', member.login_id, '38.5', '経過観察中')
    end

    it 'does not show an episode from another family' do
      other = create(:health_episode, title: '他家族の体調')

      expect { get health_episode_path(other) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PATCH /health_episodes/:id' do
    let(:episode) { create(:health_episode, family: family, user: user, title: '発熱') }

    it 'updates the episode and the target' do
      patch health_episode_path(episode), params: {
        health_episode: { user_id: member.id, title: '気管支炎', started_on: '2026-11-18', symptom_note: '咳が続く' }
      }

      episode.reload
      expect(episode.title).to eq('気管支炎')
      expect(episode.user).to eq(member)
      expect(episode.symptom_note).to eq('咳が続く')
    end

    it 'saves medications from the family master' do
      medication = create(:medication, family: family, name: 'カロナール')

      patch health_episode_path(episode), params: { health_episode: { medication_ids: ['', medication.id] } }

      expect(episode.reload.medications).to contain_exactly(medication)
    end

    it 'clears medications when none are checked' do
      medication = create(:medication, family: family)
      episode.medications << medication

      patch health_episode_path(episode), params: { health_episode: { medication_ids: [''] } }

      expect(episode.reload.medications).to be_empty
    end

    it 'does not update an episode from another family' do
      other = create(:health_episode, title: '他家族')

      expect do
        patch health_episode_path(other), params: { health_episode: { title: '書き換え' } }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PATCH /health_episodes/:id/recover' do
    it 'ends the episode today' do
      episode = create(:health_episode, family: family, user: user, started_on: Time.zone.today - 2.days)

      patch recover_health_episode_path(episode)

      episode.reload
      expect(episode).to be_recovered
      expect(episode.ended_on).to eq(Time.zone.today)
      expect(response).to redirect_to(health_episode_path(episode))
    end
  end

  describe 'PATCH /health_episodes/:id/reopen' do
    it 'returns a recovered episode to active' do
      episode = create(:health_episode, family: family, user: user, started_on: Time.zone.today - 3.days,
                                        ended_on: Time.zone.today - 1.day)

      patch reopen_health_episode_path(episode)

      episode.reload
      expect(episode).to be_active
      expect(episode.ended_on).to be_nil
    end
  end

  describe 'calendar entry' do
    it 'lists the health episode action in the date header menu' do
      get calendar_path

      expect(response.body).to include('その他', '体調記録')
    end
  end

  describe 'weekly dashboard' do
    it 'shows a multi-day episode title only once' do
      week_start = Date.current.beginning_of_week
      create(:health_episode, family: family, user: member, title: 'インフルエンザ',
                              started_on: week_start, ended_on: week_start + 2)

      get weekly_dashboard_path

      expect(response.body.scan('インフルエンザ').size).to eq(1)
    end

    it 'does not show episodes from another family' do
      other = create(:health_episode, title: '他家族のエピソード')

      get weekly_dashboard_path

      expect(response.body).not_to include(other.title)
    end
  end

  describe 'monthly events list' do
    it 'shows an episode on its start date with the period' do
      create(:health_episode, family: family, user: member, title: 'おたふく',
                              started_on: Date.new(2026, 11, 5), ended_on: Date.new(2026, 11, 8))

      get monthly_list_calendar_path, params: { date: '2026-11-15' }, as: :turbo_stream

      expect(response.body).to include('2026年11月のできごと', 'おたふく', '11/5〜11/8')
    end

    it 'does not show episodes that start in another month' do
      create(:health_episode, family: family, user: member, title: '先月のエピソード',
                              started_on: Date.new(2026, 10, 30), ended_on: Date.new(2026, 11, 2))

      get monthly_list_calendar_path, params: { date: '2026-11-15' }, as: :turbo_stream

      expect(response.body).not_to include('先月のエピソード')
    end
  end
end
