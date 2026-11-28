# frozen_string_literal: true

module Api
  module V1
    class ParticipantSerializer
      def self.call(plan_participant)
        user = plan_participant.user
        {
          id: user.id,
          display_name: user.display_name,
          status: plan_participant.status
        }
      end
    end
  end
end
