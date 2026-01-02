require 'rails_helper'

RSpec.describe HolidayService, holiday_mock: false, type: :service do
  describe '.holidays' do
    let(:current_month) { Time.current.strftime('%Y-%m') }
    let(:cache_key) { "holidays-#{current_month}" }
    let(:api_response_body) { { '2026-01-01' => '元日' }.to_json }
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:http_double) { instance_double(Net::HTTP) }
    let(:response_double) { instance_double(Net::HTTPResponse, body: api_response_body) }

    before do
      # Mock cache to memory store for testing caching logic
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      # Mock Net::HTTP
      allow(Net::HTTP).to receive(:new).and_return(http_double)
      allow(http_double).to receive(:use_ssl=)
      allow(http_double).to receive(:verify_mode=)
      allow(http_double).to receive(:get).and_return(response_double)
    end

    it 'fetches holidays from the API and caches them' do
      holidays = described_class.holidays

      expect(Net::HTTP).to have_received(:new).once
      expect(holidays).to eq({ '2026-01-01' => '元日' })
      expect(Rails.cache.exist?(cache_key)).to be true
    end

    it 'uses the cache on subsequent calls' do
      described_class.holidays
      described_class.holidays

      expect(Net::HTTP).to have_received(:new).once
    end

    context 'when the API returns empty data' do
      let(:api_response_body) { '{}' }

      it 'does not cache empty results' do
        described_class.holidays
        expect(Rails.cache.exist?(cache_key)).to be false
      end
    end

    context 'when an error occurs' do
      before do
        allow(http_double).to receive(:get).and_raise(StandardError.new('API Error'))
      end

      it 'returns an empty hash and does not crash' do
        expect do
          holidays = described_class.holidays
          expect(holidays).to eq({})
        end.not_to raise_error
      end
    end
  end
end
