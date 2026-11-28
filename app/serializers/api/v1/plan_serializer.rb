# frozen_string_literal: true

module Api
  module V1
    class PlanSerializer
      def self.call(plan)
        participants = plan.plan_participants.includes(:user)
                           .select { |plan_participant| plan_participant.user.family_id == plan.family_id }

        {
          id: plan.id,
          title: plan.title,
          start_time: plan.start_time&.strftime('%H:%M'),
          end_time: plan.end_time&.strftime('%H:%M'),
          participants: participants.map { |plan_participant| ParticipantSerializer.call(plan_participant) }
        }
      end
    end
  end
end
