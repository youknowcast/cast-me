require 'rails_helper'

RSpec.describe 'Health episodes on the daily calendar', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family, login_id: 'mama') }
  let(:member) { create(:user, family: family, login_id: 'kodo') }
  let(:today) { Time.zone.today }

  before do
    member
    sign_in user
  end

  describe 'family daily view' do
    it 'shows an active episode with a quick temperature form' do
      episode = create(:health_episode, family: family, user: member, title: 'インフルエンザ',
                                        started_on: today - 1.day)

      get calendar_path(date: today.to_s)

      expect(response.body).to include('体調', 'インフルエンザ', '経過観察中')
      expect(response.body).to include(health_episode_path(episode))
      expect(response.body).to include("quick_temperature_form_#{episode.id}")
    end

    it 'shows a recovered episode without the temperature form' do
      create(:health_episode, family: family, user: member, title: '胃腸炎',
                              started_on: today - 3.days, ended_on: today)

      get calendar_path(date: today.to_s)

      expect(response.body).to include('胃腸炎', '回復済み')
      expect(response.body).not_to include('quick_temperature_form_')
    end

    it 'defaults the quick temperature time to the selected day' do
      episode = create(:health_episode, family: family, user: member, title: '発熱', started_on: today - 2.days)
      selected = today - 1.day

      get calendar_path(date: selected.to_s)

      value = response.parsed_body.at_css("#quick_temperature_#{episode.id}_measured_at")['value']
      expect(value).to start_with(selected.strftime('%Y-%m-%d'))
    end

    it 'links to a new episode prefilled with the member and date' do
      get calendar_path(date: today.to_s)

      expect(response.body).to include("/health_episodes/new?date=#{today}")
      expect(response.body).to include("user_id=#{member.id}")
    end

    it 'does not show episodes from another family' do
      create(:health_episode, title: '他家族の体調')

      get calendar_path(date: today.to_s)

      expect(response.body).not_to include('他家族の体調')
    end
  end

  describe 'my daily view' do
    it 'shows the signed-in user episode with a quick temperature form' do
      mine = create(:health_episode, family: family, user: user, title: '自分の発熱', started_on: today - 1.day)
      create(:health_episode, family: family, user: member, title: '家族の発熱', started_on: today - 1.day)

      get my_calendar_path(date: today.to_s)

      expect(response.body).to include('自分の発熱', "quick_temperature_form_#{mine.id}")
      expect(response.body).not_to include('家族の発熱')
    end

    it 'links to a new episode for the signed-in user' do
      get my_calendar_path(date: today.to_s)

      expect(response.body).to include("/health_episodes/new?date=#{today}")
      expect(response.body).to include("user_id=#{user.id}")
    end
  end

  describe 'saving a temperature from the calendar' do
    let(:episode) { create(:health_episode, family: family, user: member, title: '発熱', started_on: today - 1.day) }
    let(:temperature_params) do
      { health_episode_temperature: { measured_at: "#{today}T10:30", value: '38.5' } }
    end

    it 'records the temperature and returns to the family calendar' do
      expect do
        post health_episode_temperatures_path(episode),
             params: temperature_params.merge(return_to: 'calendar', date: today.to_s)
      end.to change(episode.health_episode_temperatures, :count).by(1)

      expect(response).to redirect_to(calendar_path(date: today.to_s))
      expect(flash[:notice]).to eq('体温を記録しました')
    end

    it 'returns to the my calendar when asked' do
      post health_episode_temperatures_path(episode),
           params: temperature_params.merge(return_to: 'my_calendar', date: today.to_s)

      expect(response).to redirect_to(my_calendar_path(date: today.to_s))
    end

    it 'falls back to the episode page without a return target' do
      post health_episode_temperatures_path(episode), params: temperature_params

      expect(response).to redirect_to(health_episode_path(episode))
    end

    it 'does not record against an episode from another family' do
      other = create(:health_episode, title: '他家族')

      expect do
        post health_episode_temperatures_path(other), params: temperature_params
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'new episode prefill' do
    it 'starts the episode for the requested member and date' do
      get new_health_episode_path(date: '2026-11-20', user_id: member.id)

      expect(response).to have_http_status(:ok)
      episode = controller.instance_variable_get(:@episode)
      expect(episode.user).to eq(member)
      expect(episode.started_on).to eq(Date.new(2026, 11, 20))
      expect(response.body).to include(member.login_id)
    end

    it 'defaults to the signed-in user without a user_id' do
      get new_health_episode_path(date: '2026-11-20')

      expect(controller.instance_variable_get(:@episode).user).to eq(user)
    end

    it 'rejects a user from another family' do
      outsider = create(:user)

      expect do
        get new_health_episode_path(user_id: outsider.id)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
