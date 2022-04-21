require 'rails_helper'

describe 'Moment' do

  context 'valid_url?' do
    subject { build(:moment, link: link) }
    let(:link) { 'https://example.com' }

    it 'succeeds' do
      is_expected.to be_valid
    end

    context 'when invalid url is specified' do
      let(:link) { 'this.is.not.url..' }
      it 'fails' do
        is_expected.to be_invalid
      end
    end
  end
end