# frozen_string_literal: true

module Api
  module V1
    class ApplicationController < ::ApplicationController
      TIME_ZONE = 'Asia/Tokyo'

      skip_forgery_protection
      skip_before_action :authenticate_user!, raise: false
      skip_before_action :touch_last_seen, raise: false
      skip_before_action :set_calendar_date, raise: false
      before_action :authenticate_api_token!

      private

      attr_reader :current_api_token

      def current_family = current_api_token.family

      def authenticate_api_token!
        api_token = ApiToken.authenticate(bearer_token)

        unless api_token
          render json: { error: 'unauthorized' }, status: :unauthorized
          return
        end

        api_token.touch_last_used!
        @current_api_token = api_token
      end

      def bearer_token
        header = request.headers['Authorization'].to_s
        scheme, token = header.split(/\s+/, 2)
        return if scheme.blank? || !scheme.casecmp('bearer').zero?

        token.presence
      end

      def requested_date
        raw = params[:date]
        return Time.current.in_time_zone(TIME_ZONE).to_date if raw.nil?

        Date.parse(raw.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def render_invalid_date! = render json: { error: 'invalid_date' }, status: :bad_request

      def apply_user_filter(scope)
        params[:user_id].present? ? scope.where(user_id: params[:user_id]) : scope
      end

      def family_tasks_for_date(date)
        current_family.tasks.for_date(date).where(user_id: current_family.user_ids)
      end
    end
  end
end
