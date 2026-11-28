module Api
  module V1
    class PlansController < ApplicationController
      def create
        if idempotency_key
          status, body = Idempotency.process(
            family: current_family,
            key: idempotency_key,
            request_hash: Idempotency.request_hash(request.request_parameters.to_h)
          ) { create_plan_result }
        else
          status, body = create_plan_result
        end

        render json: body, status: status
      end

      private

      def idempotency_key = request.headers['Idempotency-Key'].to_s.strip.presence

      def create_plan_result
        plan = PlanCreator.call(family: current_family, token_user: current_api_token.user, params: params)
        [201, PlanSerializer.call(plan)]
      rescue StrictDate::InvalidDate
        [400, { error: 'invalid_date' }]
      rescue TimeOfDay::InvalidTime
        [400, { error: 'invalid_time' }]
      rescue PlanCreator::UnprocessableContent
        [422, { error: 'unprocessable_content' }]
      end
    end
  end
end
