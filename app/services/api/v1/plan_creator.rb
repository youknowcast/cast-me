module Api
  module V1
    class PlanCreator
      class UnprocessableContent < StandardError; end

      def self.call(family:, token_user:, params:)
        date = StrictDate.parse!(params[:date])
        title = parse_title(params[:title])
        start_time = TimeOfDay.parse_optional(params[:start_time])
        end_time = TimeOfDay.parse_optional(params[:end_time])
        participant_ids = resolve_participant_ids(family: family, token_user: token_user, raw: params[:participant_ids])

        ActiveRecord::Base.transaction do
          plan = family.plans.create!(
            date: date,
            title: title,
            start_time: start_time,
            end_time: end_time,
            created_by: token_user,
            last_edited_by: token_user
          )
          participant_ids.each { |user_id| plan.plan_participants.create!(user_id: user_id) }
          plan
        end
      rescue ActiveRecord::RecordInvalid => e
        raise UnprocessableContent, e.record.errors.full_messages.join(', ')
      end

      def self.parse_title(raw)
        raise UnprocessableContent, 'title is required' unless raw.is_a?(String) && !raw.strip.empty?

        raw
      end

      def self.resolve_participant_ids(family:, token_user:, raw:)
        return default_participant_ids(token_user) if raw.nil?
        raise UnprocessableContent, 'participant_ids must be an array' unless raw.is_a?(Array)

        ids = raw.map { |value| strict_integer(value) }.uniq
        raise UnprocessableContent, 'at least one participant is required' if ids.empty?

        member_ids = family.users.where(id: ids).pluck(:id)
        raise UnprocessableContent, 'participants must be members of the same family' unless member_ids.sort == ids.sort

        ids
      end

      def self.default_participant_ids(token_user)
        id = token_user&.id
        raise UnprocessableContent, 'no participant could be decided' if id.nil?

        [id]
      end

      def self.strict_integer(value)
        raise UnprocessableContent, 'participant ids must be integers' unless value.is_a?(Integer)

        value
      end
    end
  end
end
