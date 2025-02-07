# == Schema Information
#
# Table name: moments
#
#  id          :integer          not null, primary key
#  description :string
#  file_path   :string
#  link        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
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
