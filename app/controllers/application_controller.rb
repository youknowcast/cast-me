class ApplicationController < ActionController::Base
  helper_method :current_scope, :my_scope?

  def current_scope
    @current_scope ||= begin
      scope_param = params[:scope].to_s.downcase.strip
      if scope_param == 'my'
        'my'
      elsif scope_param == 'family'
        'family'
      else
        # Fallback to action name if controller is calendar, otherwise default to family
        (params[:controller] == 'calendar' && action_name == 'my') || action_name == 'my' ? 'my' : 'family'
      end
    end
  end

  def my_scope?
    current_scope == 'my'
  end

  def after_sign_in_path_for(_resource)
    calendar_path
  end
end
