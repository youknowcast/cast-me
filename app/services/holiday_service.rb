require 'net/http'
require 'json'

class HolidayService
  API_URL = 'https://holidays-jp.github.io/api/v1/date.json'

  def self.holidays
    current_key = Time.current.strftime('%Y-%m')
    cache_key = "holidays-#{current_key}"

    Rails.cache.fetch(cache_key, expires_in: 1.month) do
      fetch_holidays
    end
  end

  def self.fetch_holidays
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Workaround for SSL certificate issues in some environments

    response = http.get(uri.path)
    data = JSON.parse(response.body)

    if data.empty?
      Rails.logger.warn("Fetched holidays are empty. Not caching.")
      return {}
    end

    data
  rescue StandardError => e
    Rails.logger.error("Failed to fetch holidays: #{e.message}")
    {}
  end
end
