class ApplicationController < ActionController::Base
  LAST_SEEN_UPDATE_INTERVAL = 30.minutes

  before_action :touch_last_seen
  before_action :set_calendar_date
  helper_method :current_scope, :my_scope?, :family_scope?, :setting_scope?, :weekly_scope?

  def current_scope
    @current_scope ||= if controller_name.in?(%w[settings everyday_task_templates task_templates])
                         'settings'
                       else
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

  def my_scope? = current_scope == 'my'

  def family_scope? = current_scope == 'family'

  def setting_scope?
    controller_name.in?(%w[settings everyday_task_templates task_templates])
  end

  def weekly_scope? = controller_name == 'weekly_dashboard'

  def set_calendar_date
    @date = parse_date(params[:date])
  end

  # params の日付文字列を Date に変換する。空・不正な値は今日にフォールバックする。
  def parse_date(value)
    value.present? ? Date.parse(value.to_s) : Time.zone.today
  rescue Date::Error, TypeError
    Time.zone.today
  end

  def after_sign_in_path_for(_resource)
    calendar_path
  end

  private

  def touch_last_seen
    return unless user_signed_in?

    now = Time.current
    recorded_at = session[:last_seen_recorded_at].to_i
    return if recorded_at.positive? && now.to_i - recorded_at < LAST_SEEN_UPDATE_INTERVAL.to_i

    current_user.update_column(:last_seen_at, now)
    session[:last_seen_recorded_at] = now.to_i
  end
end
