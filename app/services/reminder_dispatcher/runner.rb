# frozen_string_literal: true

class ReminderDispatcher
  # 1分ごとに ReminderDispatcher.tick を呼ぶ常駐スレッド。
  # 時計としてだけ存在し、送信の正しさは NotificationDispatch が担保する。
  class Runner
    DEFAULT_INTERVAL = 60

    class << self
      def enabled?
        Rails.env.production? && ENV.fetch('REMINDER_DISPATCHER_ENABLED', '1') != '0'
      end

      def start(interval: DEFAULT_INTERVAL)
        return @thread if @thread&.alive?

        @thread = Thread.new do
          loop do
            run_tick
            sleep interval
          end
        end
      end

      def stop
        @thread&.kill
        @thread = nil
      end

      private

      def run_tick
        Rails.application.executor.wrap do
          ActiveRecord::Base.connection_pool.with_connection { ReminderDispatcher.tick }
        end
      rescue StandardError => e
        Rails.logger.error("ReminderDispatcher::Runner: #{e.class}: #{e.message}")
      end
    end
  end
end
