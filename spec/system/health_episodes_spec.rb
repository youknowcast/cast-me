require 'rails_helper'

RSpec.describe 'Health episodes', type: :system do
  let(:family) { create(:family) }
  let!(:user) { create(:user, family: family, login_id: 'mama', password: 'password123') }

  before { sign_in_through_ui }

  it 'records a new episode' do
    visit new_health_episode_path
    fill_in '病名・症状', with: 'インフルエンザ'
    fill_in '開始日', with: Time.zone.today.to_s
    click_button '記録する'

    expect(page).to have_content '体調記録を追加しました'
    expect(page).to have_content 'インフルエンザ'
    expect(page).to have_content '経過観察中'
  end

  it 'adds a temperature and toggles the status of an existing episode' do
    episode = create(:health_episode, family: family, user: user, title: '発熱')
    visit health_episode_path(episode)

    within '#new_health_episode_temperature' do
      fill_in '体温', with: '38.5'
    end
    click_button '体温を記録'
    expect(page).to have_content '38.5'

    click_button '直った'
    expect(page).to have_content '回復済み'

    click_button '解除'
    expect(page).to have_content '経過観察中'
  end

  it 'keeps plan and bulk add in the family calendar header' do
    create(:everyday_task_template, family: family)
    visit calendar_path

    expect(page).to have_button '予定追加'
    expect(page).to have_button 'まとめて追加'
    expect(page).to have_button 'タスク追加'
    expect(page).to have_button '体調記録'
  end

  it 'keeps plan and bulk add in the my calendar header' do
    create(:everyday_task_template, family: family)
    visit my_calendar_path

    expect(page).to have_button '予定追加'
    expect(page).to have_button 'まとめて追加'
    expect(page).to have_button 'タスク追加'
    expect(page).to have_button '体調記録'
  end

  private

  def sign_in_through_ui
    visit new_user_session_path
    fill_in 'ログインID', with: 'mama'
    fill_in 'パスワード', with: 'password123'
    click_button 'ログイン'
  end
end
