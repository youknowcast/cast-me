# frozen_string_literal: true

Rails.application.config.after_initialize do
  ReminderDispatcher::Runner.start if ReminderDispatcher::Runner.enabled?
end
