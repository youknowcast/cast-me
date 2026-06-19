require 'rails_helper'

RSpec.describe 'User sessions', type: :request do
  let(:user) { create(:user, password: 'password123') }

  it 'stores a persistent remember token when requested' do
    post user_session_path, params: {
      user: { login_id: user.login_id, password: 'password123', remember_me: '1' }
    }

    expect(response).to redirect_to(calendar_path)
    expect(user.reload.remember_created_at).to be_present
    expect(set_cookie_header).to include('remember_user_token=')
    expect(set_cookie_header).to match(/expires=/i)

    cookies.delete(Rails.application.config.session_options[:key])
    get monthly_list_calendar_path, params: { date: Time.zone.today }, as: :turbo_stream

    expect(response).to have_http_status(:ok)
  end

  it 'does not store a remember token when disabled' do
    post user_session_path, params: {
      user: { login_id: user.login_id, password: 'password123', remember_me: '0' }
    }

    expect(response).to redirect_to(calendar_path)
    expect(user.reload.remember_created_at).to be_nil
    expect(set_cookie_header).not_to include('remember_user_token=')

    cookies.delete(Rails.application.config.session_options[:key])
    get monthly_list_calendar_path, params: { date: Time.zone.today }, as: :turbo_stream

    expect(response).to redirect_to(new_user_session_path)
  end

  def set_cookie_header
    Array(response.headers['Set-Cookie']).join("\n")
  end
end
