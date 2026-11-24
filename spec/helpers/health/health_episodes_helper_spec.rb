require 'rails_helper'

RSpec.describe HealthEpisodesHelper, type: :helper do
  describe '#temperature_choices' do
    it 'covers 35.0 to 41.9 in 0.1 steps with a unit label' do
      choices = helper.temperature_choices

      expect(choices.size).to eq(70)
      expect(choices.first).to eq(['35.0℃', '35.0'])
      expect(choices.last).to eq(['41.9℃', '41.9'])
    end

    it 'contains the stored value' do
      expect(helper.temperature_choices(37.6)).to include(['37.6℃', '37.6'])
    end

    it 'keeps a value outside the range selectable' do
      choices = helper.temperature_choices(42.3)

      expect(choices.size).to eq(71)
      expect(choices.last).to eq(['42.3℃', '42.3'])
    end
  end

  describe '#temperature_input_value' do
    it 'defaults to 36.5' do
      expect(helper.temperature_input_value(nil)).to eq('36.5')
    end

    it 'formats the stored value' do
      expect(helper.temperature_input_value(BigDecimal('37.60'))).to eq('37.6')
    end
  end
end
