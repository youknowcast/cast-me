# == Schema Information
#
# Table name: moments
#
#  id          :bigint           not null, primary key
#  description :string(255)
#  file_path   :string(255)
#  link        :string(255)      not null
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
