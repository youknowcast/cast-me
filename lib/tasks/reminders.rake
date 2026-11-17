# frozen_string_literal: true

namespace :reminders do
  desc 'Send the reminders that are due right now (same tick as the in-process runner)'
  task dispatch: :environment do
    result = ReminderDispatcher.tick
    puts "reminders:dispatch #{result.inspect}"
  end
end
