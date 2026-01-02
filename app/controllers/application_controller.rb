class ApplicationController < ActionController::Base
  before_action :set_calendar_date
  helper_method :current_scope, :my_scope?, :family_scope?

  def current_scope
    @current_scope ||= begin
      scope_param = params[:scope].to_s.downcase.strip
      case scope_param
      when 'my'
        'my'
      when 'family'
        'family'
      else
        # Fallback to action name if controller is calendar, otherwise default to family
        controller_name == 'calendar' && action_name == 'my' ? 'my' : 'family'
      end
    end
  end

  def my_scope?
    current_scope == 'my'
  end

  def family_scope?
    current_scope == 'family' && controller_name != 'settings'
  end

  def set_calendar_date
    @date = if params[:date].present?
              Date.parse(params[:date])
            else
              Time.zone.today
            end
  rescue StandardError
    @date = Time.zone.today
  end

  def after_sign_in_path_for(_resource)
    calendar_path
  end
end
