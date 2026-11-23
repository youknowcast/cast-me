module HealthEpisodesHelper
  TEMPERATURE_SELECT_TENTHS = (350..419)
  DEFAULT_TEMPERATURE_TENTHS = 365

  def temperature_value(value)
    format('%<value>.1f', value: value)
  end

  def temperature_choices(selected = nil)
    tenths = TEMPERATURE_SELECT_TENTHS.to_a
    current = temperature_tenths(selected)
    tenths = (tenths << current).sort if current && tenths.exclude?(current)

    tenths.map { |value| ["#{temperature_from_tenths(value)}℃", temperature_from_tenths(value)] }
  end

  def temperature_input_value(value)
    temperature_from_tenths(temperature_tenths(value) || DEFAULT_TEMPERATURE_TENTHS)
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

  private

  def temperature_tenths(value)
    return if value.blank?

    (value.to_d * 10).round.to_i
  end

  def temperature_from_tenths(tenths)
    "#{tenths / 10}.#{tenths % 10}"
  end
end
