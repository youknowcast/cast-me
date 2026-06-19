require 'rails_helper'

RSpec.describe 'PlanParticipants', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }
  let(:participant_user) { create(:user, family: family) }
  let(:plan) { create(:plan, family: family, date: Time.zone.today) }
  let(:participant) { create(:plan_participant, plan: plan, user: participant_user, status: :pending) }

  before { sign_in user }

  it 'updates a family participant and refreshes the calendar' do
    patch plan_participant_path(participant), params: { status: 'joined', scope: 'family' }, as: :turbo_stream

    expect(response).to have_http_status(:success)
    expect(participant.reload).to be_joined
    expect(response.body).to include('target="daily_details"')
    expect(response.body).to include("target=\"calendar-cell-#{plan.date}\"")
  end

  it 'does not update a participant from another family' do
    other_participant = create(:plan_participant, status: :pending)

    patch plan_participant_path(other_participant), params: { status: 'joined' }, as: :turbo_stream

    expect(response).to have_http_status(:success)
    expect(response.body).to include('更新に失敗しました。')
    expect(other_participant.reload).to be_pending
  end

  it 'redirects with an alert when the participant is not found' do
    patch plan_participant_path(0), params: { status: 'joined', date: plan.date }

    expect(response).to redirect_to(calendar_path(date: plan.date))
    expect(flash[:alert]).to eq('更新に失敗しました。')
  end
end
