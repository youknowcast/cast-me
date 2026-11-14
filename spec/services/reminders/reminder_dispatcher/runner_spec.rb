# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReminderDispatcher::Runner do
  describe '.enabled?' do
    it 'is enabled in production by default' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('REMINDER_DISPATCHER_ENABLED', '1').and_return('1')

      expect(described_class.enabled?).to be(true)
    end

    it 'can be turned off with REMINDER_DISPATCHER_ENABLED=0' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('REMINDER_DISPATCHER_ENABLED', '1').and_return('0')

      expect(described_class.enabled?).to be(false)
    end

    it 'stays off outside production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))

      expect(described_class.enabled?).to be(false)
    end
  end

  describe '.start' do
    after { described_class.stop }

    it 'starts only one background thread even when called repeatedly' do
      allow(ReminderDispatcher).to receive(:tick).and_return({ sent: 0, failed: 0, skipped: 0 })
      before_count = Thread.list.count

      described_class.start(interval: 3600)
      described_class.start(interval: 3600)

      expect(Thread.list.count - before_count).to eq(1)
    end

    it 'logs and swallows a tick error so the loop keeps running' do
      allow(Rails.logger).to receive(:error)
      allow(ReminderDispatcher).to receive(:tick).and_raise(RuntimeError, 'boom')

      expect { described_class.send(:run_tick) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(/ReminderDispatcher::Runner: RuntimeError: boom/)
    end
  end
end
