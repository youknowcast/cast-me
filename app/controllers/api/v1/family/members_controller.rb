# frozen_string_literal: true

module Api
  module V1
    module Family
      class MembersController < ApplicationController
        def index
          members = current_family.users.order(:id).map do |member|
            { id: member.id, display_name: member.display_name }
          end

          render json: members
        end
      end
    end
  end
end
