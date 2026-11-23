require 'rails_helper'

RSpec.describe 'Medications', type: :request do
  let(:family) { create(:family) }
  let(:user) { create(:user, family: family) }

  before { sign_in user }

  describe 'GET /medications' do
    it 'lists the family master' do
      create(:medication, family: family, name: 'カロナール')

      get medications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('カロナール')
    end
  end

  describe 'POST /medications' do
    it 'adds a medication to the family master' do
      expect do
        post medications_path, params: { medication: { name: 'カロナール' } }
      end.to change(family.medications, :count).by(1)

      expect(response).to redirect_to(medications_path)
    end

    it 'attaches the new medication to the episode when requested' do
      episode = create(:health_episode, family: family, user: user)

      expect do
        post medications_path, params: { medication: { name: '解熱剤' }, health_episode_id: episode.id }
      end.to change(episode.health_episode_medications, :count).by(1)

      expect(response).to redirect_to(health_episode_path(episode))
    end

    it 'rejects a duplicate name on the master page' do
      create(:medication, family: family, name: '重複')

      expect do
        post medications_path, params: { medication: { name: '重複' } }
      end.not_to change(Medication, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'does not attach a medication to an episode from another family' do
      other = create(:health_episode)

      expect do
        post medications_path, params: { medication: { name: '解熱剤' }, health_episode_id: other.id }
      end.not_to change(HealthEpisodeMedication, :count)
    end
  end

  describe 'PATCH /medications/:id' do
    let(:medication) { create(:medication, family: family, name: '旧名') }

    it 'renames the medication' do
      patch medication_path(medication), params: { medication: { name: '新名' } }

      expect(medication.reload.name).to eq('新名')
    end

    it 'does not update a medication from another family' do
      other = create(:medication, name: '他家族')

      expect do
        patch medication_path(other), params: { medication: { name: '書き換え' } }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
