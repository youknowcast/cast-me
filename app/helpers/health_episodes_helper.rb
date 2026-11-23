module HealthEpisodesHelper
  def temperature_value(value)
    format('%<value>.1f', value: value)
  end

  def reminder_time_options
    (0...48).map do |slot|
      format('%<hour>02d:%<minute>02d', hour: slot / 2, minute: (slot % 2) * 30)
    end
  end

  def quick_temperature_measured_at(date)
    now = Time.current.change(sec: 0)
    return now if date == Time.zone.today

    Time.zone.parse("#{date} #{now.strftime('%H:%M')}")
  end
end
