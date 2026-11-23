require 'rails_helper'

RSpec.describe Medication, type: :model do
  let(:family) { create(:family) }

  it 'has a valid factory' do
    expect(build(:medication, family: family)).to be_valid
  end

  it 'requires a name' do
    expect(build(:medication, family: family, name: '')).not_to be_valid
  end

  it 'rejects a duplicate name in the same family' do
    create(:medication, family: family, name: 'カロナール')
    duplicate = build(:medication, family: family, name: 'カロナール')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it 'allows the same name in another family' do
    create(:medication, name: 'カロナール')
    expect(build(:medication, family: family, name: 'カロナール')).to be_valid
  end
end
