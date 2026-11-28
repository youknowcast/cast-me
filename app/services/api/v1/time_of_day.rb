module Api
  module V1
    class TimeOfDay
      class InvalidTime < StandardError; end

      FORMAT = /\A([01]\d|2[0-3]):([0-5]\d)\z/

      def self.parse_optional(raw)
        return nil if raw.nil?
        raise InvalidTime unless raw.is_a?(String) && raw.match?(FORMAT)

        raw
      end
    end
  end
end
