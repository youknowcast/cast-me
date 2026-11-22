require 'rails_helper'

RSpec.describe 'ReleaseNotes', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  describe 'GET /release_notes' do
    context 'when signed out' do
      it 'redirects to sign in' do
        get release_notes_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when signed in' do
      before { sign_in user }

      it 'renders the release notes page' do
        get release_notes_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include('リリースノート')
      end

      it 'shows each entry with its date, heading and bullets' do
        get release_notes_path

        expect(response.body).to include('2026/10/21')
        expect(response.body).to include('週間の家族ダッシュボード')
        expect(response.body).to include('日ごとの家族メモを編集できるようにしました')
      end

      it 'shows newer entries before older ones' do
        get release_notes_path

        expect(response.body.index('週間の家族ダッシュボード')).to be < response.body.index('一日のふりかえり')
      end

      it 'is reachable from the settings page' do
        get settings_path

        expect(response.body).to include(release_notes_path)
      end
    end
  end
end
