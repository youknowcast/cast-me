module Api
  module V1
    class StrictDate
      class InvalidDate < StandardError; end

      FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

      def self.parse!(raw)
        raise InvalidDate unless raw.is_a?(String) && raw.match?(FORMAT)

        begin
          Date.strptime(raw, '%Y-%m-%d')
        rescue Date::Error, TypeError
          raise InvalidDate
        end
      end
    end
  end
end
