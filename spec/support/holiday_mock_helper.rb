# frozen_string_literal: true

module HolidayMockHelper
  def stub_holidays(holidays_hash = {})
    allow(HolidayService).to receive(:holidays).and_return(holidays_hash)
  end

  def stub_default_holidays
    stub_holidays({
                    '2026-01-01' => '元日',
                    '2026-01-12' => '成人の日'
                  })
  end
end

RSpec.configure do |config|
  config.include HolidayMockHelper

  config.before do
    # 外部APIへのアクセスを防ぐためにデフォルトでモック化
    stub_default_holidays
  end
end
