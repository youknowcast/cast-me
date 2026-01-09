# frozen_string_literal: true

module Api
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    included do
      skip_forgery_protection
      skip_before_action :authenticate_user!, raise: false
      before_action :authenticate_api_token!
    end

    private

    def authenticate_api_token!
      expected = ENV.fetch('SCHEDULED_NOTIFICATION_API_TOKEN', '')
      provided = request.headers['X-Api-Token']

      return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided.to_s)

      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
